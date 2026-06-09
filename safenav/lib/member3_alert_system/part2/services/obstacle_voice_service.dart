import 'package:flutter_tts/flutter_tts.dart';

class ObstacleVoiceService {
  late FlutterTts _tts;
  bool _initialized = false;
  DateTime? _lastSpoken;
  static const _minIntervalSeconds = 8;

  Future<void> init() async {
    _tts = FlutterTts();
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  bool get canSpeak {
    if (_lastSpoken == null) return true;
    return DateTime.now().difference(_lastSpoken!).inSeconds >=
        _minIntervalSeconds;
  }

  Future<void> speak(String text, String language) async {
    if (!_initialized) await init();
    if (!canSpeak) return;

    final ttsLang = language == 'si' ? 'si-LK' : 'en-US';
    try {
      await _tts.setLanguage(ttsLang);
    } catch (_) {
      // Sinhala TTS may not be available — fall back to English
      await _tts.setLanguage('en-US');
    }
    await _tts.stop();
    await _tts.speak(text);
    _lastSpoken = DateTime.now();
  }

  Future<void> stop() async {
    if (_initialized) await _tts.stop();
  }

  void dispose() {
    if (_initialized) _tts.stop();
  }
}
