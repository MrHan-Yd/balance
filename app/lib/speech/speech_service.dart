import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// 语音会话状态机（设计文档 §4.3）：idle → listening → (success | failed | timeout) → idle
enum SpeechSessionStatus { idle, listening, success, failed, timeout }

/// 语音识别服务：设备端离线 Whisper（whisper_ggml + record）。
///
/// 国行安卓没有 Google 语音服务，小米/华为等厂商引擎又不开放给第三方应用，
/// 系统 STT（speech_to_text）在这些机型上不可用 → 改用 whisper.cpp 本地推理：
/// 完全离线、无需账号、无需联网，模型随包内置（assets/models）。
class SpeechService {
  /// 内置量化模型（ggml-base-q8_0，约 78MB：8bit 量化几乎无损、速度与 fp16 相当）
  static const String _assetModel = 'assets/models/ggml-base-q8_0.bin';

  final WhisperController _whisper = WhisperController();
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<String>? _partialsSub;
  WhisperLiveSession? _live;
  String? _modelPath;

  Timer? _silenceTimer; // 静音检测：无声达到阈值自动结束（单句识别）
  Timer? _maxTimer; // 单次会话最长时长兜底
  DateTime _lastVoice = DateTime.now();

  bool _inSession = false;

  SpeechSessionStatus _status = SpeechSessionStatus.idle;
  SpeechSessionStatus get status => _status;

  bool _available = false;
  bool get isAvailable => _available;
  bool get isListening => _status == SpeechSessionStatus.listening;

  // 当前会话的结算回调
  void Function(String text)? _pendingResult;
  void Function()? _pendingTimeout;

  /// 初始化：只做预检。模型拷贝与麦克风权限都推迟到首次说话时处理——
  /// 国行机型差异大，启动即失败会误伤；失败在点击说话时提示并引导键盘
  Future<bool> initialize({
    void Function(SpeechSessionStatus status)? onStatusChange,
  }) async {
    _onStatusChange = onStatusChange;
    _available = true;
    return true;
  }

  /// 点击：单句识别。开始录音 + 本地推理，1.8s 无声自动结束出结果（或超时）
  Future<void> startSingle({
    required void Function(String text) onResult,
    void Function()? onTimeout,
    void Function(String message)? onError,
  }) async {
    if (_inSession) await _settle(); // 连点：先结算上一句
    _pendingResult = onResult;
    _pendingTimeout = onTimeout;
    if (!await _startSession(onError: onError)) return;
    // 单句：静音 1.8s 自动结算
    _armSilenceStop(const Duration(milliseconds: 1800));
    _maxTimer = Timer(const Duration(seconds: 15), _settle);
  }

  /// 按住：持续识别。不自动结束，松手时由 UI 调用 [finish] 结算整段
  Future<void> startContinuous({
    required void Function(String text) onResult,
    void Function()? onTimeout,
    void Function(String message)? onError,
  }) async {
    if (_inSession) await _settle();
    _pendingResult = onResult;
    _pendingTimeout = onTimeout;
    if (!await _startSession(onError: onError)) return;
    _maxTimer = Timer(const Duration(seconds: 60), _settle);
  }

  /// 松手结算（连续模式）：停止录音，取最终文本并累加
  Future<void> finish() => _settle();

  /// 释放驻留的模型内存（应用退到后台时调用，约省 80MB）。
  /// 回到前台后的下一次说话会重新加载模型（约 1 秒）。
  Future<void> releaseModel() {
    if (_inSession) return Future.value(); // 会话中不释放
    return _whisper.releaseModel();
  }

  /// 停止并丢弃结果（进入后台/清理时调用，不累加）
  Future<void> stop() async {
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    _ampSub?.cancel();
    if (_inSession) {
      _inSession = false;
      await _recorder.stop();
      _live?.stop();
      _live = null;
      _pendingResult = null;
      _pendingTimeout = null;
    }
    _setStatus(SpeechSessionStatus.idle);
  }

  /// 释放资源（组件销毁时调用）
  void dispose() {
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    _ampSub?.cancel();
    _partialsSub?.cancel();
    _recorder.dispose();
    _onStatusChange = null;
  }

  /// 开始录音 + 推理会话
  Future<bool> _startSession({
    void Function(String message)? onError,
  }) async {
    if (_inSession) return false;
    try {
      _modelPath ??= await _ensureModel();
      if (!await _recorder.hasPermission()) {
        onError?.call('麦克风权限被拒绝，请在系统设置中允许录音');
        return false;
      }
      final pcm = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _live = await _whisper.transcribeLive(
        modelPath: _modelPath,
        pcm16Stream: pcm,
        lang: 'zh',
        // 模型驻留内存：首次说话加载后，后续会话不再等模型加载
        keepModelLoaded: true,
      );
      // partials 是单订阅流：必须立即挂监听，否则事件在缓冲区堆积
      _partialsSub = _live!.partials.listen((_) {});
      _inSession = true;
      _lastVoice = DateTime.now();
      // 音量监听：有声刷新静音起点（单句识别的结束判定）
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen((a) {
            if (a.current > 0.02) _lastVoice = DateTime.now();
          });
      _setStatus(SpeechSessionStatus.listening);
      return true;
    } catch (e) {
      _inSession = false;
      await _recorder.stop();
      onError?.call('无法启动语音识别：$e');
      return false;
    }
  }

  /// 静音自动结束：周期检查距上次有声的时间
  void _armSilenceStop(Duration silence) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_inSession) return;
      if (DateTime.now().difference(_lastVoice) >= silence) _settle();
    });
  }

  /// 结算当前会话：停止录音 → 取最终文本 → 有内容累加，空则超时提示
  Future<void> _settle() async {
    if (!_inSession) return;
    _inSession = false;
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    _ampSub?.cancel();
    await _recorder.stop();
    final text = (await _live?.stop() ?? '').trim();
    _live = null;
    final onResult = _pendingResult;
    final onTimeout = _pendingTimeout;
    _pendingResult = null;
    _pendingTimeout = null;
    _setStatus(SpeechSessionStatus.success);
    if (text.isEmpty) {
      onTimeout?.call();
    } else {
      onResult?.call(text);
    }
  }

  /// 把内置模型从 assets 拷贝到应用目录（whisper 需要真实文件路径）
  Future<String> _ensureModel() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/ggml-base-q8_0.bin');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;
    final data = await rootBundle.load(_assetModel);
    await file.writeAsBytes(data.buffer.asUint8List());
    return file.path;
  }

  void _setStatus(SpeechSessionStatus s) {
    _status = s;
    _onStatusChange?.call(s);
  }

  void Function(SpeechSessionStatus status)? _onStatusChange;
}
