import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/drowsiness_metrics_model.dart';
import 'drowsiness_preference_service.dart';

class DrowsinessAlertService extends ChangeNotifier {
  late FlutterTts _tts;
  DrowsinessMetrics? activeAlert;
  DateTime? _lastAlertedAt;
  static const _minIntervalSeconds = 20;

  final DrowsinessPreferenceService preferences;

  static const Map<DrowsinessLevel, Map<String, String>> _voiceMap = {
    DrowsinessLevel.critical: {
      'en': 'Severe drowsiness detected. Please pull over safely and rest immediately.',
      'si': 'බරපතල නිදිමත හඳුනා ගත්තා. කරුණාකර ආරක්ෂිතව පැත්තකට ගොස් වහාම විවේක ගන්න.',
    },
    DrowsinessLevel.warning: {
      'en': 'You appear drowsy. Consider stopping for a short break.',
      'si': 'ඔබට නිදිමත වගෙයි. කෙටි විවේකයක් ගැනීම සලකා බලන්න.',
    },
  };

  DrowsinessAlertService({required this.preferences});

  Future<void> init() async {
    _tts = FlutterTts();
    await _tts.setSpeechRate(0.50);
    await _tts.setVolume(1.0);
  }

  Future<void> triggerAlert(DrowsinessMetrics metrics) async {
    if (_lastAlertedAt != null) {
      final delta = DateTime.now().difference(_lastAlertedAt!).inSeconds;
      if (delta < _minIntervalSeconds) return;
    }

    activeAlert = metrics;
    _lastAlertedAt = DateTime.now();
    notifyListeners();

    if (preferences.alertStyle == 'voice_visual') {
      final text = _voiceMap[metrics.level];
      if (text != null) {
        final voiceText = text['en']!;
        try {
          await _tts.setLanguage('en-US');
        } catch (_) {}
        await _tts.stop();
        await _tts.speak(voiceText);
      }
    }

    // Auto-clear visual overlay after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (activeAlert?.timestamp == metrics.timestamp) {
        activeAlert = null;
        notifyListeners();
      }
    });
  }

  void clearAlert() {
    activeAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
