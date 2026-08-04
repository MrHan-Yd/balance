import '../models/price_match.dart';

/// 文本解析与数字提取器（设计文档 §4.2）
///
/// 解析管线：
///   ① 中文数字归一化："牛肉三十八" → "牛肉38"
///   ② 金额单位映射：块/元 → 整数结束；毛/角 → 小数 1 位；分 → 小数 2 位
///   ③ 多金额提取：扫描全部候选数字（非 firstMatch）
///   ④ 过滤：重量/数量单位相邻数字忽略；孤立数字视为报价；
///      上限按整数部分判定（0 < 值，整数部分 ≤ 99999，小数不推高上限）
class VoiceTextParser {
  VoiceTextParser._();

  /// 中文数字表（"两" 归一为 2）
  static const Map<String, int> _chineseDigits = {
    '零': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };

  /// 中文数字单位表（支持组合："三十八"→38，"一万零五"→10005）
  static const Map<String, int> _chineseUnits = {
    '十': 10,
    '百': 100,
    '千': 1000,
    '万': 10000,
  };

  /// 金额单位：块/元 → 整数结束；毛/角 → 小数 1 位；分 → 小数 2 位
  static const Set<String> _amountUnits = {'块', '元', '毛', '角', '分'};

  /// 重量/数量单位：相邻的数字忽略（"三斤" 不提取）
  static const Set<String> _ignoredUnits = {
    '斤',
    '公斤',
    '克',
    '千克',
    '两',
    '个',
    '袋',
    '根',
    '只',
    '包',
    '箱',
  };

  /// 有效金额上限（整数部分封顶，对齐键盘通道：99999.9 等小数不推高上限）
  static const double maxAmount = 99999;

  static final RegExp _chineseNumberRegex = RegExp(
    '[${_chineseDigits.keys.join()}${_chineseUnits.keys.join()}]+',
  );
  static final RegExp _digitRegex = RegExp(r'\d+(\.\d+)?');

  /// 解析入口：返回全部金额匹配（可含 0~n 个）
  static List<PriceMatch> parseVoiceTexts(String input) {
    if (input.trim().isEmpty) return const [];

    final text = normalizeChineseNumbers(input); // ①
    return _extractAmounts(text); // ②③④
  }

  // ---------- ① 中文数字归一化 ----------

  /// 将文本中的连续中文数字（含十/百/千/万）替换为阿拉伯数字。
  /// 例："牛肉三十八" → "牛肉38"；"五块五" → "5块5"
  static String normalizeChineseNumbers(String input) {
    final buffer = StringBuffer();
    var last = 0;
    for (final m in _chineseNumberRegex.allMatches(input)) {
      buffer.write(input.substring(last, m.start));
      final value = _parseChineseNumber(m.group(0)!);
      buffer.write(value ?? m.group(0)!);
      last = m.end;
    }
    buffer.write(input.substring(last));
    return buffer.toString();
  }

  /// 解析连续中文数字片段，非法时返回 null。
  /// "三十八"→38，"一万零五"→10005，"一百二十三"→123，"十一"→11，"二十"→20
  static int? _parseChineseNumber(String s) {
    int total = 0;
    int section = 0;
    int number = 0;
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      final digit = _chineseDigits[c];
      if (digit != null) {
        number = digit;
        if (i == s.length - 1) {
          section += number; // 末位数字并入当前段
          number = 0; // 避免 return 时重复累加
        }
        continue;
      }
      final unit = _chineseUnits[c];
      if (unit != null) {
        if (number == 0) number = 1; // 缺省前置位："十一"=10+1、"十万"=10×万
        if (unit == 10000) {
          total += (section + number) * unit; // 万：结算整段
          section = 0;
        } else {
          section += number * unit; // 十/百/千：并入当前段
        }
        number = 0;
        continue;
      }
      return null; // 非法字符
    }
    return total + section + number;
  }

  // ---------- ②③④ 金额提取与过滤 ----------

  /// 扫描全部数字片段，解析金额单位表达并过滤重量/数量单位。
  static List<PriceMatch> _extractAmounts(String text) {
    final matches = _digitRegex.allMatches(text).toList();
    final results = <PriceMatch>[];
    int consumedUntil = -1; // 已被金额表达式消费的文本位置（避免重复提取）

    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      if (m.start < consumedUntil) continue; // 已被消费

      final value = double.parse(m.group(0)!);
      final intPart = m.group(0)!;

      // 表达式起点：若紧邻前一字符是中文/字母（商品名），label 从该处开始
      final labelStart = _labelStart(text, m.start);

      // 金额单位表达：X块 / X块Y / X块Y毛Z分 / X毛 / X分 ...
      if (!intPart.contains('.')) {
        final parsed = _parseAmountExpression(text, m);
        if (parsed != null) {
          final amount = _roundToCent(parsed.$1);
          if (amount > 0 && amount.truncate() <= maxAmount) {
            results.add(
              PriceMatch(
                value: amount,
                rawText: text.substring(labelStart, parsed.$2).trim(),
              ),
            );
            consumedUntil = parsed.$2;
            continue;
          }
        }
      }

      // 重量/数量单位相邻 → 忽略（"三斤"、"5个"）
      if (_isFollowedByIgnoredUnit(text, m.end)) continue;

      // 孤立数字 → 视为直接报价
      if (value > 0 && value.truncate() <= maxAmount) {
        results.add(
          PriceMatch(
            value: _roundToCent(value),
            rawText: text.substring(labelStart, m.end).trim(),
          ),
        );
      }
    }
    return results;
  }

  /// 舍入到分（两位小数精度），避免浮点误差（开发规范 §5.4）
  static double _roundToCent(double v) => (v * 100).round() / 100;

  /// 解析以数字片段开头的金额表达式。
  /// 返回 (金额, 表达式结束位置)；不是金额表达时返回 null。
  /// 覆盖：X块 | X块Y | X块Y毛Z分 | X块Y分 | X毛 | X毛Y分 | X分
  static (double, int)? _parseAmountExpression(String text, RegExpMatch m) {
    final digits = int.parse(m.group(0)!);
    var p = _skipSpaces(text, m.end);
    if (p >= text.length || !_amountUnits.contains(text[p])) return null;

    final unit = text[p];
    if (unit == '块' || unit == '元') {
      // 整数部分，继续解析小数位
      p = _skipSpaces(text, p + 1);
      final frac = _parseFraction(text, p);
      if (frac == null) return (digits.toDouble(), p);
      return (digits + frac.$1, frac.$2);
    }

    // 毛/角/分 开头：纯小数（"5毛" → 0.5，"9分" → 0.09）。
    // leading 传入表达式开头的数字，作为毛位/分位值
    final frac = _parseFraction(text, m.end, leading: digits);
    if (frac == null) return null;
    return (frac.$1, frac.$2);
  }

  /// 从 pos 起解析小数位序列（毛/角 1 位 + 分 2 位）。
  /// 口语规则："X块Y" → X.Y；"X块Y毛Z" → X.YZ（毛位后省略"分"字）；"X块Y分" → X.0Y；
  /// 以毛/角/分开头的表达式（"5毛"、"5毛5"、"9分"）由 [leading] 传入首位数字作毛/分位。
  /// 返回 (小数部分, 表达式结束位置)；无可解析内容时返回 null。
  static (double, int)? _parseFraction(String text, int pos,
      {int? leading}) {
    var p = _skipSpaces(text, pos);
    if (p >= text.length) return null;

    int? jiao; // 毛/角位
    int? fen; // 分位

    if (_isDigit(text, p)) {
      final n = _readDigits(text, p);
      p = _skipSpaces(text, n.$2);
      if (p < text.length && (text[p] == '毛' || text[p] == '角')) {
        jiao = n.$1;
        p = _skipSpaces(text, p + 1);
      } else if (p < text.length && text[p] == '分') {
        fen = n.$1; // "X块Y分" → 分位
        p += 1;
      } else if (_isFollowedByIgnoredUnit(text, p)) {
        return null; // "5块3斤"：数字后紧跟重量/数量单位 → 非小数位，整块到此结束
      } else {
        jiao = n.$1; // "X块Y" → 块后直接数字即 1 位小数
      }
    } else if (text[p] == '毛' || text[p] == '角') {
      jiao = leading; // 表达式开头数字即毛位："5毛" → 0.5 元
      p = _skipSpaces(text, p + 1);
      if (p < text.length && _isDigit(text, p)) {
        final n = _readDigits(text, p);
        fen = n.$1; // "5毛5" → 毛位后的数字是分位
        p = n.$2;
        if (p < text.length && text[p] == '分') p += 1;
      }
    } else if (text[p] == '分') {
      fen = leading; // "9分" → 0.09 元
      p = _skipSpaces(text, p + 1);
      if (p < text.length && _isDigit(text, p)) {
        final n = _readDigits(text, p);
        fen = n.$1;
        p = n.$2;
      }
    } else {
      return null;
    }

    // 毛位后的数字 → 分位（口语省略"分"字："九块九毛九" → 9.99）
    if (jiao != null) {
      p = _skipSpaces(text, p);
      if (p < text.length && _isDigit(text, p)) {
        final n = _readDigits(text, p);
        fen = n.$1;
        p = n.$2;
        if (p < text.length && text[p] == '分') p += 1;
      }
    }
    // 冗余/直接"分"字消费（如 "X毛Y分"）
    p = _skipSpaces(text, p);
    if (p < text.length && text[p] == '分') p += 1;

    if (jiao == null && fen == null) return null;
    return ((jiao ?? 0) * 0.1 + (fen ?? 0) * 0.01, p);
  }

  // ---------- 工具 ----------

  /// 跳过空白（含全角空格）
  static int _skipSpaces(String text, int pos) {
    while (pos < text.length &&
        (text[pos] == ' ' || text[pos] == '\u3000' || text[pos] == '\t')) {
      pos++;
    }
    return pos;
  }

  static bool _isDigit(String text, int pos) {
    final code = text.codeUnitAt(pos);
    return code >= 0x30 && code <= 0x39; // '0'..'9'
  }

  /// 读取连续数字，返回 (数值, 结束位置)
  static (int, int) _readDigits(String text, int pos) {
    var end = pos;
    while (end < text.length && _isDigit(text, end)) {
      end++;
    }
    return (int.parse(text.substring(pos, end)), end);
  }

  /// 数字片段后（含空白）是否紧跟重量/数量单位
  static bool _isFollowedByIgnoredUnit(String text, int pos) {
    final p = _skipSpaces(text, pos);
    if (p >= text.length) return false;
    for (final unit in _ignoredUnits) {
      if (text.startsWith(unit, p)) return true;
    }
    return false;
  }

  /// 金额表达式 label 起点：向前扩展到最近的标点/句子边界，
  /// 商品名（含隔空格的"豆腐 12.5"）一并包含为原文片段
  static int _labelStart(String text, int digitStart) {
    var start = digitStart;
    while (start > 0) {
      final prev = text[start - 1];
      if (prev == '，' ||
          prev == ',' ||
          prev == '。' ||
          prev == '．' ||
          prev == '？' ||
          prev == '！' ||
          prev == '?' ||
          prev == '!' ||
          prev == '；' ||
          prev == ';' ||
          prev == '\n') {
        break;
      }
      start--;
    }
    return start;
  }
}
