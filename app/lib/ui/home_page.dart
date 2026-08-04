import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/session_state.dart';
import '../speech/speech_service.dart';
import '../state/session_notifier.dart';
import '../state/settings_provider.dart';
import '../theme/app_theme.dart';
import 'history_page.dart';
import 'widgets/item_list.dart';
import 'widgets/manual_keypad.dart';
import 'widgets/mic_button.dart';
import 'widgets/total_card.dart';

/// 主页（设计文档 §4.6 布局：顶部 35% 总价卡 / 中部 45% 明细 / 底部 20% 操作区）
///
/// 对齐原型 ui/index.html：总价卡内撤销按钮，中栏头部历史/键盘/清空图标
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final SpeechService _speech = SpeechService();
  final GlobalKey<ManualKeypadState> _keypadKey =
      GlobalKey<ManualKeypadState>();
  bool _keypadMode = false; // 手动键盘模式（可手动切换 / 权限被拒自动进入）
  bool _speechBlocked = false; // 麦克风/识别权限被拒
  int _failCount = 0; // 连续识别失败计数（≥2 引导切换键盘）

  /// 模式切换过渡动画进度：0 = 语音布局，1 = 键盘布局。
  /// 总价卡/中栏/底栏高度与键盘展开均沿此曲线缓动（260ms easeOutCubic）。
  late final AnimationController _modeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final CurvedAnimation _modeCurve = CurvedAnimation(
    parent: _modeCtrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _modeCurve.dispose();
    _modeCtrl.dispose();
    _speech.dispose();
    super.dispose();
  }

  /// 应用进入后台 → 立即停止识别，防止误触发（设计文档 §4.3 / US-004）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _speech.stop();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onStatusChange: (_) {
        if (mounted) setState(() {});
      },
    );
    if (!mounted) return;
    if (!ok) {
      // 权限被拒 → 降级手动键盘（US-010）；启动即键盘布局，跳过过渡动画
      setState(() {
        _speechBlocked = true;
        _keypadMode = true;
      });
      _modeCtrl.value = 1.0;
    }
  }

  /// 语音结果 → 解析累加；成功轻震动 + 无障碍播报（US-013/014）
  void _onVoiceResult(String text) {
    if (text.isEmpty) return;
    final added = ref.read(sessionProvider.notifier).addParsedText(text);
    _failCount = 0;
    if (added.isEmpty) {
      _onVoiceFail(); // 识别成功但无有效金额 → 同样提示重说
      return;
    }
    HapticFeedback.lightImpact();
    _playSoundIfEnabled();
    final total = ref.read(sessionProvider).total;
    SemanticsService.announce(
      '已添加 ${added.map((e) => e.amount.toStringAsFixed(2)).join('、')} 元，'
      '合计 ${total.toStringAsFixed(2)} 元',
      Directionality.of(context),
    );
  }

  /// 声音反馈：设置开启时播放提示音（默认关闭，菜市场环境，§2.6）
  void _playSoundIfEnabled() {
    if (ref.read(settingsProvider).soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 识别失败：重震动 + 提示；连续失败 2 次引导切换手动键盘（US-004）
  void _onVoiceFail() {
    _failCount++;
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _failCount >= 2
            ? SnackBar(
                content: const Text('连续没听清，建议使用手动键盘'),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: '切换到键盘',
                  onPressed: () {
                    setState(() => _keypadMode = true);
                    _modeCtrl.forward();
                  },
                ),
              )
            : const SnackBar(
                content: Text('没听清，请重说'),
                duration: Duration(milliseconds: 1200),
              ),
      );
    if (_failCount >= 2) _failCount = 0;
  }

  /// 语音识别出错（缺语音服务/权限被拒/引擎异常）：提示原因并引导切换手动键盘。
  /// 此前该路径静默无反馈，表现为"点击语音按钮没反应"
  void _onVoiceError(String message) {
    _failCount++;
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '切换到键盘',
            onPressed: () {
              setState(() => _keypadMode = true);
              _modeCtrl.forward();
            },
          ),
        ),
      );
    if (_failCount >= 2) _failCount = 0;
  }

  /// 手动/语音模式切换（权限被拒时不可切回）
  void _toggleKeypad() {
    if (_speechBlocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('麦克风权限不可用，已自动使用手动输入'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      return;
    }
    setState(() => _keypadMode = !_keypadMode);
    _keypadMode ? _modeCtrl.forward() : _modeCtrl.reverse();
  }

  /// 清空确认弹层：展示当前件数与总额（US-009）
  Future<void> _confirmClear(SessionState session) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '确认清空全部？',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前 ${session.items.length} 件，合计 ${session.total.toStringAsFixed(2)} 元',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
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
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('清空全部'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
    if (confirmed == true) {
      ref.read(sessionProvider.notifier).clear();
      HapticFeedback.mediumImpact();
    }
  }

  /// 历史记录页：右滑 + 淡入过渡（默认转场在桌面端近乎"闪现"，显式加过渡动画）
  void _openHistory() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const HistoryPage(),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.5, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// 设置弹层（§2.6）：声音反馈默认关闭，菜市场环境建议保持关闭
  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final sound = ref.watch(settingsProvider).soundEnabled;
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sound,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setSoundEnabled(v),
                    title: const Text(
                      '声音反馈',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      '累加成功时播放提示音',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
            // 模式切换时三区高度随 _modeCurve 缓动（7/9/4 ↔ 6/11/3），
            // 不再瞬间跳变（原 Expanded flex 直接切换无过渡）
            child: AnimatedBuilder(
              animation: _modeCurve,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final t = _modeCurve.value;
                  final avail = constraints.maxHeight - 24; // 两个 12 间距
                  return Column(
                    children: [
                      // 顶部：总价卡片（含件数/撤销）；键盘模式下让位给键盘
                      SizedBox(
                        height: (7 - t) / 20 * avail,
                        child: TotalCard(
                          total: session.total,
                          itemCount: session.items.length,
                          lastAdded: _lastAddedLabel(session),
                          canUndo: session.items.isNotEmpty,
                          onUndo: () {
                            ref.read(sessionProvider.notifier).undo();
                            HapticFeedback.lightImpact();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 中部：明细头部 + 列表（键盘模式叠加手动键盘）
                      SizedBox(
                        height: (9 + 2 * t) / 20 * avail,
                        child: _buildMiddle(session),
                      ),
                      const SizedBox(height: 12),
                      // 底部：语音主按键 / 键盘模式确认大按钮
                      SizedBox(
                        height: (4 - t) / 20 * avail,
                        child: _buildBottomBar(status),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiddle(SessionState session) {
    final t = _modeCurve.value;
    return Column(
      children: [
        Row(
          children: [
            const Text(
              '购物明细',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded, size: 20),
              color: AppColors.textSecondary,
              tooltip: '历史记录',
            ),
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
              color: AppColors.textSecondary,
              tooltip: '设置',
            ),
            IconButton(
              onPressed: _toggleKeypad,
              tooltip: _keypadMode ? '切换到语音' : '手动输入',
              color: AppColors.textSecondary,
              // 模式图标切换：淡入 + 缩放过渡
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Icon(
                  _keypadMode
                      ? Icons.mic_rounded
                      : Icons.keyboard_alt_rounded,
                  key: ValueKey<bool>(_keypadMode),
                  size: 20,
                ),
              ),
            ),
            IconButton(
              onPressed:
                  session.items.isEmpty ? null : () => _confirmClear(session),
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              color: AppColors.textSecondary,
              tooltip: '全部清空',
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 明细列表（含空状态引导）；键盘模式下手动键盘叠加在列表下方
        Expanded(
          child: ItemList(
            items: session.items,
            onRemove: (item) {
              ref.read(sessionProvider.notifier).removeItem(item);
              HapticFeedback.lightImpact();
            },
          ),
        ),
        // 键盘随 t 展开：Align heightFactor 按内容实际高度缩放（自适应字体放大），
        // ClipRect 裁切呈现"抽屉展开"效果 + 淡入，列表同步让位
        SizedBox(height: 8 * t),
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(
              opacity: t,
              child: ManualKeypad(
                key: _keypadKey,
                onConfirm: (amount) {
                  ref
                      .read(sessionProvider.notifier)
                      .addItem(
                        CartItem(
                          label: '',
                          amount: amount,
                          addedAt: DateTime.now(),
                        ),
                      );
                  HapticFeedback.lightImpact();
                  _playSoundIfEnabled();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 底栏：语音模式为麦克风主键；键盘模式为确认大按钮。
  /// 模式切换时 AnimatedSwitcher 交叉淡入淡出 + 上滑（切换即表明在用手动输入，
  /// 语音键无意义，需要时切回语音即可）
  Widget _buildBottomBar(SpeechSessionStatus status) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _keypadMode ? _buildKeypadBar() : _buildVoiceBar(status),
    );
  }

  Widget _buildKeypadBar() {
    return Column(
      key: const ValueKey('keypad-bar'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.micBottom,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () => _keypadKey.currentState?.confirm(),
            child: const Text(
              '确认',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '正在使用手动输入',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildVoiceBar(SpeechSessionStatus status) {
    return Column(
      key: const ValueKey('voice-bar'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MicButton(
          enabled: true,
          status: status,
          onTap: () async {
            _speech.startSingle(
              onResult: _onVoiceResult,
              onTimeout: _onVoiceFail,
              onError: _onVoiceError,
            );
          },
          onLongPressStart: () async {
            _speech.startContinuous(
              onResult: _onVoiceResult,
              onTimeout: _onVoiceFail,
              onError: _onVoiceError,
            );
          },
          onLongPressEnd: () async => _speech.finish(),
        ),
        const SizedBox(height: 8),
        const Text(
          '点击单句识别 · 按住连续识别',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// 最后一条明细的展示文本（空则返回 ''，卡片显示"开始记账吧"）。
  /// 对齐原型 total-sub："最近: 黄瓜 +¥12.50"
  String _lastAddedLabel(SessionState session) {
    if (session.items.isEmpty) return '';
    final item = session.items.last;
    final name = item.label.isEmpty ? '手动输入' : item.label;
    return '$name +¥${item.amount.toStringAsFixed(2)}';
  }
}
