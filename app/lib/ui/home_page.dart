import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/session_state.dart';
import '../speech/speech_service.dart';
import '../state/session_notifier.dart';
import '../theme/app_theme.dart';
import 'widgets/item_list.dart';
import 'widgets/manual_keypad.dart';
import 'widgets/mic_button.dart';
import 'widgets/total_card.dart';

/// 主页（设计文档 §4.6 布局：顶部 35% 总价卡 / 中部 45% 明细 / 底部 20% 操作区）
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  final SpeechService _speech = SpeechService();
  bool _keypadMode = false; // 权限被拒 → 手动键盘兜底

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.stop();
    super.dispose();
  }

  /// 应用进入后台 → 立即停止识别，防止误触发（设计文档 §4.3）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _speech.stop();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(onStatusChange: (_) {
      if (mounted) setState(() {});
    });
    if (!mounted) return;
    if (!ok) setState(() => _keypadMode = true); // 权限被拒 → 降级手动键盘
  }

  void _onVoiceResult(String text) {
    if (text.isEmpty) return;
    ref.read(sessionProvider.notifier).addParsedText(text);
    if (text.isNotEmpty) HapticFeedback.lightImpact(); // 识别成功轻震动
  }

  void _onVoiceFail() {
    HapticFeedback.heavyImpact(); // 识别失败重震动 + 提示
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('没听清，请重说'),
        duration: Duration(milliseconds: 1200),
      ));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('确认清空全部？',
                  style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('清空'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) ref.read(sessionProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final status = _speech.status;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // 顶部 35%：总价卡片
                Expanded(flex: 3, child: TotalCard(total: session.total)),
                const SizedBox(height: 12),
                // 中部 45%：明细列表
                Expanded(
                  flex: 4,
                  child: _keypadMode
                      ? ManualKeypad(
                          onConfirm: (amount) {
                            ref.read(sessionProvider.notifier).addItem(CartItem(
                                  label: '',
                                  amount: amount,
                                  addedAt: DateTime.now(),
                                ));
                          },
                        )
                      : ItemList(
                          items: session.items,
                          onRemove: (item) => ref
                              .read(sessionProvider.notifier)
                              .addItem(CartItem(
                                label: item.label,
                                amount: -item.amount,
                                addedAt: DateTime.now(),
                              )),
                        ),
                ),
                const SizedBox(height: 12),
                // 底部 20%：操作区
                Expanded(flex: 2, child: _buildBottomBar(status, session)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(SpeechSessionStatus status, SessionState session) {
    return Column(
      children: [
        MicButton(
          status: status,
          onTap: _keypadMode
              ? null
              : () async {
                  _speech.startSingle(
                    onResult: _onVoiceResult,
                    onTimeout: _onVoiceFail,
                  );
                },
          onLongPressStart: _keypadMode
              ? null
              : () async {
                  _speech.startContinuous(onResult: _onVoiceResult);
                },
          onLongPressEnd: _keypadMode ? null : () async => _speech.stop(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed:
                  session.items.isEmpty ? null : () => ref.read(sessionProvider.notifier).undo(),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('撤销'),
            ),
            const SizedBox(width: 24),
            TextButton.icon(
              onPressed: session.items.isEmpty ? null : _confirmClear,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('清空'),
            ),
          ],
        ),
      ],
    );
  }
}
