import 'cart_item.dart';

/// 单日历史记录（设计文档 §4.4 / US-012）
class HistoryDay {
  /// 日期键：YYYY-MM-DD
  final String dayKey;

  /// 当日条目
  final List<CartItem> items;

  const HistoryDay({required this.dayKey, required this.items});

  /// 当日总额
  double get total => items.fold(0, (sum, item) => sum + item.amount);
}
