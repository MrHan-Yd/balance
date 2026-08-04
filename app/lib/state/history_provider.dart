import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cart_item.dart';
import '../models/history_day.dart';
import 'storage_providers.dart';

/// 历史状态：按天分组（最新日期在前）
class HistoryState {
  final List<HistoryDay> days;

  const HistoryState({this.days = const []});
}

/// 历史记录（设计文档 §4.4 / US-012）：按天分组、删除单日、保留最近 30 天。
/// 会话明细超 200 条溢出时由 [HistoryController.archive] 归档。
final historyProvider = NotifierProvider<HistoryController, HistoryState>(
  HistoryController.new,
);

class HistoryController extends Notifier<HistoryState> {
  /// 历史保留时长：30 天，超出自动清理
  static const Duration retention = Duration(days: 30);

  Box get _box => ref.read(historyBoxProvider);

  @override
  HistoryState build() {
    final keys =
        _box.keys.cast<String>().toList()
          ..sort((a, b) => b.compareTo(a)); // 最新日期在前
    final days = <HistoryDay>[];
    for (final key in keys) {
      if (key.length != 10) continue; // 只处理 YYYY-MM-DD 键
      final day = DateTime.tryParse(key);
      if (day == null) continue;
      if (_isExpired(day)) {
        _box.delete(key); // 30 天自动清理
        continue;
      }
      final list = _box.get(key) as List? ?? const [];
      days.add(
        HistoryDay(
          dayKey: key,
          items:
              list
                  .map(
                    (e) =>
                        CartItem.fromJson(Map<String, dynamic>.from(e as Map)),
                  )
                  .toList(),
        ),
      );
    }
    return HistoryState(days: days);
  }

  /// 归档条目到对应日期（会话超 200 条溢出时由 session 调用）
  void archive(List<CartItem> items) {
    if (items.isEmpty) return;
    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(_dayKey(item.addedAt), () => []).add(item);
    }
    for (final entry in grouped.entries) {
      final list = List<Map>.from((_box.get(entry.key) as List?) ?? const []);
      list.addAll(entry.value.map((i) => i.toJson()));
      _box.put(entry.key, list);
    }
    _cleanExpired();
    ref.invalidateSelf(); // 重建分组视图
  }

  /// 删除单日
  void deleteDay(String dayKey) {
    _box.delete(dayKey);
    ref.invalidateSelf();
  }

  /// 清理 30 天前的历史记录
  void _cleanExpired() {
    for (final key in _box.keys.cast<String>().toList()) {
      if (key.length == 10) {
        final day = DateTime.tryParse(key);
        if (day != null && _isExpired(day)) _box.delete(key);
      }
    }
  }

  bool _isExpired(DateTime day) =>
      day.isBefore(DateTime.now().subtract(retention));

  static String _dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
