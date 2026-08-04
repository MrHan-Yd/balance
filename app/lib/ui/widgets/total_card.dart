import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 顶栏：半透明毛玻璃总价卡片（设计文档 §4.6 布局结构·顶部 35%）
class TotalCard extends StatelessWidget {
  final double total;

  const TotalCard({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryTop, AppColors.primaryBottom],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTop.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '当前总价',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTotal(total),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 68,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 千分位 + 两位小数："¥1,234.56"
  static String _formatTotal(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer('¥');
    for (int i = 0; i < intPart.length; i++) {
      buf.write(intPart[i]);
      final remaining = intPart.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    buf.write('.${parts[1]}');
    return buf.toString();
  }
}
