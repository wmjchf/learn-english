import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:app_starter/core/network/api_client.dart';

enum LessonTtsPhase { idle, loading, playing, paused }

/// 朗读：短文/对话走百炼 Qwen-TTS；点词/闪卡走系统 TTS。
class LessonTts extends ChangeNotifier {
  LessonTts() {
    _wordReady = _initWordTts();
    _player.playerStateStream.listen(_onPlayerState);
    _player.positionStream.listen((_) => _onTick());
    _player.durationStream.listen((_) => _onTick());
    _player.currentIndexStream.listen((_) => _onTick());
  }

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _wordTts = FlutterTts();
  final ApiClient _api = ApiClient();
  late final Future<void> _wordReady;
  bool _wordFailed = false;

  LessonTtsPhase phase = LessonTtsPhase.idle;
  double progress = 0;
  String? error;

  String _fullText = '';
  List<String> _urls = [];
  List<Duration> _durations = [];
  bool _disposed = false;
  int _speakGen = 0;

  bool get isPlaying => phase == LessonTtsPhase.playing;
  bool get isPaused => phase == LessonTtsPhase.paused;
  bool get isLoading => phase == LessonTtsPhase.loading;
  bool get isActive =>
      phase == LessonTtsPhase.playing ||
      phase == LessonTtsPhase.paused ||
      phase == LessonTtsPhase.loading;

  String get currentText => _fullText;

  bool isSessionFor(String text) {
    final t = text.trim();
    return t.isNotEmpty && _fullText == t && isActive;
  }

  Future<void> _initWordTts() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        await _wordTts.setSharedInstance(true);
        await _wordTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      final langOk = await _wordTts.isLanguageAvailable('en-US');
      if (langOk == true) {
        await _wordTts.setLanguage('en-US');
      } else {
        await _wordTts.setLanguage('en-GB');
      }
      await _wordTts.setSpeechRate(Platform.isIOS ? 0.48 : 0.45);
      await _wordTts.setVolume(1.0);
      await _wordTts.setPitch(1.0);
    } catch (e) {
      _wordFailed = true;
      debugPrint('[LessonTts] word tts init failed: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onPlayerState(PlayerState state) {
    if (_disposed) return;
    if (phase == LessonTtsPhase.loading) return;
    switch (state.processingState) {
      case ProcessingState.completed:
        phase = LessonTtsPhase.idle;
        progress = 1;
        _notify();
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (_disposed || phase != LessonTtsPhase.idle) return;
          progress = 0;
          _notify();
        });
        break;
      case ProcessingState.ready:
      case ProcessingState.buffering:
      case ProcessingState.loading:
        if (state.playing) {
          phase = LessonTtsPhase.playing;
        } else if (phase == LessonTtsPhase.playing) {
          phase = LessonTtsPhase.paused;
        }
        _notify();
        break;
      case ProcessingState.idle:
        break;
    }
  }

  Duration get _totalDuration {
    if (_durations.isEmpty) return Duration.zero;
    return _durations.fold(Duration.zero, (a, b) => a + b);
  }

  Duration get _elapsed {
    if (_durations.isEmpty) return _player.position;
    final idx = _player.currentIndex ?? 0;
    var sum = Duration.zero;
    for (var i = 0; i < idx && i < _durations.length; i++) {
      sum += _durations[i];
    }
    return sum + _player.position;
  }

  void _onTick() {
    if (_disposed) return;
    _captureCurrentDuration();
    final total = _totalDuration;
    if (total.inMilliseconds <= 0) return;
    progress =
        (_elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    _notify();
  }

  Future<List<String>> _fetchUrls(String text) async {
    final json = await _api.post(
      '/api/tts',
      body: {
        'text': text,
        'languageType': 'English',
      },
      authed: true,
    );
    final raw = json['urls'];
    if (raw is! List || raw.isEmpty) {
      throw ApiException('语音合成失败');
    }
    return raw.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
  }

  void _estimateDurations(String text) {
    final sec = (text.length / 14).clamp(1.5, 600.0);
    final totalMs = (sec * 1000).round();
    if (_urls.isEmpty) {
      _durations = [];
      return;
    }
    final each = (totalMs / _urls.length).round();
    _durations = List<Duration>.generate(
      _urls.length,
      (_) => Duration(milliseconds: each),
    );
  }

  void _captureCurrentDuration() {
    final d = _player.duration;
    final idx = _player.currentIndex ?? 0;
    if (d == null || d.inMilliseconds <= 0) return;
    if (idx < 0 || idx >= _durations.length) return;
    _durations[idx] = d;
  }

  /// 短文 / 对话：百炼 Qwen-TTS。
  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final gen = ++_speakGen;
    _fullText = t;
    error = null;
    progress = 0;
    phase = LessonTtsPhase.loading;
    _notify();

    try {
      await _wordTts.stop();
      await _player.stop();
      final urls = await _fetchUrls(t);
      if (_disposed || gen != _speakGen) return;
      _urls = urls;

      _estimateDurations(t);
      if (urls.length == 1) {
        await _player.setUrl(urls.first);
      } else {
        await _player.setAudioSources(
          urls.map((u) => AudioSource.uri(Uri.parse(u))).toList(),
        );
      }
      if (_disposed || gen != _speakGen) return;
      _captureCurrentDuration();
      phase = LessonTtsPhase.playing;
      _notify();
      await _player.play();
    } catch (e) {
      if (_disposed || gen != _speakGen) return;
      debugPrint('[LessonTts] speak failed: $e');
      error = e is ApiException ? e.message : '朗读失败';
      phase = LessonTtsPhase.idle;
      progress = 0;
      _notify();
    }
  }

  /// 点词 / 闪卡：系统 TTS（不走云端）。
  Future<void> speakWord(String text) async {
    final t = text.trim();
    if (t.isEmpty || _wordFailed) return;
    await _wordReady;
    // 避免和短文云端朗读叠音
    if (isActive) {
      await stop();
    }
    try {
      await _wordTts.stop();
      await _wordTts.speak(t);
    } catch (e) {
      debugPrint('[LessonTts] speakWord failed: $e');
    }
  }

  Future<void> pause() async {
    if (phase != LessonTtsPhase.playing) return;
    await _player.pause();
    phase = LessonTtsPhase.paused;
    _notify();
  }

  Future<void> resume() async {
    if (phase != LessonTtsPhase.paused) return;
    phase = LessonTtsPhase.playing;
    _notify();
    await _player.play();
  }

  Future<void> togglePause() async {
    if (phase == LessonTtsPhase.playing) {
      await pause();
    } else if (phase == LessonTtsPhase.paused) {
      await resume();
    }
  }

  Future<void> seek(double fraction) async {
    if (_urls.isEmpty) return;
    final f = fraction.clamp(0.0, 1.0);
    progress = f;
    _notify();

    final total = _totalDuration;
    if (total.inMilliseconds <= 0) {
      final idx = (f * (_urls.length - 1)).round().clamp(0, _urls.length - 1);
      try {
        await _player.seek(Duration.zero, index: idx);
        if (phase == LessonTtsPhase.paused || phase == LessonTtsPhase.idle) {
          phase = LessonTtsPhase.playing;
          await _player.play();
        }
      } catch (e) {
        debugPrint('[LessonTts] seek failed: $e');
      }
      return;
    }

    final targetMs = (f * total.inMilliseconds).round();
    var acc = 0;
    var idx = 0;
    var offset = targetMs;
    for (var i = 0; i < _durations.length; i++) {
      final d = _durations[i].inMilliseconds;
      if (acc + d >= targetMs || i == _durations.length - 1) {
        idx = i;
        offset = (targetMs - acc).clamp(0, d);
        break;
      }
      acc += d;
    }

    try {
      await _player.seek(Duration(milliseconds: offset), index: idx);
      if (phase != LessonTtsPhase.playing) {
        phase = LessonTtsPhase.playing;
        await _player.play();
      }
      _notify();
    } catch (e) {
      debugPrint('[LessonTts] seek failed: $e');
    }
  }

  Future<void> stop() async {
    _speakGen++;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _wordTts.stop();
    } catch (_) {}
    phase = LessonTtsPhase.idle;
    progress = 0;
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _speakGen++;
    _player.dispose();
    _wordTts.stop();
    super.dispose();
  }
}
