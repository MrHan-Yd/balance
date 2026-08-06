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
      // 空状态：引导文案（原型 .empty，图标带粉色圆底 .mic-ico）
      // 注：Container 构造非 const，此处不能整棵 const
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x29F291A2), // rgba(242,145,162,.16)
              ),
              // 设计话筒图标（ui/button.png 切图 button6，对齐语音键同款）
              child: Image.asset(
                'assets/icons/button6.png',
                width: 30,
                height: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '开始说话，自动记账',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
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
        // 原型 .name：商品名做标题；.name small：识别原文做副行
        final title = item.title.isEmpty ? '手动输入' : item.title;
        final sub = item.label.isNotEmpty && item.raw.isNotEmpty
            ? '“${item.raw}” · ${_formatTime(item.addedAt)}'
            : _formatTime(item.addedAt);
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                // 原型 .item 0 6px 18px rgba(242,145,162,.18)
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListTile(
              // 首字徽章（原型 .badge：34×34 圆角粉底）
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  item.title.isEmpty
                      ? '¥'
                      : String.fromCharCodes(item.title.runes.take(1)),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.amountText,
                  ),
                ),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                      color: Color(0xFFB08A92),
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
