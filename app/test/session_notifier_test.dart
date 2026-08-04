import 'package:balance/models/cart_item.dart';
import 'package:balance/state/history_provider.dart';
import 'package:balance/state/session_notifier.dart';
import 'package:balance/state/settings_provider.dart';
import 'package:balance/state/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_box.dart';

/// 会话状态机测试（设计文档 §7 / US-008/009/011/012）
void main() {
  late ProviderContainer container;
  late Box sessionBox;
  late Box historyBox;

  setUpAll(() async {
    sessionBox = InMemoryBox();
    historyBox = InMemoryBox();
  });

  setUp(() async {
    await sessionBox.clear();
    await historyBox.clear();
    container = ProviderContainer(
      overrides: [
        sessionBoxProvider.overrideWithValue(sessionBox),
        historyBoxProvider.overrideWithValue(historyBox),
      ],
    );
  });

  tearDown(() async {
    // 等待 invalidateSelf 触发的异步 rebuild 完成
    await container.pump();
    container.dispose();
  });

  tearDownAll(() async {});

  CartItem item(double amount, {String label = ''}) =>
      CartItem(label: label, amount: amount, addedAt: DateTime.now());

  group('累加', () {
    test('初始空状态 total=0', () {
      final s = container.read(sessionProvider);
      expect(s.items, isEmpty);
      expect(s.total, 0);
    });

    test('addItem 累加总价', () {
      final n = container.read(sessionProvider.notifier);
      n.addItem(item(5.5));
      n.addItem(item(38));
      final s = container.read(sessionProvider);
      expect(s.items.length, 2);
      expect(s.total, 43.5);
    });

    test('addParsedText 单句多金额逐条插入', () {
      final n = container.read(sessionProvider.notifier);
      final added = n.addParsedText('黄瓜5块，牛肉38');
      expect(added.length, 2);
      expect(container.read(sessionProvider).items.length, 2);
      expect(container.read(sessionProvider).total, 43);
    });

    test('addParsedText 无金额返回空且不累加', () {
      final n = container.read(sessionProvider.notifier);
      expect(n.addParsedText('老板这个多少钱'), isEmpty);
      expect(container.read(sessionProvider).items, isEmpty);
    });
  });

  group('撤销与删除（US-008/007）', () {
    test('撤销最近一笔，可连续撤销', () {
      final n = container.read(sessionProvider.notifier);
      n.addItem(item(5));
      n.addItem(item(38));
      n.undo();
      expect(container.read(sessionProvider).total, 5);
      n.undo();
      expect(container.read(sessionProvider).items, isEmpty);
    });

    test('空栈撤销安全', () {
      container.read(sessionProvider.notifier).undo();
      expect(container.read(sessionProvider).items, isEmpty);
    });

    test('删除单项总价联动，撤销栈同步', () {
      final n = container.read(sessionProvider.notifier);
      final a = item(5, label: '黄瓜');
      final b = item(38, label: '牛肉');
      final c = item(2.5, label: '青菜');
      n.addItem(a);
      n.addItem(b);
      n.addItem(c);
      n.removeItem(b); // 删除中间项
      final s = container.read(sessionProvider);
      expect(s.items.map((e) => e.amount), [5, 2.5]);
      expect(s.undoStack.length, 2);
      expect(s.total, 7.5);
      n.undo(); // 撤销最后一笔（青菜）
      expect(container.read(sessionProvider).items.map((e) => e.amount), [5]);
    });

    test('删除不存在的项无副作用', () {
      final n = container.read(sessionProvider.notifier);
      n.addItem(item(5));
      final before = container.read(sessionProvider).items.length;
      n.removeItem(item(99));
      expect(container.read(sessionProvider).items.length, before);
    });
  });

  group('清空（US-009）', () {
    test('清空后撤销栈同步清空', () {
      final n = container.read(sessionProvider.notifier);
      n.addItem(item(5));
      n.addItem(item(38));
      n.clear();
      final s = container.read(sessionProvider);
      expect(s.items, isEmpty);
      expect(s.undoStack, isEmpty);
      expect(s.total, 0);
    });

    test('清空 = 结算：明细归档进当日历史（US-012）', () {
      final n = container.read(sessionProvider.notifier);
      n.addItem(item(5, label: '黄瓜'));
      n.addItem(item(38, label: '牛肉'));
      n.clear();
      final history = container.read(historyProvider);
      expect(history.days.length, 1);
      expect(history.days.first.items.length, 2);
      expect(history.days.first.total, 43);
    });
  });

  group('200 条上限归档（US-012）', () {
    test('超出部分最旧归档入历史', () {
      final n = container.read(sessionProvider.notifier);
      for (var i = 0; i < 205; i++) {
        n.addItem(item(1));
      }
      expect(container.read(sessionProvider).items.length, 200);
      final history = container.read(historyProvider);
      expect(history.days, isNotEmpty);
      final totalArchived = history.days.fold<int>(
          0, (sum, d) => sum + d.items.length);
      expect(totalArchived, 5);
    });
  });

  group('重启恢复（US-011）', () {
    test('新容器从同一 box 恢复会话', () {
      final n = container.read(sessionProvider.notifier);
      n.addItem(item(5.5, label: '黄瓜'));
      n.addItem(item(38, label: '牛肉'));

      final c2 = ProviderContainer(
        overrides: [
          sessionBoxProvider.overrideWithValue(sessionBox),
          historyBoxProvider.overrideWithValue(historyBox),
        ],
      );
      addTearDown(c2.dispose);
      final s = c2.read(sessionProvider);
      expect(s.items.length, 2);
      expect(s.total, 43.5);
      expect(s.items.first.label, '黄瓜');
    });
  });

  group('30 天历史清理', () {
    test('过期 key 在读取时被清除', () {
      final oldKey = DateTime.now()
          .subtract(const Duration(days: 35))
          .toIso8601String()
          .substring(0, 10);
      historyBox.put(
        oldKey,
        [
          item(5).toJson(),
        ],
      );
      final history = container.read(historyProvider);
      expect(history.days, isEmpty);
      expect(historyBox.get(oldKey), isNull);
    });
  });

  group('设置（§2.6 声音反馈）', () {
    test('默认关闭，开启后持久化，新容器恢复', () {
      expect(container.read(settingsProvider).soundEnabled, isFalse);

      container.read(settingsProvider.notifier).setSoundEnabled(true);
      expect(container.read(settingsProvider).soundEnabled, isTrue);
      expect(sessionBox.get('settings.soundFeedback'), isTrue);

      // 模拟重启：新容器从同一 box 恢复设置
      final c2 = ProviderContainer(
        overrides: [
          sessionBoxProvider.overrideWithValue(sessionBox),
          historyBoxProvider.overrideWithValue(historyBox),
        ],
      );
      addTearDown(c2.dispose);
      expect(c2.read(settingsProvider).soundEnabled, isTrue);
    });
  });
}
