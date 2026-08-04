import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cart_item.dart';
import '../models/session_state.dart';
import '../parser/voice_text_parser.dart';

/// 会话数据持久化 box（在 main 中注入）
final sessionBoxProvider = Provider<Box>((ref) => throw UnimplementedError());

/// 历史归档 box（按天分组，30 天自动清理）
final historyBoxProvider = Provider<Box>((ref) => throw UnimplementedError());

/// 会话状态机（设计文档 §3 / §4.4）
final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionNotifier extends Notifier<SessionState> {
  static const String _itemsKey = 'items';
  static const String _undoKey = 'undo';

  Box get _box => ref.read(sessionBoxProvider);
  Box get _historyBox => ref.read(historyBoxProvider);

  @override
  SessionState build() {
    // App 重启后从 hive 自动恢复
    final items = (_box.get(_itemsKey) as List?) ?? const [];
    final undo = (_box.get(_undoKey) as List?) ?? const [];
    return SessionState(
      items: items
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      undoStack: undo
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// 将一句识别文本解析为多条明细并逐条累加（设计文档 §4.2 ③）
  void addParsedText(String text) {
    final matches = VoiceTextParser.parseVoiceTexts(text);
    for (final m in matches) {
      addItem(CartItem(label: m.rawText, amount: m.value, addedAt: DateTime.now()));
    }
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

  /// 清空（需二次确认，由 UI 层把关）；清空后撤销栈同步清空
  void clear() {
    state = const SessionState();
    _persist();
  }

  /// 历史归档：按天分组写入 history box（设计文档 §4.4，保留 30 天）
  void _archive(List<CartItem> items) {
    for (final item in items) {
      final dayKey = _dayKey(item.addedAt);
      final list = List<Map>.from(
          (_historyBox.get(dayKey) as List?) ?? const []);
      list.add(item.toJson());
      _historyBox.put(dayKey, list);
    }
    _cleanExpiredHistory();
  }

  /// 清理 30 天前的历史记录
  void _cleanExpiredHistory() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (final key in _historyBox.keys.toList()) {
      if (key is String && key.length == 10) {
        final day = DateTime.tryParse(key);
        if (day != null && day.isBefore(cutoff)) {
          _historyBox.delete(key);
        }
      }
    }
  }

  String _dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  void _persist() {
    _box.put(_itemsKey,
        state.items.map((e) => e.toJson()).toList());
    _box.put(_undoKey,
        state.undoStack.map((e) => e.toJson()).toList());
  }
}
