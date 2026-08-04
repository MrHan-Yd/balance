import 'package:balance/keypad/keypad_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// 手动键盘输入校验（US-010：最多一位小数、单小数点、≤ 99999）
void main() {
  group('数字输入', () {
    test('初始输入', () {
      expect(KeypadLogic.input('0', '5'), '5');
    });
    test('前导零被替换', () {
      expect(KeypadLogic.input('0', '3'), '3');
    });
    test('连按 0 保持单零', () {
      expect(KeypadLogic.input('0', '0'), '0');
    });
    test('连续数字拼接', () {
      var s = KeypadLogic.input('0', '3');
      s = KeypadLogic.input(s, '8');
      expect(s, '38');
    });
    test('非数字按键忽略', () {
      expect(KeypadLogic.input('38', 'a'), '38');
    });
  });

  group('小数点', () {
    test('整数后加点', () {
      expect(KeypadLogic.input('38', '.'), '38.');
    });
    test('单小数点：重复点忽略', () {
      expect(KeypadLogic.input('38.', '.'), '38.');
    });
    test('0 后加点', () {
      expect(KeypadLogic.input('0', '.'), '0.');
    });
    test('小数输入', () {
      var s = KeypadLogic.input('38.', '5');
      expect(s, '38.5');
    });
  });

  group('一位小数限制', () {
    test('第二位小数不响应', () {
      var s = KeypadLogic.input('38.5', '5');
      s = KeypadLogic.input(s, '1');
      expect(s, '38.5');
    });
    test('第一位小数可输入', () {
      expect(KeypadLogic.input('38.', '5'), '38.5');
    });
  });

  group('上限 99999', () {
    test('9999 + 9 = 99999', () {
      expect(KeypadLogic.input('9999', '9'), '99999');
    });
    test('99999 后再输入不响应', () {
      expect(KeypadLogic.input('99999', '9'), '99999');
    });
    test('99999.9 小数上限可达', () {
      var s = '99999';
      s = KeypadLogic.input(s, '.');
      s = KeypadLogic.input(s, '9');
      s = KeypadLogic.input(s, '9'); // 第二位小数不响应
      expect(s, '99999.9');
      expect(KeypadLogic.confirm(s), 99999.9);
    });
    test('99999.9 后再输小数不响应', () {
      expect(KeypadLogic.input('99999.9', '9'), '99999.9');
    });
  });

  group('退格', () {
    test('删除末位', () {
      expect(KeypadLogic.backspace('38.5'), '38.');
    });
    test('0. 退到 0', () {
      expect(KeypadLogic.backspace('0.'), '0');
    });
    test('0 退到空', () {
      expect(KeypadLogic.backspace('0'), '');
    });
    test('空串退格安全', () {
      expect(KeypadLogic.backspace(''), '');
    });
    test('删小数点后可用', () {
      var s = KeypadLogic.backspace('38.5');
      s = KeypadLogic.backspace(s); // '38.'
      s = KeypadLogic.input(s, '2');
      expect(s, '382');
    });
  });

  group('确认校验', () {
    test('正常金额', () {
      expect(KeypadLogic.confirm('38.5'), 38.5);
    });
    test('整数金额', () {
      expect(KeypadLogic.confirm('38'), 38);
    });
    test('0 无效', () {
      expect(KeypadLogic.confirm('0'), isNull);
    });
    test('0.0 无效', () {
      expect(KeypadLogic.confirm('0.0'), isNull);
    });
    test('空串无效', () {
      expect(KeypadLogic.confirm(''), isNull);
    });
    test('小数点结尾无效', () {
      expect(KeypadLogic.confirm('38.'), isNull);
    });
    test('超上限无效', () {
      expect(KeypadLogic.confirm('100000'), isNull);
    });
    test('上限 99999.9 有效', () {
      expect(KeypadLogic.confirm('99999.9'), 99999.9);
    });
    test('两位小数 99999.99 无效', () {
      expect(KeypadLogic.confirm('99999.99'), isNull);
    });
  });
}
