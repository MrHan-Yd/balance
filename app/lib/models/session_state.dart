import 'cart_item.dart';

/// 当前会话状态（设计文档 §4.1）
class SessionState {
  /// 明细列表上限，超出最旧条目归档到历史
  static const int maxItems = 200;

  /// 明细列表
  final List<CartItem> items;

  /// 撤销栈
  final List<CartItem> undoStack;

  /// 总额 = Σ amount
  double get total => items.fold(0, (sum, item) => sum + item.amount);

  const SessionState({this.items = const [], this.undoStack = const []});

  SessionState copyWith({
    List<CartItem>? items,
    List<CartItem>? undoStack,
  }) {
    return SessionState(
      items: items ?? this.items,
      undoStack: undoStack ?? this.undoStack,
    );
  }
}
