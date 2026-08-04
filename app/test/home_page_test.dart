import 'package:balance/state/storage_providers.dart';
import 'package:balance/theme/app_theme.dart';
import 'package:balance/ui/home_page.dart';
import 'package:balance/ui/widgets/manual_keypad.dart';
import 'package:balance/ui/widgets/mic_button.dart';
import 'package:balance/ui/widgets/rolling_number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_box.dart';

/// Widget 测试（设计文档 §7：明细增删、撤销/清空交互、空状态、手动键盘输入流）
///
/// 语音通道以 mock 替代（测试环境无原生识别）；交互均走手动键盘模式。
/// 会话/历史存储以纯内存 Box 注入：FakeAsync 中 Hive 文件 IO 无法完成，
/// 写操作排队后 clear() 会永久挂起（详见 support/in_memory_box.dart）。
void main() {
  late Box sessionBox;
  late Box historyBox;

  setUpAll(() async {
    // mock speech_to_text 原生通道，避免 MissingPluginException
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'has_permission':
          return true;
        case 'listen':
          return true;
        case 'stop':
        case 'cancel':
          return null;
        case 'locales':
          return <dynamic>['zh_CN'];
        default:
          return null;
      }
    });

    sessionBox = InMemoryBox();
    historyBox = InMemoryBox();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugin.csdcorp.com/speech_to_text'), null);
  });

  setUp(() async {
    await sessionBox.clear();
    await historyBox.clear();
  });

  /// 组装带 hive 注入的 App（模拟真机竖屏尺寸）
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionBoxProvider.overrideWithValue(sessionBox),
          historyBoxProvider.overrideWithValue(historyBox),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pump(); // 等待语音初始化
  }

  /// 带短超时的 pumpAndSettle：UI 若出现无限动画/持续帧，5 秒内快速失败
  /// （默认超时 10 分钟，会在 CI 上表现为"跑了就卡死"）
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );

  /// 读取总价卡滚动数字的完整文本（逐位滚动组件，需读组件属性而非 find.text）
  String totalText(WidgetTester tester) =>
      tester
          .widget<RollingNumberText>(find.byType(RollingNumberText))
          .text;

  /// 切换到手动键盘模式（tap 中栏 ⌨️ 图标）
  Future<void> switchToKeypad(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.keyboard_alt_rounded));
    await settle(tester);
  }

  /// 键盘按键 finder：限定在 ManualKeypad 内，避开总价滚动数字中的同字符
  /// （如 '.'、'3'、'8' 等也出现在总价 '0.00' / '38.50' 的单字符 Text 中）
  Finder keypadKey(String ch) => find.descendant(
    of: find.byType(ManualKeypad),
    matching: find.text(ch),
  );

  /// 通过键盘输入金额并确认
  Future<void> enterAmount(WidgetTester tester, String text) async {
    for (final ch in text.split('')) {
      await tester.tap(keypadKey(ch));
      await tester.pump();
    }
    await tester.tap(find.text('确认'));
    await settle(tester);
  }

  testWidgets('空状态显示引导文案', (tester) async {
    await pumpApp(tester);
    expect(find.text('开始说话，自动记账'), findsOneWidget);
    expect(find.text('当前总价'), findsOneWidget);
  });

  testWidgets('手动键盘输入流：确认后插入明细并更新总价', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);

    await enterAmount(tester, '38.5');
    expect(totalText(tester), '38.50'); // 总价卡数字（¥ 独立渲染）
    expect(find.text('¥38.50'), findsOneWidget); // 明细行金额

    await enterAmount(tester, '12');
    expect(totalText(tester), '50.50'); // 总价联动更新
  });

  testWidgets('键盘非法输入不响应：重复小数点', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);

    await tester.tap(keypadKey('3'));
    await tester.pump();
    await tester.tap(keypadKey('.'));
    await tester.pump();
    await tester.tap(keypadKey('.'));
    await tester.pump();
    await tester.tap(keypadKey('8'));
    await tester.pump();

    expect(find.text('3.8'), findsOneWidget); // 未出现 3..8
  });

  testWidgets('撤销上一笔（US-008）', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);

    await enterAmount(tester, '38');
    await enterAmount(tester, '5');
    expect(totalText(tester), '43.00');

    await tester.tap(find.text('撤销上一笔'));
    await settle(tester);
    expect(totalText(tester), '38.00');

    await tester.tap(find.text('撤销上一笔'));
    await settle(tester);
    expect(find.text('开始说话，自动记账'), findsOneWidget); // 回到空状态
  });

  testWidgets('清空需二次确认（US-009）', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);
    await enterAmount(tester, '38');

    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await settle(tester);
    expect(find.text('确认清空全部？'), findsOneWidget);
    expect(find.textContaining('当前 1 件'), findsOneWidget);

    // 取消：不清空
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(totalText(tester), '38.00');

    // 确认：清空
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await settle(tester);
    await tester.tap(find.text('清空全部'));
    await settle(tester);
    expect(find.text('开始说话，自动记账'), findsOneWidget);
  });

  testWidgets('明细行滑动删除（US-007）', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);

    await enterAmount(tester, '38');
    await enterAmount(tester, '5');
    expect(totalText(tester), '43.00');

    // 滑动删除最后一条明细（明细行金额：整数显示 "¥5"）
    await tester.drag(find.text('¥5').last, const Offset(-400, 0));
    await settle(tester);
    expect(totalText(tester), '38.00');
  });

  testWidgets('历史页入口（US-012）', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.history_rounded));
    await settle(tester);
    expect(find.text('历史记录'), findsOneWidget);
    expect(find.text('暂无历史记录'), findsOneWidget);
  });

  testWidgets('清空结算后明细归档进当日历史（US-012 数据流）', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);
    await enterAmount(tester, '38');
    await enterAmount(tester, '5');

    // 清空 = 结算完成：本次明细应进入历史记录
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await settle(tester);
    await tester.tap(find.text('清空全部'));
    await settle(tester);
    expect(totalText(tester), '0.00');

    // 打开历史页：今日一条 2 件记录，总额 43.00
    await tester.tap(find.byIcon(Icons.history_rounded));
    await settle(tester);
    expect(find.text('暂无历史记录'), findsNothing);
    final now = DateTime.now();
    final dayKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(find.text(dayKey), findsOneWidget);
    expect(find.textContaining('共 2 件'), findsOneWidget);
    expect(find.textContaining('¥43.00'), findsOneWidget);
  });

  testWidgets('键盘模式：无语音键，底栏为确认大按钮', (tester) async {
    await pumpApp(tester);
    await switchToKeypad(tester);
    expect(find.text('正在使用手动输入'), findsOneWidget);
    expect(find.byType(MicButton), findsNothing); // 语音主键不再显示
    expect(find.text('确认'), findsOneWidget); // 底栏确认大按钮
  });

  testWidgets('设置：声音反馈默认关闭，开启后持久化（重启保持）', (tester) async {
    await pumpApp(tester);

    // 打开设置弹层：默认关闭
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('声音反馈'), findsOneWidget);
    var sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isFalse);

    // 开启 → 写入存储
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isTrue);
    expect(sessionBox.get('settings.soundFeedback'), isTrue);

    // 关闭弹层后重新组装 App（模拟重启）→ 设置保持
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isTrue);
  });

  testWidgets('声音反馈：默认关闭不发声，开启后累加发声', (tester) async {
    // mock 系统声音通道，统计 SystemSound.play 调用
    final sounds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemSound.play') {
        sounds.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpApp(tester);
    await switchToKeypad(tester);

    // 默认关闭：确认金额只发按钮自身的系统点击音（Material Feedback），无额外提示音
    await enterAmount(tester, '38');
    final baseCount = sounds.length;

    // 开启声音反馈
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    // 开启后：确认金额比默认多一次提示音
    await enterAmount(tester, '12');
    expect(sounds.length, greaterThan(baseCount));
  });
}
