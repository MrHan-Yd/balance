import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/history_day.dart';
import '../../state/history_provider.dart';
import '../../theme/app_theme.dart';

/// 历史记录抽屉（设计文档 §4.4 / US-012）：按天分组，查看/删除单日。
///
/// 从底部滑出（对齐原型 ui/index.html 历史弹层 .sheet），替代原全屏页面。
class HistorySheet extends ConsumerWidget {
  const HistorySheet({super.key});

  /// 弹出历史抽屉
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        // 原型 .sheet border rgba(233,127,139,.18)
        side: BorderSide(color: Color(0x2EE97F8B)),
      ),
      builder: (_) => const HistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(historyProvider).days;
    final maxH = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // grab 条（原型 .sheet .grab）
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      '暂无历史记录',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: days.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _DayCard(day: days[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单日卡片：日期 + 件数 + 总额；点击展开明细，长按/删除图标删除单日
class _DayCard extends ConsumerWidget {
  final HistoryDay day;

  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.card,
      elevation: 0,
      shadowColor: AppColors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: ExpansionTile(
        title: Text(
          day.dayKey,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '共 ${day.items.length} 件',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTotal(day.total),
              style: const TextStyle(
                color: AppColors.amountText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.danger,
              ),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        children: [
          for (final item in day.items)
            ListTile(
              dense: true,
              title: Text(
                item.title.isEmpty ? '未命名' : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                _formatTime(item.addedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: Text(
                item.amountText,
                style: const TextStyle(
                  color: AppColors.amountText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.sheet,
            title: const Text(
              '删除当日历史？',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              '将删除 ${day.dayKey} 的 ${day.items.length} 条记录，且不可恢复。',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(historyProvider.notifier).deleteDay(day.dayKey);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  '删除',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
    );
  }
}

/// 千分位 + 两位小数："¥1,234.56"
String _formatTotal(double value) {
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

String _formatTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
