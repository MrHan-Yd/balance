/// 购物明细条目（设计文档 §4.1）
class CartItem {
  /// 商品名/标题（如 "黄瓜"）；纯报价或手动输入时为空
  final String label;

  /// 识别原文片段（如 "黄瓜5块5"）；手动输入时为空
  final String raw;

  /// 金额（元），两位小数精度
  final double amount;

  /// 添加时间
  final DateTime addedAt;

  const CartItem({
    required this.label,
    required this.amount,
    required this.addedAt,
    this.raw = '',
  });

  /// 展示标题：商品名 → 原文 → 空（UI 层兜底"手动输入"）
  String get title => label.isNotEmpty ? label : raw;

  /// 明细行金额展示："¥1,234.56"
  String get amountText {
    final isInt = amount == amount.roundToDouble();
    final digits = isInt ? 0 : 2;
    return '¥${amount.toStringAsFixed(digits)}';
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'raw': raw,
    'amount': amount,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    label: json['label'] as String? ?? '',
    raw: json['raw'] as String? ?? '',
    amount: (json['amount'] as num).toDouble(),
    addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
  );

  /// 值相等：全字段相同视为同一条（用于滑动删除匹配撤销栈）
  @override
  bool operator ==(Object other) =>
      other is CartItem &&
      other.label == label &&
      other.raw == raw &&
      other.amount == amount &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(label, raw, amount, addedAt);

  @override
  String toString() =>
      'CartItem(${title.isEmpty ? "未命名" : title}, $amount, $addedAt)';
}
