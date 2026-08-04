import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'storage_providers.dart';

/// 设置状态（设计文档 §2.6：声音反馈默认关闭，菜市场环境；设置项可开启）
class SettingsState {
  /// 累加成功时是否播放提示音
  final bool soundEnabled;

  const SettingsState({this.soundEnabled = false});

  SettingsState copyWith({bool? soundEnabled}) =>
      SettingsState(soundEnabled: soundEnabled ?? this.soundEnabled);
}

/// 全局设置（声音反馈等），持久化到会话 box，重启保持
final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(
      SettingsController.new,
    );

class SettingsController extends Notifier<SettingsState> {
  static const String _soundKey = 'settings.soundFeedback';

  Box get _box => ref.read(sessionBoxProvider);

  @override
  SettingsState build() {
    return SettingsState(soundEnabled: _box.get(_soundKey) == true);
  }

  /// 声音反馈开关（默认关闭，菜市场环境）
  void setSoundEnabled(bool enabled) {
    state = SettingsState(soundEnabled: enabled);
    _box.put(_soundKey, enabled);
  }
}
