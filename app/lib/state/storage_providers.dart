import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// hive box 注入（在 main 中 override）

/// 会话数据持久化 box（key: items / undo）
final sessionBoxProvider = Provider<Box>((ref) => throw UnimplementedError());

/// 历史归档 box（key: YYYY-MM-DD → `List<CartItem>`，30 天自动清理）
final historyBoxProvider = Provider<Box>((ref) => throw UnimplementedError());
