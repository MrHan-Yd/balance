import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../theme/app_theme.dart';

/// 中栏：平滑滚动的购物明细列表（设计文档 §4.6 布局结构·中部 45%）
class ItemList extends StatelessWidget {
  final List<CartItem> items;
  final void Function(CartItem item)? onRemove;

  const ItemList({super.key, required this.items, this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      // 空状态：显示引导文案
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none_rounded, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              '开始说话，自动记账',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: Colors.white10,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey('${item.addedAt.millisecondsSinceEpoch}-$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.danger,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => onRemove?.call(item),
          child: ListTile(
            title: Text(
              item.label.isEmpty ? '未命名' : item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            subtitle: Text(
              _formatTime(item.addedAt),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Text(
              item.amountText,
              style: const TextStyle(
                color: AppColors.amountText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
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
