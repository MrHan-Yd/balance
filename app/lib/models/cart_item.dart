/// 购物明细条目（设计文档 §4.1）
class CartItem {
  /// 原始识别文本片段（如 "豆腐"）；纯数字时为空
  final String label;

  /// 金额（元），两位小数精度
  final double amount;

  /// 添加时间
  final DateTime addedAt;

  const CartItem({
    required this.label,
    required this.amount,
    required this.addedAt,
  });

  /// 明细行金额展示："¥1,234.56"
  String get amountText {
    final isInt = amount == amount.roundToDouble();
    final digits = isInt ? 0 : 2;
    return '¥${amount.toStringAsFixed(digits)}';
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'amount': amount,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    label: json['label'] as String? ?? '',
    amount: (json['amount'] as num).toDouble(),
    addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
  );

  /// 值相等：label + amount + addedAt 全同视为同一条（用于滑动删除匹配撤销栈）
  @override
  bool operator ==(Object other) =>
      other is CartItem &&
      other.label == label &&
      other.amount == amount &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(label, amount, addedAt);

  @override
  String toString() =>
      'CartItem(${label.isEmpty ? "未命名" : label}, $amount, $addedAt)';
}
