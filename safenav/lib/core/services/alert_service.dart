import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'sensor_service.dart';

class AlertService extends ChangeNotifier {
  final SensorService _sensorService;

  AlertService({required SensorService sensorService})
      : _sensorService = sensorService;

  static const String _baseUrl = 'http://10.0.2.2:8000';

  List<Map<String, dynamic>> activeAlerts = [];
  final Set<int> _alertedHotspotIds = {};
  Timer? _proximityTimer;
  bool isEnabled = true;
  String currentLanguage = 'en';
  late FlutterTts _tts;
  bool _ttsInitialized = false;

  // ── Public API ────────────────────────────────────────────────────────────

  void startAlertMonitoring() {
    _initTts();
    _proximityTimer?.cancel();
    _proximityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProximity(),
    );
  }

  void stopAlertMonitoring() {
    _proximityTimer?.cancel();
    _proximityTimer = null;
    if (_ttsInitialized) _tts.stop();
    activeAlerts = [];
    _alertedHotspotIds.clear();
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

  Future<void> _checkProximity() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
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

      final body = jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'hour': now.hour,
        'is_weekend': isWeekend,
        'driver_score': driverScore,
        'driver_events': recentEvents,
        'alerted_hotspot_ids': _alertedHotspotIds.toList(),
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/alerts/nearby'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final alerts =
          (data['alerts'] as List<dynamic>).cast<Map<String, dynamic>>();

      if (alerts.isEmpty) return;

      for (final alert in alerts) {
        final id = alert['hotspot_id'] as int;
        _alertedHotspotIds.add(id);
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
    if (_ttsInitialized) _tts.stop();
    super.dispose();
  }
}
