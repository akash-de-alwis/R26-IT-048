import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/proximity_tier.dart';

/// Spoken road-awareness alerts, with its own TTS instance.
class AwarenessVoiceService {
  static const minGap = Duration(seconds: 8);

  // NOTE: the Sinhala names and phrases below should be checked by a
  // Sinhala speaker before release.
  static const _namesEn = {
    'person': 'Pedestrian',
    'cyclist': 'Cyclist',
    'motorcycle': 'Motorcycle',
    'vehicle': 'Vehicle',
    'bus': 'Bus',
    'truck': 'Truck',
    'animal': 'Animal',
    'obstacle': 'Obstacle',
  };
  static const _namesSi = {
    'person': 'පදිකයෙක්',
    'cyclist': 'පාපැදිකරුවෙක්',
    'motorcycle': 'මෝටර් සයිකලයක්',
    'vehicle': 'වාහනයක්',
    'bus': 'බස් රථයක්',
    'truck': 'ට්‍රක් රථයක්',
    'animal': 'සතෙක්',
    'obstacle': 'බාධකයක්',
  };

  FlutterTts? _tts;
  DateTime? _lastSpoken;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  /// English display name for a profile group (also used by the banner).
  static String displayName(String group) => _namesEn[group] ?? 'Obstacle';

  /// Proximity phrase for [group] at [tier], or null below veryClose.
  static String? proximityPhrase(
      String group, ProximityTier tier, String lang) {
    final si = lang == 'si';
    final name = si
        ? (_namesSi[group] ?? _namesSi['obstacle']!)
        : (_namesEn[group] ?? _namesEn['obstacle']!);
    return switch (tier) {
      ProximityTier.veryClose => si
          ? 'ඉදිරියෙන් $name ඉතා ළඟයි. වේගය අඩු කරන්න.'
          : '$name very close ahead. Slow down.',
      ProximityTier.critical => si
          ? '$name ඉතා ළඟයි! වහාම තිරිංග යොදන්න.'
          : '$name too close! Brake now.',
      _ => null,
    };
  }

  Future<FlutterTts> _ensureTts() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    tts.setStartHandler(() => _isSpeaking = true);
    tts.setCompletionHandler(() => _isSpeaking = false);
    tts.setCancelHandler(() => _isSpeaking = false);
    tts.setErrorHandler((_) => _isSpeaking = false);
    _tts = tts;
    return tts;
  }

  /// True if the 8 s gap since the last phrase has passed.
  bool get canSpeak =>
      _lastSpoken == null || DateTime.now().difference(_lastSpoken!) >= minGap;

  /// Speaks [text] in [lang] ('en' or 'si'). Phrases closer than [minGap]
  /// are dropped unless [critical] is set. Returns whether it spoke.
  Future<bool> speak(String text, String lang, {bool critical = false}) async {
    if (!critical && !canSpeak) return false;
    try {
      final tts = await _ensureTts();
      await _setLanguage(tts, lang);
      await tts.stop();
      _lastSpoken = DateTime.now();
      await tts.speak(text);
      return true;
    } catch (e) {
      debugPrint('[AwarenessVoice] $e');
      return false;
    }
  }

  Future<void> _setLanguage(FlutterTts tts, String lang) async {
    if (lang == 'si') {
      try {
        final ok = await tts.isLanguageAvailable('si-LK');
        if (ok == true) {
          await tts.setLanguage('si-LK');
          return;
        }
      } catch (_) {}
      // Sinhala voice not installed: fall back to English
    }
    await tts.setLanguage('en-US');
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  void dispose() {
    _tts?.stop();
  }
}
