import 'package:flutter/material.dart';

/// 视觉规范（设计文档 §4.6，v0.5 定稿：60-30-10 法则）
///
/// 60% 中性深灰蓝底 + 30% 沉稳蓝 + 10% 电光蓝点缀
class AppColors {
  AppColors._();

  // 背景：中性深灰蓝渐变
  static const Color backgroundTop = Color(0xFF0E131A);
  static const Color backgroundBottom = Color(0xFF080B10);

  // 主色/总价卡片：沉稳蓝灰渐变
  static const Color primaryTop = Color(0xFF2E5C96);
  static const Color primaryBottom = Color(0xFF1B3A66);

  // 录音按钮：沉稳蓝发光渐变
  static const Color micTop = Color(0xFF2F6FCC);
  static const Color micBottom = Color(0xFF1C4E8E);

  // 语义色
  static const Color danger = Color(0xFFE53935);

  // 文本与点缀
  static const Color textPrimary = Color(0xFFE8F1FA); // 主体文字暖白
  static const Color amountText = Color(0xFF90CAF9); // 金额数字淡蓝
  static const Color accent = Color(0xFF4FC3F7); // 电光蓝（仅 10% 点缀）
  static const Color textSecondary = Color(0xFF8A94A6);
}

/// 全局主题
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryTop,
      brightness: Brightness.dark,
      surface: AppColors.backgroundTop,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundTop,
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
