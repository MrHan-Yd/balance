import 'package:balance/parser/voice_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 解析器冒烟验证（设计文档 §4.2 核心用例；Phase 1 将扩充至 ≥40 例）
void main() {
  group('① 中文数字归一化', () {
    test('基础数字', () {
      expect(VoiceTextParser.normalizeChineseNumbers('牛肉三十八'), '牛肉38');
    });
    test('组合数字', () {
      expect(VoiceTextParser.normalizeChineseNumbers('一百二十三'), '123');
    });
    test('带零', () {
      expect(VoiceTextParser.normalizeChineseNumbers('一万零五'), '10005');
    });
    test('两归一为 2', () {
      expect(VoiceTextParser.normalizeChineseNumbers('两斤'), '2斤');
    });
  });

  group('②③④ 金额提取', () {
    test('孤立数字报价', () {
      final r = VoiceTextParser.parseVoiceTexts('38');
      expect(r.length, 1);
      expect(r.first.value, 38);
    });
    test('块后直接数字 → 一位小数', () {
      final r = VoiceTextParser.parseVoiceTexts('38块5');
      expect(r.single.value, 38.5);
    });
    test('中文数字 + 块 + 毛', () {
      final r = VoiceTextParser.parseVoiceTexts('五块五毛');
      expect(r.single.value, 5.5);
    });
    test('块毛分组合', () {
      final r = VoiceTextParser.parseVoiceTexts('九块九毛九');
      expect(r.single.value, 9.99);
    });
    test('商品名 + 金额', () {
      final r = VoiceTextParser.parseVoiceTexts('豆腐 12.5');
      expect(r.single.value, 12.5);
      expect(r.single.rawText, contains('豆腐'));
    });
    test('单句多金额', () {
      final r = VoiceTextParser.parseVoiceTexts('黄瓜5块，牛肉38');
      expect(r.length, 2);
      expect(r.map((e) => e.value), [5, 38]);
    });
    test('重量单位忽略', () {
      final r = VoiceTextParser.parseVoiceTexts('三斤5块');
      expect(r.length, 1);
      expect(r.single.value, 5);
    });
    test('空输入', () {
      expect(VoiceTextParser.parseVoiceTexts(''), isEmpty);
    });
    test('无金额文本', () {
      expect(VoiceTextParser.parseVoiceTexts('老板这个多少钱'), isEmpty);
    });
  });
}
