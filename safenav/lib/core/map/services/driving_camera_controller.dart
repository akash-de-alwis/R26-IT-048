import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Google-Maps-style driving camera: during a trip the map is zoomed in,
/// tilted and rotated to the direction of travel, and follows the driver.
/// A user pan pauses following until [recenter] is called.
///
/// Runs its own position stream while a trip is active. The map screen's
/// shared stream uses Geolocator's Android default (~5 s interval), which
/// makes the camera jump; driving follow needs ~1 s updates, and changing
/// the shared stream would change GPS usage for the whole map screen.
/// A user pan is detected with Mapbox's gesture-only scroll callback, which
/// never fires for this controller's own flyTo/easeTo.
class DrivingCameraController extends ChangeNotifier {
  final MapboxMap mapboxMap;

  /// Screen padding for the camera, so the driver sits in the visible
  /// area above the trip sheet rather than at the screen centre.
  final MbxEdgeInsets Function()? viewPadding;

  DrivingCameraController(this.mapboxMap, {this.viewPadding});

  static const double drivingZoom = 17.5;
  static const double drivingPitch = 55.0;
  static const double overviewZoom = 14.0;
  static const double overviewPitch = 0.0;
  static const int followAnimMs = 1000; // matches position update cadence
  static const int transitionMs = 1200; // entering/leaving driving mode
  // GPS heading is noise when (nearly) stationary: keep the last bearing
  static const double _minSpeedForHeadingMps = 1.5;
  // Moves shorter than this are GPS jitter, not a direction of travel
  static const double _minMoveForCourseM = 4;

  bool _isActive = false;
  bool _isFollowing = true;
  double _bearing = 0;
  geo.Position? _lastPos;
  geo.Position? _courseFrom; // last position used for course-over-ground
  StreamSubscription<geo.Position>? _positionSub;
  // Follow updates wait for the enter/recenter flight to finish, so an
  // early fix cannot cut it short at a half-way zoom
  DateTime _transitionEnds = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isActive => _isActive;
  bool get isFollowing => _isFollowing;

  /// Enters driving view at [from] (or a fresh fix) and starts following.
  Future<void> start({geo.Position? from}) async {
    _isActive = true;
    _isFollowing = true;
    notifyListeners();
    // Gesture-only listeners: a user pan pauses follow; a pinch zoom does
    // not (follow keeps the user's zoom, see _follow).
    mapboxMap.setOnMapMoveListener((_) => onUserPanDetected());

    final pos = from ?? _lastPos ?? await _currentFix();
    if (!_isActive || pos == null) return;
    _lastPos = pos;
    _updateBearing(pos);
    await _flyToDriving(pos);
    if (!_isActive) return;
    await _positionSub?.cancel();
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? geo.AndroidSettings(
              accuracy: geo.LocationAccuracy.bestForNavigation,
              distanceFilter: 3,
              intervalDuration: const Duration(seconds: 1),
            )
          : const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.bestForNavigation,
              distanceFilter: 3,
            ),
    ).listen(onPosition, onError: (_) {});
  }

  /// Location updates from this controller's trip stream.
  @visibleForTesting
  void onPosition(geo.Position pos) {
    _lastPos = pos;
    if (!_isActive) return;
    _updateBearing(pos);
    if (_isFollowing && DateTime.now().isAfter(_transitionEnds)) {
      _follow(pos);
    }
  }

  /// Called for user-initiated pans only (gesture callback).
  void onUserPanDetected() {
    if (!_isActive || !_isFollowing) return;
    _isFollowing = false;
    notifyListeners();
  }

  /// Flies back to the driver in driving view and resumes following.
  Future<void> recenter() async {
    if (!_isActive) return;
    _isFollowing = true;
    notifyListeners();
    final pos = await _currentFix() ?? _lastPos;
    if (pos == null || !_isActive) return;
    _lastPos = pos;
    _updateBearing(pos);
    await _flyToDriving(pos);
  }

  /// Leaves driving mode: flat, north-up overview at the last position.
  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;
    _isFollowing = true;
    notifyListeners();
    mapboxMap.setOnMapMoveListener(null);
    await _positionSub?.cancel();
    _positionSub = null;
    _courseFrom = null;
    final pos = _lastPos;
    try {
      await mapboxMap.flyTo(
        CameraOptions(
          center: pos == null
              ? null
              : Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: overviewZoom,
          pitch: overviewPitch,
          bearing: 0,
          padding: MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        ),
        MapAnimationOptions(duration: transitionMs),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _isActive = false;
    _positionSub?.cancel();
    try {
      mapboxMap.setOnMapMoveListener(null);
    } catch (_) {}
    super.dispose();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<geo.Position?> _currentFix() async {
    try {
      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Direction of travel: course over ground between successive fixes
  /// (reliable on devices and emulators), falling back to the reported GPS
  /// heading only while there has not been a long enough move yet.
  void _updateBearing(geo.Position pos) {
    final from = _courseFrom;
    if (from == null) {
      _courseFrom = pos;
    } else {
      final moved = geo.Geolocator.distanceBetween(
          from.latitude, from.longitude, pos.latitude, pos.longitude);
      if (moved >= _minMoveForCourseM) {
        _bearing = (geo.Geolocator.bearingBetween(
                    from.latitude, from.longitude, pos.latitude, pos.longitude) +
                360) %
            360;
        _courseFrom = pos;
        return;
      }
    }
    if (from == null &&
        pos.speed >= _minSpeedForHeadingMps &&
        pos.heading >= 0) {
      _bearing = pos.heading;
    }
  }

  CameraOptions _drivingCamera(geo.Position pos, {bool setZoom = true}) =>
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: setZoom ? drivingZoom : null,
        pitch: drivingPitch,
        bearing: _bearing,
        padding: viewPadding?.call(),
      );

  Future<void> _flyToDriving(geo.Position pos) async {
    _transitionEnds =
        DateTime.now().add(const Duration(milliseconds: transitionMs));
    try {
      await mapboxMap.flyTo(
        _drivingCamera(pos),
        MapAnimationOptions(duration: transitionMs),
      );
    } catch (_) {}
  }

  /// Follow updates keep the current zoom, so the zoom control and pinch
  /// zoom still work while following.
  Future<void> _follow(geo.Position pos) async {
    try {
      await mapboxMap.easeTo(
        _drivingCamera(pos, setZoom: false),
        MapAnimationOptions(duration: followAnimMs),
      );
    } catch (_) {}
  }
}
