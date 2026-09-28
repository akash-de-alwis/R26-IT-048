import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../member3_alert_system/part2/models/obstacle_model.dart';
import '../../../member3_alert_system/part2/services/obstacle_scan_service.dart';
import '../../member4_part2/services/drowsiness_detection_service.dart';
import '../models/awareness_alert_model.dart';
import '../models/proximity_tier.dart';
import '../models/sensed_object_model.dart';
import 'awareness_event_logger.dart';
import 'awareness_preference_service.dart';
import 'awareness_voice_service.dart';
import 'beep_engine.dart';
import 'distance_calibration_service.dart';
import 'object_detector_service.dart';
import 'proximity_classifier.dart';

/// One alert channel for route hazards (Member 3 scan) and camera
/// proximity. Camera proximity always wins; route alerts wait or drop.
class AwarenessOrchestrator extends ChangeNotifier {
  static const _routeCheckInterval = Duration(seconds: 3);
  static const _routeRadiusM = 200.0;
  static const _routeBannerDuration = Duration(seconds: 6);
  static const _pendingRouteMaxAge = Duration(seconds: 10);
  static const _logInterval = Duration(seconds: 3);
  static const _noticeDuration = Duration(seconds: 8);
  static const _cameraQuietFrames = 3; // frames below closer before the
  // camera alert releases the channel (matches the beep de-escalation)

  static const _severityOrder = ['CAUTION', 'WARNING', 'CRITICAL'];

  final AwarenessPreferenceService prefs;
  final ObjectDetectorService detector;
  final BeepEngine beeps;
  final AwarenessVoiceService voice;
  final DistanceCalibrationService calibration;
  final ObstacleScanService routeScan;
  final DrowsinessDetectionService drowsiness; // read only

  AwarenessOrchestrator({
    required this.prefs,
    required this.detector,
    required this.beeps,
    required this.voice,
    required this.calibration,
    required this.routeScan,
    required this.drowsiness,
  }) {
    prefs.addListener(_onPrefsChanged);
  }

  // ── Public state ──────────────────────────────────────────────────────────
  AwarenessAlert? activeAlert;
  ProximityTier cameraTier = ProximityTier.none;
  List<SensedObject> objects = [];
  String? notice;
  int loggedEvents = 0; // kept after stop() for the trip summary
  bool isActive = false;
  bool cameraActive = false;
  double speedKmh = 0;

  // ── Internals ─────────────────────────────────────────────────────────────
  String? _tripId;
  StreamSubscription<Position>? _positionSub;
  Position? _position;
  Timer? _routeTimer;
  Timer? _routeBannerTimer;
  Timer? _noticeTimer;

  final Set<String> _alertedIds = {};
  AwarenessAlert? _routeAlert;
  AwarenessAlert? _cameraAlert;
  _PendingRoute? _pendingRoute;

  bool _cameraHot = false; // camera alert owns the channel
  int _quietFrames = 0;
  int? _voicedTrackId;
  ProximityTier _voicedTier = ProximityTier.none;
  DateTime? _lastLogAt;
  DateTime? _closeSince;

  Future<void> start(String tripId) async {
    if (isActive) await stop();
    if (!prefs.masterEnabled) return;

    isActive = true;
    _tripId = tripId;
    loggedEvents = 0;
    _alertedIds.clear();

    beeps.setEnabled(prefs.beepsEnabled);
    beeps.setMasterVolume(prefs.beepVolume);

    _startPositionStream();

    if (prefs.routeAlertsEnabled) {
      _routeTimer = Timer.periodic(_routeCheckInterval, (_) => _checkRoute());
    }
    if (prefs.cameraProximityEnabled) await _startCamera();
    notifyListeners();
  }

  Future<void> stop() async {
    isActive = false;
    _routeTimer?.cancel();
    _routeTimer = null;
    _routeBannerTimer?.cancel();
    _routeBannerTimer = null;
    _noticeTimer?.cancel();
    _noticeTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;

    if (cameraActive) await detector.stop();
    cameraActive = false;
    beeps.stop();
    await voice.stop();

    activeAlert = null;
    _routeAlert = null;
    _cameraAlert = null;
    _pendingRoute = null;
    _alertedIds.clear();
    cameraTier = ProximityTier.none;
    objects = [];
    notice = null;
    _position = null;
    speedKmh = 0;
    _cameraHot = false;
    _quietFrames = 0;
    _voicedTrackId = null;
    _voicedTier = ProximityTier.none;
    _lastLogAt = null;
    _closeSince = null;
    notifyListeners();
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  void _startPositionStream() {
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 0,
                intervalDuration: const Duration(seconds: 1),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 0,
              );
    try {
      _positionSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen((p) {
        _position = p;
        speedKmh = math.max(0, p.speed) * 3.6;
      }, onError: (Object e) => debugPrint('[awareness] position: $e'));
    } catch (e) {
      debugPrint('[awareness] position stream failed: $e');
    }
  }

  /// Front and rear cameras cannot run together on every phone. A
  /// wireless drowsiness camera does not hold a phone camera.
  bool get _drowsinessHoldsCamera {
    if (drowsiness.isRunning) {
      return !(drowsiness.activeSource?.isNetwork ?? false);
    }
    final dp = drowsiness.preferences;
    return dp.detectionEnabled && dp.selectedCameraId != 'network';
  }

  Future<void> _startCamera() async {
    if (_drowsinessHoldsCamera) {
      _setNotice(
          'Camera proximity is off: drowsiness detection is using the camera.');
      return;
    }
    final status = await Permission.camera.request();
    if (!isActive) return;
    if (!status.isGranted) {
      _setNotice('Camera proximity is off: camera permission was denied.');
      return;
    }
    final ok = await detector.start(onFrame: _onFrame);
    if (!isActive) {
      if (ok) await detector.stop();
      return;
    }
    cameraActive = ok;
    if (!ok) {
      debugPrint('[awareness] ${detector.errorMessage}');
      _setNotice('Camera proximity is off: the rear camera could not start.');
    }
  }

  void _onPrefsChanged() {
    if (!isActive) return;
    if (!prefs.masterEnabled) {
      stop();
      return;
    }
    beeps.setEnabled(prefs.beepsEnabled);
    beeps.setMasterVolume(prefs.beepVolume);
  }

  // ── Camera proximity ──────────────────────────────────────────────────────

  void _onFrame(List<SensedObject> objs) {
    if (!isActive) return;
    final followS = prefs.followingTimeSeconds;

    SensedObject? worst;
    for (final o in objs) {
      final d = o.distanceM;
      o.tier = d != null
          ? classifyProximity(
              distanceM: d,
              speedKmh: speedKmh,
              followingTimeS: followS,
              inPath: o.inPath,
              ttcSeconds: o.ttcSeconds,
            )
          : classifyGenericObstacle(o.areaFraction, o.inPath);
      if (worst == null ||
          o.tier.index > worst.tier.index ||
          (o.tier == worst.tier &&
              (o.distanceM ?? double.infinity) <
                  (worst.distanceM ?? double.infinity))) {
        worst = o;
      }
    }

    objects = objs;
    cameraTier = worst?.tier ?? ProximityTier.none;
    beeps.submitTier(cameraTier); // every frame, even when none

    final alerting = worst != null &&
        cameraTier.index >= ProximityTier.closer.index;
    if (alerting) {
      _quietFrames = 0;
      _cameraHot = true;
      _cameraAlert = _cameraAlertFor(worst);
      _maybeSpeakProximity(worst);
      _maybeLog(worst, followS);
    } else if (_cameraHot) {
      _quietFrames++;
      if (_quietFrames >= _cameraQuietFrames) {
        _cameraHot = false;
        _cameraAlert = null;
        _voicedTrackId = null;
        _voicedTier = ProximityTier.none;
        _closeSince = null;
        _deliverPendingRoute(); // channel is free again
      }
    }

    _refreshBanner(notify: false);
    notifyListeners();
  }

  AwarenessAlert _cameraAlertFor(SensedObject o) {
    final d = o.distanceM;
    final where = o.inPath ? '' : ' - beside the path';
    return AwarenessAlert(
      source: AlertSource.camera,
      key: 'cam_${o.trackId}',
      title: AwarenessVoiceService.displayName(o.group),
      subtitle: d != null
          ? '${d.toStringAsFixed(1)} m$where'
          : 'Large object ahead',
      tier: o.tier,
      icon: AwarenessAlert.iconForGroup(o.group),
      at: DateTime.now(),
    );
  }

  /// Speaks only when the tier escalates to veryClose or critical for a
  /// new object or a higher tier; never on every frame.
  void _maybeSpeakProximity(SensedObject o) {
    if (!prefs.voiceEnabled) return;
    if (o.tier.index < ProximityTier.veryClose.index) return;
    final isNewObject = o.trackId != _voicedTrackId;
    final isHigher = o.tier.index > _voicedTier.index;
    if (!isNewObject && !isHigher) return;

    // The single critical phrase always speaks, even over the beep loop
    final critical = o.tier == ProximityTier.critical &&
        _voicedTier != ProximityTier.critical;
    if (!critical && !voice.canSpeak) return; // retried on a later frame

    final phrase = AwarenessVoiceService.proximityPhrase(
        o.group, o.tier, prefs.voiceLanguage);
    if (phrase == null) return;
    _voicedTrackId = o.trackId;
    _voicedTier = o.tier;
    unawaited(voice.speak(phrase, prefs.voiceLanguage, critical: critical));
  }

  void _maybeLog(SensedObject o, double followS) {
    final tripId = _tripId;
    final d = o.distanceM;
    if (tripId == null || d == null) return; // backend needs a distance
    final now = DateTime.now();
    _closeSince ??= now;
    if (_lastLogAt != null && now.difference(_lastLogAt!) < _logInterval) {
      return;
    }
    _lastLogAt = now;
    final safe = math.max(speedKmh / 3.6 * followS, 6.0);
    AwarenessEventLogger.log(
      tripId: tripId,
      distanceM: d,
      safeDistanceM: safe,
      speedKmh: speedKmh,
      tier: o.tier,
      ttcSeconds: o.ttcSeconds,
      durationSeconds: now.difference(_closeSince!).inMilliseconds / 1000,
    ).then((ok) {
      if (ok && _tripId == tripId) {
        loggedEvents++;
        notifyListeners();
      }
    });
  }

  // ── Route hazards ─────────────────────────────────────────────────────────

  void _checkRoute() {
    if (!isActive || !prefs.routeAlertsEnabled) return;
    _deliverPendingRoute();

    final pos = _position;
    if (pos == null || routeScan.obstacles.isEmpty) return;

    final candidates = <(ObstacleModel, double)>[];
    for (final o in routeScan.obstacles) {
      if (_alertedIds.contains(o.id)) continue;
      if (!prefs.shouldAlertRoute(o.severity)) continue;
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, o.latitude, o.longitude);
      if (dist <= _routeRadiusM) candidates.add((o, dist));
    }
    if (candidates.isEmpty) return;

    // Highest severity first, then nearest
    candidates.sort((a, b) {
      final sa = _severityOrder.indexOf(a.$1.severity);
      final sb = _severityOrder.indexOf(b.$1.severity);
      if (sa != sb) return sb.compareTo(sa);
      return a.$2.compareTo(b.$2);
    });
    final (obstacle, dist) = candidates.first;
    _alertedIds.add(obstacle.id);

    final si = prefs.voiceLanguage == 'si';
    final alert = AwarenessAlert(
      source: AlertSource.route,
      key: 'route_${obstacle.id}',
      title: si ? obstacle.alert.shortSi : obstacle.alert.shortEn,
      subtitle: '${dist.round()} m ahead',
      tier: AwarenessAlert.tierForRouteSeverity(obstacle.severity),
      severityLabel: obstacle.severity,
      icon: obstacle.materialIcon,
      at: DateTime.now(),
    );
    final voiceText = si ? obstacle.alert.voiceSi : obstacle.alert.voiceEn;

    if (_cameraHot) {
      // Camera proximity owns the channel: hold (newest wins) for up to 10 s
      _pendingRoute = _PendingRoute(alert, voiceText, DateTime.now());
      return;
    }
    _deliverRoute(alert, voiceText);
  }

  void _deliverPendingRoute() {
    final p = _pendingRoute;
    if (p == null || _cameraHot) return;
    _pendingRoute = null;
    if (DateTime.now().difference(p.queuedAt) > _pendingRouteMaxAge) {
      return; // stale: dropped
    }
    _deliverRoute(p.alert, p.voiceText);
  }

  Future<void> _deliverRoute(AwarenessAlert alert, String voiceText) async {
    _routeAlert = alert;
    _routeBannerTimer?.cancel();
    _routeBannerTimer = Timer(_routeBannerDuration, () {
      if (_routeAlert?.key == alert.key) {
        _routeAlert = null;
        _refreshBanner();
      }
    });
    _refreshBanner();

    // One soft attention beep, then the voice
    if (prefs.beepsEnabled) {
      await beeps.playPatternOnce(ProximityTier.far);
    }
    if (!isActive || _cameraHot || !prefs.voiceEnabled) return;
    await voice.speak(voiceText, prefs.voiceLanguage);
  }

  // ── Banner / notice ───────────────────────────────────────────────────────

  /// Only one banner: the camera alert while it owns the channel,
  /// otherwise the route alert for its 6 seconds.
  void _refreshBanner({bool notify = true}) {
    activeAlert = _cameraHot ? _cameraAlert : _routeAlert;
    if (notify) notifyListeners();
  }

  void _setNotice(String msg) {
    notice = msg;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(_noticeDuration, () {
      notice = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    prefs.removeListener(_onPrefsChanged);
    _routeTimer?.cancel();
    _routeBannerTimer?.cancel();
    _noticeTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}

class _PendingRoute {
  final AwarenessAlert alert;
  final String voiceText;
  final DateTime queuedAt;
  _PendingRoute(this.alert, this.voiceText, this.queuedAt);
}
