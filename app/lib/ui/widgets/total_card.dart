import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'rolling_number_text.dart';

/// 顶栏：电光蓝发光总价卡片（设计文档 §4.6 布局结构·顶部 35%）
///
/// 对齐原型 ui/index.html .total-card：
/// - 实心蓝渐变（165deg：右上亮 → 左下暗，非毛玻璃半透明）
/// - 黑色深投影 + 全包裹电光蓝光晕（box-shadow: 0 0 60px rgba(79,195,247,.16)）
/// - 当前总价 + "本次共 N 件" 胶囊
/// - 独立 ¥ 符号 + 大号金额（bump 弹跳动画 + 电光辉光）
/// - 最近一条原文 + "撤销上一笔"按钮
/// - 顶部高光线 + 底部弥散电光斑装饰
class TotalCard extends StatelessWidget {
  final double total;
  final int itemCount;
  final String lastAdded;
  final bool canUndo;
  final VoidCallback? onUndo;

  const TotalCard({
    super.key,
    required this.total,
    this.itemCount = 0,
    this.lastAdded = '',
    this.canUndo = false,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    // 阴影放外层：ClipRRect 会裁掉内层溢出的投影，光晕必须画在裁剪之外
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // 深色投影（原型 0 24px 50px rgba(200,110,130,.28)：粉色投影而非黑色）
          BoxShadow(
            color: const Color(0x47C86E82),
            blurRadius: 50,
            offset: const Offset(0, 24),
          ),
          // 全包裹粉色光晕（原型 0 0 60px rgba(242,145,162,.38)）
          BoxShadow(
            color: const Color(0x61F291A2),
            blurRadius: 60,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            // 原型 linear-gradient(165deg)：左上亮粉 → 右下玫瑰
            //（CSS 165deg 起点在 345° 即左上，终点在 165° 即右下）
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryTop, AppColors.primaryBottom],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Stack(
            children: [
              // 顶部高光线（原型 ::before）
              const Positioned(
                top: 0,
                left: 24,
                right: 24,
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x8CFFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // 底部弥散光斑（原型 ::after + filter: blur(6px)；
              // 必须模糊，否则硬边圆被圆角裁剪后会变成"贝壳"形）
              Positioned(
                bottom: -70,
                left: -40,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x24FFFFFF),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabelRow(),
                  // 金额行自适应：空间不足时整体等比缩小，避免键盘模式下溢出
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildAmountRow(),
                    ),
                  ),
                  _buildSubRow(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 标签行：当前总价 + 件数胶囊
  Widget _buildLabelRow() {
    return Row(
      children: [
        const Text(
          '当前总价',
          style: TextStyle(
            color: Color(0xE6FFFFFF), // 原型 .total-label opacity .9
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22), // 原型 rgba(255,255,255,.22)
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '本次共 $itemCount 件',
            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11),
          ),
        ),
      ],
    );
  }

  /// 金额行：独立 ¥ 符号 + 大号金额（数字滚动 bump 动画，对齐原型 .total-amount）
  /// 注：不含 Expanded/flex，配合外层 FittedBox 做等比缩放
  Widget _buildAmountRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text(
          '¥',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        // 滚筒式数字滚动：仅变化的数字位滚动过渡（comma/小数点/相同位保持静止）
        RollingNumberText(
          text: _formatTotal(total),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 60,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            fontFeatures: [FontFeature.tabularFigures()],
            shadows: [
              // 白色辉光（原型 text-shadow: 0 0 28px rgba(255,255,255,.35)）
              Shadow(color: Color(0x59FFFFFF), blurRadius: 28),
            ],
          ),
        ),
      ],
    );
  }

  /// 底部行：最近一条 + 撤销按钮（button1 撤销图标）
  Widget _buildSubRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            lastAdded.isEmpty ? '开始记账吧' : '最近: $lastAdded',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xD9FFFFFF), // 原型 .total-sub opacity .85
              fontSize: 12,
            ),
          ),
        ),
        Tooltip(
          message: '撤销上一笔',
          child: TextButton(
            key: const Key('btnUndo'),
            onPressed: canUndo ? onUndo : null,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Image.asset(
              'assets/icons/button1.png',
              width: 20,
              height: 20,
            ),
          ),
        ),
      ],
    );
  }

  /// 千分位 + 两位小数："1,234.56"（¥ 符号由金额行单独渲染）
  static String _formatTotal(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      buf.write(intPart[i]);
      final remaining = intPart.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    buf.write('.${parts[1]}');
    return buf.toString();
  }
}
