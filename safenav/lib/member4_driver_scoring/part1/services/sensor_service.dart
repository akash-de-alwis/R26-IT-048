import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driving_event.dart';
import '../models/trip_session.dart';

// Service that listens to device sensors (accelerometer, gyroscope, GPS),
// detects driving events (brakes, acceleration, turns, overspeeding, etc.),
// maintains the active TripSession and saves recent trips to persistent
// storage for history.

class SensorService extends ChangeNotifier {
  SensorService._();
  static final SensorService instance = SensorService._();

  static const String _historyKey = 'trip_history';
  static const int _maxHistorySize = 20;

  // ── Thresholds ───────────────────────────────────────────────────────────
  // Configurable numeric thresholds used to detect different driving events.
  static const double _harshBrakeThreshold = 0.65;
  static const double _harshAccelThreshold = 0.55;
  static const double _sharpTurnThreshold = 0.60;
  static const double _overspeedThresholdKmh = 70.0;
  static const int _cooldownSeconds = 3;
  static const int _smoothStretchSeconds = 30;

  // ── Score deltas ─────────────────────────────────────────────────────────
  // Points to add or subtract when an event is detected.
  static final Map<DrivingEventType, int> _scoreDeltas = {
    DrivingEventType.harshBraking: -8,
    DrivingEventType.harshAcceleration: -5,
    DrivingEventType.sharpTurn: -4,
    DrivingEventType.overSpeeding: -6,
    DrivingEventType.smoothDriving: 2,
  };

  // ── Public state ─────────────────────────────────────────────────────────
  // Publicly visible state consumed by UI via ChangeNotifier.
  TripSession? currentTrip;
  bool isTracking = false;
  double currentSpeedKmh = 0.0;

  // ── Subscriptions ────────────────────────────────────────────────────────
  // Active stream subscriptions to sensor and location streams.
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<geo.Position>? _locationSubscription;

  // ── Rolling windows (last 5 readings each) ───────────────────────────────
  // Small moving windows used to smooth sensor readings.
  final List<double> _accelXWindow = [];
  final List<double> _accelYWindow = [];
  final List<double> _accelZWindow = [];
  final List<double> _gyroZWindow = [];

  // ── Cooldown / smooth-streak ─────────────────────────────────────────────
  // Track last event times to avoid duplicate detections and detect
  // sustained smooth driving stretches.
  final Map<DrivingEventType, DateTime> _lastEventTime = {};
  DateTime? _smoothStretchStart;

  // ── GPS state ────────────────────────────────────────────────────────────
  // Latest GPS coordinates and previous point for distance calculations.
  double _currentLat = 0.0;
  double _currentLng = 0.0;
  double? _prevLat;
  double? _prevLng;

  // Throttle location-driven UI updates to at most once per second
  DateTime? _lastLocationNotify;

  // ── Public API ────────────────────────────────────────────────────────────

  void startTrip(String? destinationName) {
    if (isTracking) return;

    currentTrip = TripSession(
      tripId: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      destinationName: destinationName,
    );
    isTracking = true;
    currentSpeedKmh = 0.0;
    _lastEventTime.clear();
    _smoothStretchStart = null;
    _prevLat = null;
    _prevLng = null;
    _accelXWindow.clear();
    _accelYWindow.clear();
    _accelZWindow.clear();
    _gyroZWindow.clear();

    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_processAccelerometer);

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_processGyroscope);

    _locationSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_processLocation);

    notifyListeners();
  }

  Future<TripSession?> endTrip() async {
    if (!isTracking || currentTrip == null) return null;

    currentTrip!.endTime = DateTime.now();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _locationSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _locationSubscription = null;
    isTracking = false;

    final completed = currentTrip!;
    await _saveTripToHistory(completed);
    notifyListeners();
    return completed;
  }

  Future<List<TripSession>> getTripHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TripSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveTripToHistory(TripSession trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getTripHistory();
      final updated = [trip, ...existing].take(_maxHistorySize).toList();
      await prefs.setString(
        _historyKey,
        jsonEncode(updated.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      // Log persistence errors but don't crash the app.
      debugPrint('_saveTripToHistory error: $e');
    }
  }

  // ── Sensor processing ─────────────────────────────────────────────────────

  void _processAccelerometer(UserAccelerometerEvent event) {
    // Smooth accelerometer values using short windows and detect
    // harsh braking/acceleration or long smooth driving stretches.
    _pushWindow(_accelXWindow, event.x);
    _pushWindow(_accelYWindow, event.y);
    _pushWindow(_accelZWindow, event.z);

    final gX = _mean(_accelXWindow) / 9.8;
    final gY = _mean(_accelYWindow) / 9.8;
    final gZ = _mean(_accelZWindow) / 9.8;

    if (gY < -_harshBrakeThreshold &&
        _canFireEvent(DrivingEventType.harshBraking)) {
      _addEvent(_makeEvent(DrivingEventType.harshBraking, gY.abs()));
      _smoothStretchStart = null;
    } else if (gY > _harshAccelThreshold &&
        _canFireEvent(DrivingEventType.harshAcceleration)) {
      _addEvent(_makeEvent(DrivingEventType.harshAcceleration, gY));
      _smoothStretchStart = null;
    }

    if (gX.abs() < 0.1 && gY.abs() < 0.1 && gZ.abs() < 0.1) {
      _smoothStretchStart ??= DateTime.now();
      if (DateTime.now().difference(_smoothStretchStart!).inSeconds >=
          _smoothStretchSeconds) {
        _addEvent(_makeEvent(DrivingEventType.smoothDriving, 0.0));
        _smoothStretchStart = DateTime.now();
      }
    } else if (gX.abs() >= 0.1 || gY.abs() >= 0.1) {
      _smoothStretchStart = null;
    }
  }

  void _processGyroscope(GyroscopeEvent event) {
    // Use gyroscope Z-axis to detect sharp turns after smoothing.
    _pushWindow(_gyroZWindow, event.z);
    final smoothZ = _mean(_gyroZWindow);

    if (smoothZ.abs() > _sharpTurnThreshold &&
        _canFireEvent(DrivingEventType.sharpTurn)) {
      _addEvent(_makeEvent(DrivingEventType.sharpTurn, smoothZ.abs()));
      _smoothStretchStart = null;
    }
  }

  void _processLocation(geo.Position position) {
    // Update GPS location, compute incremental distance, track speed,
    // and detect overspeeding events.
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    currentSpeedKmh = position.speed * 3.6;

    if (currentTrip != null) {
      if (_prevLat != null && _prevLng != null) {
        currentTrip!.totalDistanceKm += _haversineKm(
          _prevLat!,
          _prevLng!,
          _currentLat,
          _currentLng,
        );
      }
      currentTrip!.maxSpeedKmh = math.max(
        currentTrip!.maxSpeedKmh,
        currentSpeedKmh,
      );
    }

    _prevLat = _currentLat;
    _prevLng = _currentLng;

    if (currentSpeedKmh > _overspeedThresholdKmh &&
        _canFireEvent(DrivingEventType.overSpeeding)) {
      _addEvent(_makeEvent(DrivingEventType.overSpeeding, currentSpeedKmh));
      return; // _addEvent already called notifyListeners
    }

    // Throttle UI updates to once per second for distance/speed changes
    final now = DateTime.now();
    if (_lastLocationNotify == null ||
        now.difference(_lastLocationNotify!).inMilliseconds >= 1000) {
      _lastLocationNotify = now;
      // Defer to post-frame to avoid notifying during an active build
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _canFireEvent(DrivingEventType type) {
    // Enforce a short cooldown between same-type events.
    final last = _lastEventTime[type];
    if (last == null) return true;
    return DateTime.now().difference(last).inSeconds >= _cooldownSeconds;
  }

  DrivingEvent _makeEvent(DrivingEventType type, double magnitude) {
    // Build a DrivingEvent with current location/time and score delta.
    return DrivingEvent(
      type: type,
      timestamp: DateTime.now(),
      magnitude: magnitude,
      latitude: _currentLat,
      longitude: _currentLng,
      pointsDeducted: _scoreDeltas[type] ?? 0,
    );
  }

  void _addEvent(DrivingEvent event) {
    if (currentTrip == null) return;
    currentTrip!.events.add(event);
    currentTrip!.safetyScore = (currentTrip!.safetyScore + event.pointsDeducted)
        .clamp(0, 100);
    _lastEventTime[event.type] = DateTime.now();
    notifyListeners();
  }

  void _pushWindow(List<double> window, double value) {
    window.add(value);
    if (window.length > 5) window.removeAt(0);
  }

  double _mean(List<double> window) {
    if (window.isEmpty) return 0.0;
    return window.reduce((a, b) => a + b) / window.length;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}
