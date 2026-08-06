import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cart_item.dart';
import '../models/session_state.dart';
import '../parser/voice_text_parser.dart';
import 'history_provider.dart';
import 'storage_providers.dart';

/// 会话状态机（设计文档 §3 / §4.4）
final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<SessionState> {
  static const String _itemsKey = 'items';
  static const String _undoKey = 'undo';

  Box get _box => ref.read(sessionBoxProvider);

  @override
  SessionState build() {
    // App 重启后从 hive 自动恢复
    final items = (_box.get(_itemsKey) as List?) ?? const [];
    final undo = (_box.get(_undoKey) as List?) ?? const [];
    return SessionState(
      items:
          items
              .map(
                (e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
      undoStack:
          undo
              .map(
                (e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
    );
  }

  /// 将一句识别文本解析为多条明细并逐条累加（设计文档 §4.2 ③）；
  /// 返回本次实际插入的条目（供播报/UI 反馈，空列表 = 解析无金额）
  List<CartItem> addParsedText(String text) {
    final matches = VoiceTextParser.parseVoiceTexts(text);
    final added = <CartItem>[];
    for (final m in matches) {
      final item = CartItem(
        label: m.name, // 商品名做标题（"黄瓜"），纯报价为空
        raw: m.rawText, // 原文片段（"黄瓜5块5"）
        amount: m.value,
        addedAt: DateTime.now(),
      );
      addItem(item);
      added.add(item);
    }
    return added;
  }

  /// 追加明细 → 更新总价 → 持久化；超出 200 条最旧归档到历史
  void addItem(CartItem item) {
    var items = [...state.items, item];
    var undoStack = [...state.undoStack];
    undoStack.add(item);

    if (items.length > SessionState.maxItems) {
      final overflow = items.sublist(0, items.length - SessionState.maxItems);
      items = items.sublist(items.length - SessionState.maxItems);
      _archive(overflow);
    }

    state = state.copyWith(items: items, undoStack: undoStack);
    _persist();
  }

  /// 撤销最近一次累加（弹回 undoStack 栈顶，可连续撤销）
  void undo() {
    if (state.undoStack.isEmpty || state.items.isEmpty) return;
    final items = [...state.items]..removeLast();
    final undoStack = [...state.undoStack]..removeLast();
    state = state.copyWith(items: items, undoStack: undoStack);
    _persist();
  }

  /// 删除单项（明细行滑动删除，US-007）：从明细与撤销栈中同步移除，
  /// 保证撤销栈与明细一一对应，总价联动更新
  void removeItem(CartItem item) {
    final items = [...state.items]..remove(item);
    final undoStack = [...state.undoStack]..remove(item);
    if (items.length == state.items.length) return; // 未匹配到，忽略
    state = state.copyWith(items: items, undoStack: undoStack);
    _persist();
  }

  /// 清空（需二次确认，由 UI 层把关）；清空后撤销栈同步清空。
  /// 清空 = 结算完成：本次明细归档进当日历史（设计文档 §2.5 核心闭环 US-012）
  void clear() {
    if (state.items.isNotEmpty) {
      ref.read(historyProvider.notifier).archive(state.items);
    }
    state = const SessionState();
    _persist();
  }

  /// 历史归档：按天分组写入 history box（设计文档 §4.4，保留 30 天）
  void _archive(List<CartItem> items) {
    ref.read(historyProvider.notifier).archive(items);
  }

  void _persist() {
    _box.put(_itemsKey, state.items.map((e) => e.toJson()).toList());
    _box.put(_undoKey, state.undoStack.map((e) => e.toJson()).toList());
  }
}
