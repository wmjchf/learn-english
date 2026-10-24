import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 系统 TTS：短文 / 对话通读，点词单念。
/// 真机需配置 iOS 播放会话，否则静音开关 / 默认会话下可能无声。
class LessonTts {
  LessonTts() {
    _ready = _init();
  }

  final FlutterTts _tts = FlutterTts();
  late final Future<void> _ready;
  bool _failed = false;

  Future<void> _init() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
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

      // 优先美式英语；不可用再退回系统默认
      final langOk = await _tts.isLanguageAvailable('en-US');
      if (langOk == true) {
        await _tts.setLanguage('en-US');
      } else {
        await _tts.setLanguage('en-GB');
      }

      await _tts.setSpeechRate(Platform.isIOS ? 0.48 : 0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      if (!kIsWeb && Platform.isAndroid) {
        await _tts.setQueueMode(1);
      }
    } catch (e) {
      _failed = true;
      debugPrint('[LessonTts] init failed: $e');
    }
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty || _failed) return;
    await _ready;
    try {
      await _tts.stop();
      final result = await _tts.speak(t);
      if (result != 1) {
        debugPrint('[LessonTts] speak result=$result text=$t');
      }
    } catch (e) {
      debugPrint('[LessonTts] speak failed: $e');
    }
  }

  Future<void> stop() async {
    await _ready;
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
