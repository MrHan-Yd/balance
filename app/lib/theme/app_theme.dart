import 'package:flutter/material.dart';

/// 视觉规范（v0.6 定稿：浅粉 · 奶油系，取自 ui/icon.png 同款配色）
///
/// 主色取自新 App 图标：奶油底色 #F9F7EB + 浅粉 #F9A9B4 / 玫瑰 #E97F8B。
/// 60% 奶油浅粉底 + 30% 玫瑰粉（总价卡/按钮）+ 10% 深玫瑰点缀。
class AppColors {
  AppColors._();

  // 背景：奶油 → 浅粉渐变（对齐原型 body 0% #FBF4EF → #F9EFE8）
  static const Color backgroundTop = Color(0xFFFBF4EF);
  static const Color backgroundBottom = Color(0xFFF9EFE8);

  // 主色/总价卡片：浅粉 → 玫瑰渐变
  static const Color primaryTop = Color(0xFFF9A9B4);
  static const Color primaryBottom = Color(0xFFEF7E8F);

  // 录音按钮：粉 → 玫瑰渐变
  static const Color micTop = Color(0xFFFB9FAE);
  static const Color micBottom = Color(0xFFE97F8B);

  // 卡片（浅色底上的白色玻璃卡）
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0x3DF291A2);

  // 底部抽屉（对齐原型 .sheet 米白底）
  static const Color sheet = Color(0xFFFFF9F8);
  static const Color sheetLine = Color(0x1FE97F8B);

  // 语义色
  static const Color danger = Color(0xFFE04555);

  // 文本与点缀
  static const Color textPrimary = Color(0xFF4A3A3F); // 主体文字深暖棕
  static const Color amountText = Color(0xFFC84E66); // 金额数字深玫瑰
  static const Color accent = Color(0xFFF291A2); // 点缀粉
  static const Color textSecondary = Color(0xFF9C8289);
}

/// 全局主题
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBottom,
      brightness: Brightness.light,
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
