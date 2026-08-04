import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../theme/app_theme.dart';

/// 中栏：平滑滚动的购物明细列表（设计文档 §4.6 布局结构·中部 45%）
///
/// 对齐原型 ui/index.html .item：玻璃卡片（圆角 16 + 微光边框）、
/// 首字徽章、名称 + 时间、金额、× 删除按钮；滑动删除（US-006）保留。
class ItemList extends StatelessWidget {
  final List<CartItem> items;
  final void Function(CartItem item)? onRemove;

  const ItemList({super.key, required this.items, this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      // 空状态：引导文案（原型 .empty）
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              '开始说话，自动记账',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              '说“黄瓜五块五”或直接说“38”',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey('${item.addedAt.millisecondsSinceEpoch}-$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => onRemove?.call(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: ListTile(
              // 首字徽章（原型 .badge：34×34 圆角蓝底）
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  item.label.isEmpty
                      ? '¥'
                      : String.fromCharCodes(item.label.runes.take(1)),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.amountText,
                  ),
                ),
              ),
              title: Text(
                item.label.isEmpty ? '手动输入' : item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _formatTime(item.addedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.amountText,
                    style: const TextStyle(
                      color: AppColors.amountText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: () => onRemove?.call(item),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF5C6B80),
                    ),
                    tooltip: '删除',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
