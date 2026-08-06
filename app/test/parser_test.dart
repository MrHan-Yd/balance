import 'package:balance/parser/voice_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 解析器用例表（设计文档 §7：≥40 例，验收口径全绿）
void main() {
  group('① 中文数字归一化', () {
    test('基础数字', () {
      expect(VoiceTextParser.normalizeChineseNumbers('牛肉三十八'), '牛肉38');
    });
    test('组合数字：一百二十三', () {
      expect(VoiceTextParser.normalizeChineseNumbers('一百二十三'), '123');
    });
    test('带零：一万零五', () {
      expect(VoiceTextParser.normalizeChineseNumbers('一万零五'), '10005');
    });
    test('两归一为 2', () {
      expect(VoiceTextParser.normalizeChineseNumbers('两斤'), '2斤');
    });
    test('十一（十开头省略一）', () {
      expect(VoiceTextParser.normalizeChineseNumbers('十一'), '11');
    });
    test('二十（整十）', () {
      expect(VoiceTextParser.normalizeChineseNumbers('二十'), '20');
    });
    test('三百二十', () {
      expect(VoiceTextParser.normalizeChineseNumbers('三百二十'), '320');
    });
    test('一百零三', () {
      expect(VoiceTextParser.normalizeChineseNumbers('一百零三'), '103');
    });
    test('二千零五', () {
      expect(VoiceTextParser.normalizeChineseNumbers('二千零五'), '2005');
    });
    test('五万', () {
      expect(VoiceTextParser.normalizeChineseNumbers('五万'), '50000');
    });
    test('十二万（超上限值，验证归一化本身）', () {
      expect(VoiceTextParser.normalizeChineseNumbers('十二万'), '120000');
    });
    test('数字与中文混排', () {
      expect(VoiceTextParser.normalizeChineseNumbers('黄瓜5块，牛肉三十八'), '黄瓜5块，牛肉38');
    });
  });

  group('②③④ 金额提取：纯数字报价', () {
    test('孤立数字', () {
      final r = VoiceTextParser.parseVoiceTexts('38');
      expect(r.length, 1);
      expect(r.single.value, 38);
    });
    test('带小数孤立数字', () {
      expect(VoiceTextParser.parseVoiceTexts('12.5').single.value, 12.5);
    });
    test('精度 1.99', () {
      expect(VoiceTextParser.parseVoiceTexts('1.99').single.value, 1.99);
    });
    test('0.5 有效', () {
      expect(VoiceTextParser.parseVoiceTexts('0.5').single.value, 0.5);
    });
    test('纯中文数字报价', () {
      expect(VoiceTextParser.parseVoiceTexts('三十八').single.value, 38);
    });
    test('带首尾空格', () {
      expect(VoiceTextParser.parseVoiceTexts('  38  ').single.value, 38);
    });
  });

  group('②③④ 金额提取：金额单位映射', () {
    test('块', () {
      expect(VoiceTextParser.parseVoiceTexts('三块').single.value, 3);
    });
    test('元', () {
      expect(VoiceTextParser.parseVoiceTexts('三元').single.value, 3);
    });
    test('毛', () {
      expect(VoiceTextParser.parseVoiceTexts('五毛').single.value, 0.5);
    });
    test('角', () {
      expect(VoiceTextParser.parseVoiceTexts('三角').single.value, 0.3);
    });
    test('分', () {
      expect(VoiceTextParser.parseVoiceTexts('九分').single.value, 0.09);
    });
    test('块后直接数字 → 一位小数', () {
      expect(VoiceTextParser.parseVoiceTexts('38块5').single.value, 38.5);
    });
    test('中文数字 + 块 + 毛', () {
      expect(VoiceTextParser.parseVoiceTexts('五块五毛').single.value, 5.5);
    });
    test('块毛分组合', () {
      expect(VoiceTextParser.parseVoiceTexts('九块九毛九').single.value, 9.99);
    });
    test('块 + 分（一位变分位）', () {
      expect(VoiceTextParser.parseVoiceTexts('五块五分').single.value, 5.05);
    });
    test('毛位后省略分字', () {
      expect(VoiceTextParser.parseVoiceTexts('九块九毛九').single.value, 9.99);
    });
    test('中文数字组合金额', () {
      expect(VoiceTextParser.parseVoiceTexts('三十八块五').single.value, 38.5);
    });
    test('三位金额', () {
      expect(VoiceTextParser.parseVoiceTexts('一百二十三块四毛五分').single.value, 123.45);
    });
    test('纯小数毛分组合', () {
      expect(VoiceTextParser.parseVoiceTexts('五毛五').single.value, 0.55);
    });
  });

  group('②③④ 金额提取：单句多金额', () {
    test('两笔：中文 + 数字', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜5块，牛肉38');
      expect(r.length, 2);
      expect(r.map((e) => e.value), [5, 38]);
    });
    test('三笔', () {
      final r = VoiceTextParser.parseVoiceTexts('苹果3元，梨4.5元，枣1块');
      expect(r.map((e) => e.value), [3, 4.5, 1]);
    });
    test('全部中文金额', () {
      final r = VoiceTextParser.parseVoiceTexts('白菜两块，土豆三块五');
      expect(r.map((e) => e.value), [2, 3.5]);
    });
    test('rawText 保留原文片段', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜5块，牛肉38');
      expect(r[0].rawText, '黄瓜5块');
      expect(r[1].rawText, '牛肉38');
    });
  });

  group('②③④ 过滤：重量/数量单位', () {
    test('三斤忽略', () {
      expect(VoiceTextParser.parseVoiceTexts('三斤'), isEmpty);
    });
    test('五个忽略', () {
      expect(VoiceTextParser.parseVoiceTexts('五个'), isEmpty);
    });
    test('阿拉伯数字 + 单位', () {
      expect(VoiceTextParser.parseVoiceTexts('3斤'), isEmpty);
      expect(VoiceTextParser.parseVoiceTexts('10个'), isEmpty);
    });
    test('两袋忽略', () {
      expect(VoiceTextParser.parseVoiceTexts('两袋'), isEmpty);
    });
    test('三斤5块只取金额', () {
      final r = VoiceTextParser.parseVoiceTexts('三斤5块');
      expect(r.length, 1);
      expect(r.single.value, 5);
    });
    test('5块3斤：重量单位阻断小数位', () {
      final r = VoiceTextParser.parseVoiceTexts('5块3斤');
      expect(r.length, 1);
      expect(r.single.value, 5);
    });
    test('2根黄瓜3块', () {
      final r = VoiceTextParser.parseVoiceTexts('2根黄瓜3块');
      expect(r.map((e) => e.value), [3]);
    });
    test('多笔中混重量只取金额', () {
      final r = VoiceTextParser.parseVoiceTexts('土豆3个，青菜2块');
      expect(r.map((e) => e.value), [2]);
    });
  });

  group('④ 过滤：范围与无效输入', () {
    test('边界 99999', () {
      expect(VoiceTextParser.parseVoiceTexts('99999').single.value, 99999);
    });
    test('超上限 100000', () {
      expect(VoiceTextParser.parseVoiceTexts('100000'), isEmpty);
    });
    test('小数不推高上限：99999.99 可达（整数部分 99999）', () {
      expect(VoiceTextParser.parseVoiceTexts('99999.99').single.value,
          99999.99);
    });
    test('中文超上限', () {
      expect(VoiceTextParser.parseVoiceTexts('十二万'), isEmpty);
    });
    test('0 无效', () {
      expect(VoiceTextParser.parseVoiceTexts('0'), isEmpty);
    });
    test('空输入', () {
      expect(VoiceTextParser.parseVoiceTexts(''), isEmpty);
      expect(VoiceTextParser.parseVoiceTexts('   '), isEmpty);
    });
    test('无金额文本', () {
      expect(VoiceTextParser.parseVoiceTexts('老板这个多少钱'), isEmpty);
    });
    test('乱语', () {
      expect(VoiceTextParser.parseVoiceTexts('asdfgh qwerty'), isEmpty);
    });
    test('纯标点', () {
      expect(VoiceTextParser.parseVoiceTexts('？？？'), isEmpty);
    });
  });

  group('商品名与原文片段', () {
    test('商品名 + 空格 + 金额', () {
      final r = VoiceTextParser.parseVoiceTexts('豆腐 12.5');
      expect(r.single.value, 12.5);
      expect(r.single.rawText, contains('豆腐'));
      expect(r.single.name, '豆腐');
    });
    test('无分隔商品名', () {
      final r = VoiceTextParser.parseVoiceTexts('豆腐38');
      expect(r.single.value, 38);
      expect(r.single.rawText, '豆腐38');
      expect(r.single.name, '豆腐');
    });
    test('商品名 + 中文金额', () {
      final r = VoiceTextParser.parseVoiceTexts('牛肉三十八');
      expect(r.single.value, 38);
      expect(r.single.rawText, '牛肉38');
      expect(r.single.name, '牛肉');
    });
    test('多句以标点分隔', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜5块。牛肉38！');
      expect(r.map((e) => e.value), [5, 38]);
    });
    test('黄瓜五块五 → 黄瓜是标题，5.5 是金额', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜五块五');
      expect(r.single.name, '黄瓜');
      expect(r.single.value, 5.5);
      expect(r.single.rawText, '黄瓜5块5');
    });
    test('纯报价 name 为空', () {
      expect(VoiceTextParser.parseVoiceTexts('38').single.name, '');
      expect(VoiceTextParser.parseVoiceTexts('五块五').single.name, '');
    });
    test('多笔各取各的 name', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜5块，牛肉38');
      expect(r[0].name, '黄瓜');
      expect(r[1].name, '牛肉');
    });
  });

  group('⓪ 变体归一化（Whisper 繁体/同音字输出）', () {
    test('同音字快 → 块："5快5"', () {
      expect(VoiceTextParser.parseVoiceTexts('5快5').single.value, 5.5);
    });
    test('繁体塊："5塊5"', () {
      expect(VoiceTextParser.parseVoiceTexts('5塊5').single.value, 5.5);
    });
    test('繁体兩："兩块"', () {
      expect(VoiceTextParser.parseVoiceTexts('兩块').single.value, 2);
    });
    test('口语小数：五点五', () {
      expect(VoiceTextParser.parseVoiceTexts('五点五').single.value, 5.5);
    });
    test('混排小数：5点5', () {
      expect(VoiceTextParser.parseVoiceTexts('5点5').single.value, 5.5);
    });
    test('整句同音：黄瓜五快五', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜五快五');
      expect(r.single.value, 5.5);
      expect(r.single.name, '黄瓜');
    });
  });

  group('无标点连续多笔（Whisper 中文输出基本无标点）', () {
    test('label 不跨笔累积（真机回归场景）', () {
      final r = VoiceTextParser.parseVoiceTexts('5块5 上18 黄瓜55块5');
      expect(r.length, 3);
      expect(r.map((e) => e.value), [5.5, 18, 55.5]);
      expect(r[0].rawText, '5块5');
      expect(r[1].rawText, '上18');
      expect(r[2].rawText, '黄瓜55块5');
      expect(r[2].name, '黄瓜');
    });
    test('两笔紧连无空格', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜5块5牛肉38');
      expect(r.map((e) => e.value), [5.5, 38]);
      expect(r[0].rawText, '黄瓜5块5');
      expect(r[1].rawText, '牛肉38');
      expect(r[1].name, '牛肉');
    });
    test('孤立报价连续两笔不互相吞并', () {
      final r = VoiceTextParser.parseVoiceTexts('38 12.5');
      expect(r.map((e) => e.value), [38, 12.5]);
      expect(r[1].rawText, '12.5');
    });
  });

  group('连续纯数字报价（Whisper 快语速误听）', () {
    test('真机输出：5块6块6几块钱8块8 9块9', () {
      final r = VoiceTextParser.parseVoiceTexts('5块6块6几块钱8块8 9块9');
      expect(r.map((e) => e.value), [5, 6.6, 8.8, 9.9]);
      expect(r.map((e) => e.rawText), ['5块', '6块6', '8块8', '9块9']);
      expect(r.map((e) => e.name), ['', '', '', '']);
    });
    test('无空格粘连：5块6块6', () {
      final r = VoiceTextParser.parseVoiceTexts('5块6块6');
      expect(r.map((e) => e.value), [5, 6.6]);
      expect(r[1].rawText, '6块6');
    });
    test('有空格：8块8 9块9（分位不吞下一笔）', () {
      final r = VoiceTextParser.parseVoiceTexts('8块8 9块9');
      expect(r.map((e) => e.value), [8.8, 9.9]);
    });
    test('规范间距：5块5 6块6', () {
      final r = VoiceTextParser.parseVoiceTexts('5块5 6块6');
      expect(r.map((e) => e.value), [5.5, 6.6]);
    });
    test('几块钱不污染下一笔 label', () {
      final r = VoiceTextParser.parseVoiceTexts('几块钱8块8');
      expect(r.length, 1);
      expect(r.single.value, 8.8);
      expect(r.single.name, '');
    });
    test('纯单位残留 label 清空（块8块8）', () {
      final r = VoiceTextParser.parseVoiceTexts('块8块8');
      expect(r.length, 1);
      expect(r.single.value, 8.8);
      expect(r.single.name, '');
    });
  });
}
