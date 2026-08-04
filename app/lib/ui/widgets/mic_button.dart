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
  final Future<void> Function()? onTap;
  final Future<void> Function()? onLongPressStart;
  final Future<void> Function()? onLongPressEnd;

  const MicButton({
    super.key,
    required this.status,
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
    final label = _isListening ? '正在聆听…' : '按住 / 点击 说话';
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => widget.onLongPressStart?.call(),
      onLongPressEnd: (_) => widget.onLongPressEnd?.call(),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.micTop, AppColors.micBottom],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.micTop.withValues(alpha: _isListening ? 0.55 : 0.3),
              blurRadius: _isListening ? 26 : 16,
              spreadRadius: 1 + _pulse.value * 3,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: 1 + _pulse.value * 0.25,
                child: child,
              ),
              child: Icon(
                _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 30,
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
      ),
    );
  }
}
