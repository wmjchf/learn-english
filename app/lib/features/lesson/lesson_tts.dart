import 'package:flutter_tts/flutter_tts.dart';

/// 系统 TTS：短文 / 对话通读，点词单念。
class LessonTts {
  LessonTts() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
  }

  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _tts.stop();
    await _tts.speak(t);
  }

  Future<void> stop() => _tts.stop();

  void dispose() {
    _tts.stop();
  }
}
