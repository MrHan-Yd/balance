import 'package:flutter/material.dart';

/// 滚动数字文本（滚筒/计程表效果）
///
/// 金额按字符拆分为独立 [AnimatedSwitcher]：仅变化的数字位做上下滚动过渡
/// （新数字自下滚入、旧数字向上滚出），不变的字符（逗号/小数点/相同数字）保持静止。
/// 整体用 Semantics 暴露完整金额文本（无障碍与测试读到的都是完整数字）。
class RollingNumberText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const RollingNumberText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < text.length; i++)
            _RollingChar(index: i, char: text[i], style: style),
        ],
      ),
    );
  }
}

class _RollingChar extends StatelessWidget {
  final int index;
  final String char;
  final TextStyle style;

  const _RollingChar({
    required this.index,
    required this.char,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          // 滚筒滚动：新字符自下滚入（forward），旧字符向上滚出（reverse）
          final exiting = animation.status == AnimationStatus.reverse;
          final tween = exiting
              ? Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1))
              : Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);
          return SlideTransition(
            position: tween.animate(animation),
            child: child,
          );
        },
        child: Text(
          char,
          key: ValueKey('$index-$char'),
          style: style,
        ),
      ),
    );
  }
}
