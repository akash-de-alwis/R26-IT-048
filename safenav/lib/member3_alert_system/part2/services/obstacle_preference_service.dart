import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObstaclePreferenceService extends ChangeNotifier {
  static const _enabledKey = 'obstacle_detection_enabled';
  static const _voiceKey = 'obstacle_voice_enabled';
  static const _langKey = 'obstacle_voice_language';
  static const _thresholdKey = 'obstacle_alert_threshold';

  // Master toggle — when false, nothing about obstacle detection runs
  bool detectionEnabled = false;

  // Sub-settings (only meaningful when detectionEnabled == true)
  bool voiceEnabled = true;
  String voiceLanguage = 'en'; // 'en' or 'si'
  String alertThreshold = 'CAUTION'; // CAUTION, WARNING, or CRITICAL

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    detectionEnabled = prefs.getBool(_enabledKey) ?? true;
    voiceEnabled = prefs.getBool(_voiceKey) ?? true;
    voiceLanguage = prefs.getString(_langKey) ?? 'en';
    alertThreshold = prefs.getString(_thresholdKey) ?? 'CAUTION';
    notifyListeners();
  }

  Future<void> setDetectionEnabled(bool v) async {
    detectionEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, v);
  }

  Future<void> setVoiceEnabled(bool v) async {
    voiceEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceKey, v);
  }

  Future<void> setLanguage(String lang) async {
    voiceLanguage = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  Future<void> setThreshold(String t) async {
    alertThreshold = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_thresholdKey, t);
  }

  bool shouldAlertFor(String severity) {
    const order = ['CAUTION', 'WARNING', 'CRITICAL'];
    final thresholdIdx = order.indexOf(alertThreshold);
    final sevIdx = order.indexOf(severity);
    return sevIdx >= thresholdIdx;
  }
}
