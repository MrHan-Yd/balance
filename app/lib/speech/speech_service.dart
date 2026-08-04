import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 语音会话状态机（设计文档 §4.3）：idle → listening → (success | failed | timeout) → idle
enum SpeechSessionStatus { idle, listening, success, failed, timeout }

/// 语音识别服务：封装 speech_to_text，对接系统本地识别引擎（zh-CN）
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  Timer? _timeoutTimer;

  SpeechSessionStatus _status = SpeechSessionStatus.idle;
  SpeechSessionStatus get status => _status;

  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;

  /// 初始化并申请麦克风/识别权限；返回是否可用
  Future<bool> initialize({
    void Function(SpeechSessionStatus status)? onStatusChange,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    _onStatusChange = onStatusChange;
    final ok = await _speech.initialize(
      onStatus: (_) {},
      // 插件只有这一个错误通道：listen 会话期间的错误也走这里转发
      onError: (error) {
        _setStatus(SpeechSessionStatus.failed);
        _timeoutTimer?.cancel();
        final handler = _listenErrorHandler;
        if (handler != null) {
          handler(_friendlyError(error.errorMsg));
        } else {
          onError?.call(error);
        }
      },
    );
    if (ok) _localeId = await _pickLocale();
    return ok;
  }

  /// 从设备可用地区里挑一个中文地区。
  /// 国行 ROM 的识别引擎地区码不统一（zh_CN / zh-CN / cmn-Hans-CN…），
  /// 硬编码 zh_CN 可能因引擎不认该地区而启动失败；
  /// 无中文则退回系统地区，都取不到时交给引擎默认。
  Future<String?> _pickLocale() async {
    final locales = await _speech.locales();
    if (locales.isEmpty) return null;
    for (final l in locales) {
      final id = l.localeId.toLowerCase().replaceAll('_', '-');
      if (id == 'zh-cn' || id == 'zh' || id.startsWith('zh-')) {
        return l.localeId;
      }
    }
    return (await _speech.systemLocale())?.localeId ?? locales.first.localeId;
  }

  /// 点击：单次识别，识别出首个有效结果（或 3 秒超时）后自动停止并累加
  Future<void> startSingle({
    required void Function(String text) onResult,
    void Function()? onTimeout,
    void Function(String message)? onError,
  }) async {
    if (!_speech.isAvailable) {
      onError?.call('语音识别不可用，请检查系统语音服务');
      return;
    }
    await _stopIfListening();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (_status != SpeechSessionStatus.listening) return;
      _setStatus(SpeechSessionStatus.timeout);
      stop();
      onTimeout?.call();
    });
    await _listen(onResult, onError: onError);
  }

  /// 按住：持续识别，按住期间连续识别并逐条累加；8 秒无结果自动停止并提示
  Future<void> startContinuous({
    required void Function(String text) onResult,
    void Function()? onTimeout,
    void Function(String message)? onError,
  }) async {
    if (!_speech.isAvailable) {
      onError?.call('语音识别不可用，请检查系统语音服务');
      return;
    }
    await _stopIfListening();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (_status != SpeechSessionStatus.listening) return;
      _setStatus(SpeechSessionStatus.timeout);
      stop();
      onTimeout?.call();
    });
    await _listen(onResult, partial: true, onError: onError);
  }

  Future<void> _listen(
    void Function(String text) onResult, {
    bool partial = false,
    void Function(String message)? onError,
  }) async {
    _listenErrorHandler = onError;
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: partial,
          listenMode: ListenMode.dictation,
          localeId: _localeId,
        ),
        onResult: (SpeechRecognitionResult result) {
          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;
          // 只累加最终结果：长按连续识别时 partial 中间结果会随说话不断变化，
          // 若直接累加，同一句话会被重复计入总价（如"黄瓜五块五"会被加 3~4 次）
          if (!result.finalResult) return;
          _listenErrorHandler = null; // 已成功出结果，会话目标达成
          _setStatus(SpeechSessionStatus.success);
          onResult(text);
        },
      );
      _setStatus(SpeechSessionStatus.listening);
    } catch (_) {
      // 个别机型 listen 直接抛异常（如未初始化/无语音识别服务）
      _timeoutTimer?.cancel();
      _setStatus(SpeechSessionStatus.failed);
      onError?.call('语音识别启动失败');
    }
  }

  /// 把引擎返回的英文错误码转成可读的中文提示
  String _friendlyError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('permission')) return '麦克风权限被拒绝';
    if (m.contains('audio') || m.contains('microphone')) return '没有检测到麦克风输入';
    if (m.contains('not_found') ||
        m.contains('no_match') ||
        m.contains('unavailable') ||
        m.contains('cannot')) {
      return '设备缺少语音识别服务';
    }
    if (m.contains('busy')) return '语音识别忙，请稍后再试';
    if (m.contains('network') || m.contains('server')) return '语音服务网络异常';
    return '语音识别出错：$msg';
  }

  /// 停止识别（松手 / 超时 / 进入后台）
  Future<void> stop() async {
    _timeoutTimer?.cancel();
    _listenErrorHandler = null;
    if (_speech.isListening) {
      await _speech.stop();
    }
    _setStatus(SpeechSessionStatus.idle);
  }

  /// 释放资源：取消定时器并断开状态回调（组件销毁时调用，避免 unmount 后 setState）
  void dispose() {
    _timeoutTimer?.cancel();
    _listenErrorHandler = null;
    _onStatusChange = null;
  }

  void _setStatus(SpeechSessionStatus s) {
    _status = s;
    _onStatusChange?.call(s);
  }

  Future<void> _stopIfListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  void Function(SpeechSessionStatus status)? _onStatusChange;

  /// 当前 listen 会话的错误回调（插件错误通道的转发目标，见 [initialize]）
  void Function(String message)? _listenErrorHandler;

  /// 识别地区：initialize 后按设备能力挑选（见 [_pickLocale]），null 走引擎默认
  String? _localeId;
}
