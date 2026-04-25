import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../member4_scoring/models/driving_event.dart';
import '../../member4_scoring/services/sensor_service.dart';

class AlertService extends ChangeNotifier {
  final SensorService _sensorService;

  AlertService({required SensorService sensorService})
      : _sensorService = sensorService;

  static const String _baseUrl = AppConstants.backendUrl;

  List<Map<String, dynamic>> activeAlerts = [];
  final Set<int> _alertedHotspotIds = {};
  Timer? _proximityTimer;
  bool isEnabled = true;
  String currentLanguage = 'en';
  late FlutterTts _tts;
  bool _ttsInitialized = false;

  // Tracks how many behavior events have already been spoken this trip
  int _spokenEventCount = 0;

  // ── Public API ────────────────────────────────────────────────────────────

  void startAlertMonitoring() {
    _initTts();
    _proximityTimer?.cancel();
    _proximityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProximity(),
    );
    _sensorService.addListener(_onSensorChanged);
  }

  void stopAlertMonitoring() {
    _proximityTimer?.cancel();
    _proximityTimer = null;
    _sensorService.removeListener(_onSensorChanged);
    if (_ttsInitialized) _tts.stop();
    activeAlerts = [];
    _alertedHotspotIds.clear();
    _spokenEventCount = 0;
    notifyListeners();
  }

  /// Clears active alerts and hotspot history without stopping the timer.
  /// Call this at the end of a trip so the next trip gets fresh alerts.
  void clearAlertsForNewTrip() {
    if (_ttsInitialized) _tts.stop();
    activeAlerts = [];
    _alertedHotspotIds.clear();
    _spokenEventCount = 0;
    notifyListeners();
  }

  void dismissAlert(int hotspotId) {
    activeAlerts.removeWhere((a) => a['hotspot_id'] == hotspotId);
    notifyListeners();
  }

  void dismissAllAlerts() {
    activeAlerts = [];
    notifyListeners();
  }

  void toggleLanguage() {
    currentLanguage = currentLanguage == 'en' ? 'si' : 'en';
    if (_ttsInitialized) {
      _tts.setLanguage(currentLanguage == 'si' ? 'si-LK' : 'en-US');
    }
    notifyListeners();
  }

  void toggleAlerts() {
    isEnabled = !isEnabled;
    if (!isEnabled && _ttsInitialized) _tts.stop();
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _initTts() {
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    _ttsInitialized = true;
  }

  // Fires whenever SensorService records a new driving event
  void _onSensorChanged() {
    if (!isEnabled || !_ttsInitialized) return;
    final trip = _sensorService.currentTrip;
    if (trip == null) return;

    // Count only events worth speaking (skip smoothDriving)
    final speakable = trip.events
        .where((e) => e.type != DrivingEventType.smoothDriving)
        .toList();

    if (speakable.length <= _spokenEventCount) return;
    _spokenEventCount = speakable.length;

    final latest = speakable.last;
    final text = _behaviorMessage(latest.type);
    if (text.isNotEmpty) _tts.speak(text);
  }

  String _behaviorMessage(DrivingEventType type) {
    if (currentLanguage == 'si') {
      return switch (type) {
        DrivingEventType.harshBraking =>
          'හදිසි තිර තාල. ක්‍රමයෙන් රිය රඳවන්න.',
        DrivingEventType.harshAcceleration =>
          'හදිසි ත්වරණය. සෙමෙන් ගමන් ගන්න.',
        DrivingEventType.sharpTurn =>
          'තියුණු හැරවීමක්. වේගය අඩු කරන්න.',
        DrivingEventType.overSpeeding =>
          'අධිවේගය. වහාම වේගය අඩු කරන්න.',
        _ => '',
      };
    }
    return switch (type) {
      DrivingEventType.harshBraking =>
        'Harsh braking detected. Try to brake more gradually.',
      DrivingEventType.harshAcceleration =>
        'Sudden acceleration detected. Accelerate smoothly.',
      DrivingEventType.sharpTurn =>
        'Sharp turn detected. Slow down before corners.',
      DrivingEventType.overSpeeding =>
        'Overspeeding detected. Reduce your speed immediately.',
      _ => '',
    };
  }

  Future<void> _checkProximity() async {
    try {
      geo.Position? position;
      try {
        position = await geo.Geolocator.getLastKnownPosition();
      } catch (_) {}
      position ??= await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 6));

      if (position == null) return;

      final now = DateTime.now();
      final isWeekend = now.weekday >= 6 ? 1 : 0;

      final trip = _sensorService.currentTrip;
      final driverScore = trip?.safetyScore ?? 100;
      final recentEvents = trip?.events
              .reversed
              .take(5)
              .map((e) => e.type.name)
              .toList() ??
          [];

      final http.Response response;
      try {
        response = await http
            .post(
              Uri.parse('$_baseUrl/alerts/nearby'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'latitude': position.latitude,
                'longitude': position.longitude,
                'hour': now.hour,
                'is_weekend': isWeekend,
                'driver_score': driverScore,
                'driver_events': recentEvents,
                'alerted_hotspot_ids': _alertedHotspotIds.toList(),
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('AlertService: server unreachable: $e');
        return;
      }

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final alerts =
          (data['alerts'] as List<dynamic>).cast<Map<String, dynamic>>();

      if (alerts.isEmpty) return;

      for (final alert in alerts) {
        _alertedHotspotIds.add(alert['hotspot_id'] as int);
        activeAlerts.add(alert);
      }
      notifyListeners();

      final first = alerts.first;
      if (isEnabled && (first['should_speak'] as bool? ?? false)) {
        final text = currentLanguage == 'si'
            ? (first['message_si'] as String? ?? '')
            : (first['message_en'] as String? ?? '');
        if (text.isNotEmpty) await _tts.speak(text);
      }
    } catch (e) {
      debugPrint('AlertService._checkProximity error: $e');
    }
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    _sensorService.removeListener(_onSensorChanged);
    if (_ttsInitialized) _tts.stop();
    super.dispose();
  }
}
