/// 解析器提取出的单个金额（设计文档 §4.2）
class PriceMatch {
  /// 提取的金额（元）
  final double value;

  /// 原文片段（如 "黄瓜5块"、"38块5"、"12.5"），仅本笔，不含前面已入账的内容
  final String rawText;

  /// 商品名（金额前的名称部分，如 "黄瓜"；纯报价时为空）
  final String name;

  const PriceMatch({
    required this.value,
    required this.rawText,
    this.name = '',
  });
}
