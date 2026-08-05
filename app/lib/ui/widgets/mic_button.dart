import 'package:flutter/material.dart';

import '../../speech/speech_service.dart';
import '../../theme/app_theme.dart';

/// 底栏：全宽"按住/点击 说话"主按键（设计文档 §4.3 / §4.6 布局结构·底部 20%）
///
/// - 点击：单次识别
/// - 按住：持续识别（≥300ms 激活）
/// - 识别中：声波脉冲动画
class MicButton extends StatefulWidget {
  final SpeechSessionStatus status;
  final bool enabled;
  final Future<void> Function()? onTap;
  final Future<void> Function()? onLongPressStart;
  final Future<void> Function()? onLongPressEnd;

  const MicButton({
    super.key,
    required this.status,
    this.enabled = true,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool get _isListening => widget.status == SpeechSessionStatus.listening;

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isListening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_isListening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        !widget.enabled
            ? '手动输入模式'
            : _isListening
            ? '正在聆听…'
            : '按住 · 说话';
    // 聆听时切换语义色红光（原型 .talk-btn.listening：#C62828 → #E53935）
    final gradient = _isListening
        ? const [Color(0xFFC62828), Color(0xFFE53935)]
        : const [AppColors.micTop, AppColors.micBottom];
    // 弥散光晕（原型 0 0 40px rgba(242,145,162,.35)）
    final glow = _isListening
        ? const Color(0x59E53935)
        : const Color(0x59F291A2);
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPressStart:
            widget.enabled ? (_) => widget.onLongPressStart?.call() : null,
        onLongPressEnd:
            widget.enabled ? (_) => widget.onLongPressEnd?.call() : null,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            // 白色描边（原型 .talk-btn border rgba(255,255,255,.30)）
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              // 深影（原型 0 14px 34px rgba(210,110,130,.35)）
              BoxShadow(
                color: _isListening
                    ? const Color(0x40C21E1E)
                    : const Color(0x59D26E82),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
              // 弥散光晕（原型 0 0 40px rgba(242,145,162,.35)）
              BoxShadow(
                color: glow,
                blurRadius: 40,
                spreadRadius: _isListening ? 1 + _pulse.value * 3 : 0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 顶部高光线（原型 .talk-btn::after rgba(255,255,255,.55)）
              const Positioned(
                top: 0,
                left: 22,
                right: 22,
                height: 1.5,
                child: IgnorePointer(
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
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder:
                        (_, child) => Transform.scale(
                          scale: 1 + _pulse.value * 0.25,
                          child: child,
                        ),
                    // 设计图标 button6（麦克风）；聆听中切换声波动画图标
                    child: _isListening
                        ? const Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                            size: 30,
                          )
                        : Image.asset(
                            'assets/icons/button6.png',
                            width: 32,
                            height: 32,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
