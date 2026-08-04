import 'package:flutter/material.dart';

import '../../keypad/keypad_logic.dart';
import '../../theme/app_theme.dart';

/// 手动数字小键盘（设计文档 §4.3 兜底：麦克风/识别权限被拒时降级使用）
///
/// 0-9 / 小数点 / 退格，与语音模式同样走会话状态机（US-010）。
/// 输入校验见 [KeypadLogic]：最多一位小数、单小数点、≤ 99999。
/// 确认按钮在键盘模式下由底栏承担（[ManualKeypadState.confirm]）。
class ManualKeypad extends StatefulWidget {
  final void Function(double amount)? onConfirm;

  const ManualKeypad({super.key, this.onConfirm});

  @override
  State<ManualKeypad> createState() => ManualKeypadState();
}

class ManualKeypadState extends State<ManualKeypad> {
  String _display = '0';

  /// 确认当前输入（底栏确认大按钮入口）：非法输入不响应并提示
  void confirm() {
    final value = KeypadLogic.confirm(_display);
    if (value == null) {
      // 非法输入不响应（US-010）
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('金额需大于 0 且不超过 99,999'),
            duration: Duration(milliseconds: 1000),
          ),
        );
      return;
    }
    widget.onConfirm?.call(value);
    setState(() => _display = '0');
  }

  void _input(String key) {
    setState(() => _display = KeypadLogic.input(_display, key));
  }

  void _backspace() {
    setState(() => _display = KeypadLogic.backspace(_display));
  }

  @override
  Widget build(BuildContext context) {
    // 3 列数字区（无确认键，宽松排布不贴边）；确认由底栏大按钮承担
    // 外层滚动兜底：极端小屏/字体放大时不破版（US-014 支持 200% 字体缩放）
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              _display,
              style: const TextStyle(
                color: AppColors.amountText,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _keyRow(['1', '2', '3']),
          const SizedBox(height: 6),
          _keyRow(['4', '5', '6']),
          const SizedBox(height: 6),
          _keyRow(['7', '8', '9']),
          const SizedBox(height: 6),
          _keyRow(['.', '0', '⌫']),
        ],
      ),
    );
  }

  /// 一行三个按键（高 36、横向留 4 间距，视觉不贴边）
  Widget _keyRow(List<String> keys) {
    return Row(
      children: [
        for (final k in keys)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 36,
                child:
                    k == '⌫'
                        ? _KeyButton(
                          icon: Icons.backspace_outlined,
                          onTap: _backspace,
                        )
                        : _KeyButton(label: k, onTap: () => _input(k)),
              ),
            ),
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child:
              icon != null
                  ? Icon(icon, color: AppColors.textPrimary, size: 24)
                  : Text(
                    label!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                    ),
                  ),
        ),
      ),
    );
  }
}
