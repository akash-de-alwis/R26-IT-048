import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../member4_scoring/models/driving_event.dart';
import '../../member4_scoring/services/sensor_service.dart';
import 'notification_service.dart';

class AlertService extends ChangeNotifier {
  final SensorService _sensorService;

  AlertService({required SensorService sensorService})
      : _sensorService = sensorService;

  static const String _baseUrl = AppConstants.backendUrl;

  List<Map<String, dynamic>> activeAlerts = [];
  final Set<int> _alertedHotspotIds = {};
  Timer? _proximityTimer;
  bool isEnabled = true;
  bool isVoiceEnabled = true;
  bool isInAppAlertsEnabled = false;
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
    if (!isEnabled) {
      if (_ttsInitialized) _tts.stop();
      activeAlerts = [];
    }
    notifyListeners();
  }

  void toggleVoice() {
    isVoiceEnabled = !isVoiceEnabled;
    if (!isVoiceEnabled && _ttsInitialized) _tts.stop();
    notifyListeners();
  }

  void toggleInAppAlerts() {
    isInAppAlertsEnabled = !isInAppAlertsEnabled;
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
  Future<void> _onSensorChanged() async {
    if (!isEnabled) return;
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
    if (text.isEmpty) return;

    await NotificationService.instance.showAlert(
      id: _behaviorNotificationId(latest.type),
      title: _behaviorTitle(latest.type),
      body: text,
      severity: 'WARNING',
    );

    if (isVoiceEnabled && _ttsInitialized) _tts.speak(text);
  }

  String _behaviorTitle(DrivingEventType type) => switch (type) {
        DrivingEventType.harshBraking => 'Harsh Braking Detected',
        DrivingEventType.harshAcceleration => 'Sudden Acceleration',
        DrivingEventType.sharpTurn => 'Sharp Turn Detected',
        DrivingEventType.overSpeeding => 'Overspeeding Detected',
        _ => 'Driving Alert',
      };

  // Fixed IDs per event type so same-type notifications replace each other
  int _behaviorNotificationId(DrivingEventType type) => switch (type) {
        DrivingEventType.harshBraking => 20001,
        DrivingEventType.harshAcceleration => 20002,
        DrivingEventType.sharpTurn => 20003,
        DrivingEventType.overSpeeding => 20004,
        _ => 20000,
      };

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
    if (!isEnabled) return;
    try {
      geo.Position? position;
      try {
        position = await geo.Geolocator.getLastKnownPosition();
      } catch (_) {}
      position ??= await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 6));

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
        final hotspotId = alert['hotspot_id'] as int;
        _alertedHotspotIds.add(hotspotId);
        activeAlerts.add(alert);

        final severity = alert['severity'] as String? ?? 'CAUTION';
        final message = currentLanguage == 'si'
            ? (alert['message_si'] as String? ?? '')
            : (alert['message_en'] as String? ?? '');
        final roadName = alert['road_name'] as String? ?? 'Nearby';

        await NotificationService.instance.showAlert(
          id: hotspotId,
          title: '$severity — $roadName',
          body: message.isNotEmpty ? message : 'Accident hotspot nearby.',
          severity: severity,
        );
      }
      notifyListeners();

      final first = alerts.first;
      if (isEnabled && isVoiceEnabled && (first['should_speak'] as bool? ?? false)) {
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
