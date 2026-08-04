import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 手动数字小键盘（设计文档 §4.3 兜底：麦克风/识别权限被拒时降级使用）
///
/// 0-9 / 小数点 / 退格 / 确认，与语音模式同样走会话状态机。
class ManualKeypad extends StatefulWidget {
  final void Function(double amount)? onConfirm;

  const ManualKeypad({super.key, this.onConfirm});

  @override
  State<ManualKeypad> createState() => _ManualKeypadState();
}

class _ManualKeypadState extends State<ManualKeypad> {
  final List<String> _digits = [];
  bool _hasDot = false;

  String get _display {
    if (_digits.isEmpty) return '0';
    final s = _digits.join();
    return _hasDot && !s.contains('.') ? '$s.' : s;
  }

  void _input(String d) {
    if (d == '.') {
      if (_hasDot) return;
      _hasDot = true;
    }
    setState(() => _digits.add(d));
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() {
      final removed = _digits.removeLast();
      if (removed == '.') _hasDot = false;
    });
  }

  void _confirm() {
    final value = double.tryParse(_display);
    if (value == null || value <= 0) return;
    widget.onConfirm?.call(value);
    setState(() {
      _digits.clear();
      _hasDot = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            _display,
            style: const TextStyle(
              color: AppColors.amountText,
              fontSize: 40,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.all(4),
                child: k == '⌫'
                    ? _KeyButton(icon: Icons.backspace_outlined, onTap: _backspace)
                    : _KeyButton(label: k, onTap: () => _input(k)),
              ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.micBottom,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _confirm,
                child: const Text('确认', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  const _KeyButton({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, color: AppColors.textPrimary, size: 22)
              : Text(
                  label!,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 20),
                ),
        ),
      ),
    );
  }
}
