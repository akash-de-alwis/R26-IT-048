import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AwarenessPreferenceService extends ChangeNotifier {
  static const _masterKey = 'awareness_master_enabled';
  static const _routeAlertsKey = 'awareness_route_alerts_enabled';
  static const _cameraKey = 'awareness_camera_proximity_enabled';
  static const _beepsKey = 'awareness_beeps_enabled';
  static const _beepVolumeKey = 'awareness_beep_volume';
  static const _voiceKey = 'awareness_voice_enabled';
  static const _langKey = 'awareness_voice_language';
  static const _thresholdKey = 'awareness_route_threshold';
  static const _followingKey = 'awareness_following_rule';
  static const _previewKey = 'awareness_show_camera_preview';
  static const _focalKey = 'awareness_focal_length_px';
  static const _calibWidthKey = 'awareness_calibrated_frame_width_px';

  static const severityOrder = ['CAUTION', 'WARNING', 'CRITICAL'];
  static const followingRules = {
    'NEW_LEARNER': 3.0,
    'STANDARD': 2.0,
    'CAUTIOUS': 4.0,
  };

  bool masterEnabled = true;
  bool routeAlertsEnabled = true; // uses GPS + backend scan, no camera
  bool cameraProximityEnabled = false; // opt-in: needs the rear camera
  bool beepsEnabled = true;
  double beepVolume = 0.8;
  bool voiceEnabled = true;
  String voiceLanguage = 'en'; // 'en' or 'si'
  String routeThreshold = 'CAUTION'; // CAUTION / WARNING / CRITICAL
  String followingRule = 'NEW_LEARNER'; // NEW_LEARNER / STANDARD / CAUTIOUS
  bool showCameraPreview = false;
  double? focalLengthPx;
  int? calibratedFrameWidthPx;

  Future<void> loadFromStorage() async {
    final p = await SharedPreferences.getInstance();
    masterEnabled = p.getBool(_masterKey) ?? true;
    routeAlertsEnabled = p.getBool(_routeAlertsKey) ?? true;
    cameraProximityEnabled = p.getBool(_cameraKey) ?? false;
    beepsEnabled = p.getBool(_beepsKey) ?? true;
    beepVolume = p.getDouble(_beepVolumeKey) ?? 0.8;
    voiceEnabled = p.getBool(_voiceKey) ?? true;
    voiceLanguage = p.getString(_langKey) ?? 'en';
    routeThreshold = p.getString(_thresholdKey) ?? 'CAUTION';
    followingRule = p.getString(_followingKey) ?? 'NEW_LEARNER';
    showCameraPreview = p.getBool(_previewKey) ?? false;
    focalLengthPx = p.getDouble(_focalKey);
    calibratedFrameWidthPx = p.getInt(_calibWidthKey);
    notifyListeners();
  }

  Future<void> setMasterEnabled(bool v) => _setBool(_masterKey, v, () => masterEnabled = v);
  Future<void> setRouteAlertsEnabled(bool v) =>
      _setBool(_routeAlertsKey, v, () => routeAlertsEnabled = v);
  Future<void> setCameraProximityEnabled(bool v) =>
      _setBool(_cameraKey, v, () => cameraProximityEnabled = v);
  Future<void> setBeepsEnabled(bool v) => _setBool(_beepsKey, v, () => beepsEnabled = v);
  Future<void> setVoiceEnabled(bool v) => _setBool(_voiceKey, v, () => voiceEnabled = v);
  Future<void> setShowCameraPreview(bool v) =>
      _setBool(_previewKey, v, () => showCameraPreview = v);

  Future<void> setBeepVolume(double v) async {
    beepVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_beepVolumeKey, beepVolume);
  }

  Future<void> setVoiceLanguage(String lang) =>
      _setString(_langKey, lang, () => voiceLanguage = lang);

  Future<void> setRouteThreshold(String t) {
    assert(severityOrder.contains(t), 'Unknown threshold $t');
    return _setString(_thresholdKey, t, () => routeThreshold = t);
  }

  Future<void> setFollowingRule(String rule) {
    assert(followingRules.containsKey(rule), 'Unknown following rule $rule');
    return _setString(_followingKey, rule, () => followingRule = rule);
  }

  /// Saves the camera focal length found by calibration, and the frame
  /// width it was measured at. Pass nulls to reset to the default.
  Future<void> setFocalLength(double? focalPx, int? frameWidthPx) async {
    focalLengthPx = focalPx;
    calibratedFrameWidthPx = frameWidthPx;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (focalPx == null) {
      await p.remove(_focalKey);
    } else {
      await p.setDouble(_focalKey, focalPx);
    }
    if (frameWidthPx == null) {
      await p.remove(_calibWidthKey);
    } else {
      await p.setInt(_calibWidthKey, frameWidthPx);
    }
  }

  /// Seconds of following gap for the chosen rule (3 s by default).
  double get followingTimeSeconds => followingRules[followingRule] ?? 3.0;

  /// True if a route obstacle of [severity] meets the chosen threshold.
  /// Same ordering as the obstacle alert threshold: CAUTION < WARNING < CRITICAL.
  bool shouldAlertRoute(String severity) {
    final thresholdIdx = severityOrder.indexOf(routeThreshold);
    final sevIdx = severityOrder.indexOf(severity);
    if (sevIdx < 0) return false; // unknown or SAFE
    return sevIdx >= (thresholdIdx < 0 ? 0 : thresholdIdx);
  }

  Future<void> _setBool(String key, bool v, void Function() apply) async {
    apply();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  Future<void> _setString(String key, String v, void Function() apply) async {
    apply();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(key, v);
  }
}
