/// 解析器提取出的单个金额（设计文档 §4.2）
class PriceMatch {
  /// 提取的金额（元）
  final double value;

  /// 原文片段，作为明细 label（如 "黄瓜5块"、"38块5"、"12.5"）
  final String rawText;

  const PriceMatch({required this.value, required this.rawText});
}
