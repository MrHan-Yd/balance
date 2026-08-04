/// 手动键盘输入校验（US-010 / 开发文档 §3 keypad）
///
/// 规则：单小数点、最多一位小数（菜市场报价习惯）、0 < 值 ≤ 99999，非法输入不响应。
/// 纯 Dart，可独立单测。
class KeypadLogic {
  KeypadLogic._();

  /// 金额上限（对齐解析器 maxAmount）
  static const double maxAmount = 99999;

  /// 最多一位小数
  static const int maxFractionDigits = 1;

  /// 输入单个按键（数字或 '.'），返回输入后的显示串；非法输入不响应
  static String input(String current, String key) {
    if (key == '.') return _inputDot(current);
    if (!_digitRegex.hasMatch(key)) return current; // 仅 0-9
    return _inputDigit(current, key);
  }

  static String _inputDigit(String cur, String d) {
    if (cur == '0') return d == '0' ? cur : d; // 前导零替换
    if (cur == '0.') return '0.$d';

    final dotIdx = cur.indexOf('.');
    if (dotIdx >= 0) {
      // 小数区：最多两位小数
      if (cur.length - dotIdx - 1 >= maxFractionDigits) return cur;
      return cur + d;
    }
    // 整数区：拼接后不得超上限
    final next = cur + d;
    if (double.tryParse(next) != null && double.parse(next) > maxAmount) {
      return cur;
    }
    return next;
  }

  static String _inputDot(String cur) {
    if (cur.contains('.')) return cur;
    return cur == '0' ? '0.' : '$cur.';
  }

  /// 退格：删除末位；'0' 退到空串，'0.' 退到 '0'
  static String backspace(String cur) {
    if (cur.isEmpty || cur == '0') return '';
    if (cur == '0.') return '0';
    return cur.substring(0, cur.length - 1);
  }

  /// 确认：校验并转为金额；非法（空 / 0 / 超上限 / 格式错）返回 null
  static double? confirm(String cur) {
    // 格式：整数 或 "整数.一位小数"；拒绝 "38." / "." / 空串（double.tryParse 会放过结尾小数点）
    if (!_amountRegex.hasMatch(cur)) return null;
    final v = double.tryParse(cur);
    if (v == null || v <= 0) return null;
    // 上限按整数部分判定：小数不推高上限，99999.9 可达（99999.9 > 99999 会被 double 比较误杀）
    final intPart = cur.split('.').first;
    if (double.parse(intPart) > maxAmount) return null;
    return v;
  }

  static final RegExp _digitRegex = RegExp(r'^\d$');
  static final RegExp _amountRegex = RegExp(r'^\d+(\.\d)?$');
}
