import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'state/storage_providers.dart';
import 'theme/app_theme.dart';
import 'ui/home_page.dart';

/// 秤心 Balance — 买菜语音自动加和助手
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 会话 / 历史 持久化 box
  final sessionBox = await Hive.openBox('session_box');
  final historyBox = await Hive.openBox('history_box');

  runApp(
    ProviderScope(
      overrides: [
        sessionBoxProvider.overrideWithValue(sessionBox),
        historyBoxProvider.overrideWithValue(historyBox),
      ],
      child: const BalanceApp(),
    ),
  );
}

class BalanceApp extends StatelessWidget {
  const BalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '秤心 Balance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
