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
    return _speech.initialize(
      onStatus: (_) {},
      onError: (error) {
        _setStatus(SpeechSessionStatus.failed);
        onError?.call(error);
      },
    );
  }

  /// 点击：单次识别，识别出首个有效结果（或 3 秒超时）后自动停止并累加
  Future<void> startSingle({
    required void Function(String text) onResult,
    void Function()? onTimeout,
  }) async {
    if (!_speech.isAvailable) return;
    await _stopIfListening();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (_status != SpeechSessionStatus.listening) return;
      _setStatus(SpeechSessionStatus.timeout);
      stop();
      onTimeout?.call();
    });
    _listen(onResult);
  }

  /// 按住：持续识别，按住期间连续识别并逐条累加；8 秒无结果自动停止
  Future<void> startContinuous({
    required void Function(String text) onResult,
  }) async {
    if (!_speech.isAvailable) return;
    await _stopIfListening();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (_status != SpeechSessionStatus.listening) return;
      _setStatus(SpeechSessionStatus.timeout);
      stop();
    });
    _listen(onResult, partial: true);
  }

  Future<void> _listen(void Function(String text) onResult,
      {bool partial = false}) async {
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: partial,
        listenMode: ListenMode.dictation,
        localeId: 'zh_CN',
      ),
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        if (result.finalResult || partial) {
          _setStatus(SpeechSessionStatus.success);
          onResult(text);
        }
      },
    );
    _setStatus(SpeechSessionStatus.listening);
  }

  /// 停止识别（松手 / 超时 / 进入后台）
  Future<void> stop() async {
    _timeoutTimer?.cancel();
    if (_speech.isListening) {
      await _speech.stop();
    }
    _setStatus(SpeechSessionStatus.idle);
  }

  void _setStatus(SpeechSessionStatus s) {
    _status = s;
    _onStatusChange?.call(s);
  }

  Future<void> _stopIfListening() async {
    if (_speech.isListening) await _speech.stop();
  }

  void Function(SpeechSessionStatus status)? _onStatusChange;
}
