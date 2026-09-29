import 'dart:async';
import 'dart:convert';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/enhanced_route_model.dart';
import 'route_geometry_splitter.dart';
import 'route_line_style.dart';

/// Draws enhanced routes as Google-Maps-style style layers:
///
///   alternates: white casing → dimmed line (one source, per-feature colour)
///   selected:   white casing → grey travelled → congestion gradient line
///
/// Sources and layers are created once and then updated in place, so
/// redraws and position updates never remove/re-add layers (no flicker,
/// and markers added after the first draw stay above the route).
///
/// Congestion colours use `line-gradient` (supported by mapbox_maps_flutter
/// 2.22 with `lineMetrics: true`), so colour changes blend over
/// [RouteLineStyle.gradientBlendM] instead of cutting sharply. During a
/// trip the portion behind the driver is hidden with `line-trim-offset`
/// rather than by re-slicing the geometry, so the gradient never has to be
/// recomputed as the driver moves; visually the coloured line covers only
/// the remaining route.
class EnhancedRouteRenderer {
  EnhancedRouteRenderer(this._map);

  final MapboxMap _map;

  static const _altSrc = 'enh-route-alt-src';
  static const _mainSrc = 'enh-route-main-src';
  static const _travelledSrc = 'enh-route-travelled-src';
  static const _altCasing = 'enh-route-alt-casing';
  static const _altLine = 'enh-route-alt-line';
  static const _mainCasing = 'enh-route-main-casing';
  static const _travelledLine = 'enh-route-travelled-line';
  static const _mainLine = 'enh-route-main-line';

  static const _emptyFc = '{"type":"FeatureCollection","features":[]}';
  static const _progressThrottle = Duration(seconds: 2);

  List<List<double>> _mainGeometry = const [];
  bool _trackProgress = false;
  DateTime _lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pendingTimer;
  ({double lat, double lng})? _pendingPos;

  /// Draws [routes]. [selected] gets the full style; the others are dimmed.
  /// When [tripActive] the travelled split is shown and kept up to date by
  /// [updateProgress], starting from ([lat], [lng]) if given.
  Future<void> draw({
    required List<EnhancedRouteModel> routes,
    required EnhancedRouteModel? selected,
    required bool tripActive,
    double? lat,
    double? lng,
  }) async {
    await _ensureLayers();
    final style = _map.style;

    // Alternates — unchanged dimmed colours, now with casing + round style
    final altFeatures = <Map<String, dynamic>>[];
    for (final route in routes) {
      if (selected != null && route.routeType == selected.routeType) continue;
      if (route.geometry.length < 2) continue;
      altFeatures.add({
        'type': 'Feature',
        'properties': {'color': _hex(_dimColorFor(route.routeType))},
        'geometry': {'type': 'LineString', 'coordinates': route.geometry},
      });
    }
    await style.setStyleSourceProperty(_altSrc, 'data',
        json.encode({'type': 'FeatureCollection', 'features': altFeatures}));

    // Selected — geometry is the segments joined, so gradient fractions
    // line up exactly with line-progress along what is drawn.
    _mainGeometry = selected == null ? const [] : _joinedGeometry(selected);
    _trackProgress = tripActive && _mainGeometry.length >= 2;

    if (_mainGeometry.length < 2) {
      await style.setStyleSourceProperty(_mainSrc, 'data', _emptyFc);
      await style.setStyleSourceProperty(_travelledSrc, 'data', _emptyFc);
      return;
    }

    await style.setStyleLayerProperty(
      _mainLine,
      'line-gradient',
      RouteLineStyle.congestionGradient(selected!.segments,
          fallbackHex: _hex(selected.color.toARGB32())),
    );
    await style.setStyleSourceProperty(_mainSrc, 'data', _lineFeature(_mainGeometry));

    if (_trackProgress && lat != null && lng != null) {
      await _applyProgress(lat, lng);
    } else {
      await _setTravelled(null);
    }
  }

  /// Feed position updates here; ignored unless a trip route is drawn.
  /// Applied at most once per [_progressThrottle]; the latest position
  /// inside a throttled window is applied when the window ends.
  void updateProgress(double lat, double lng) {
    if (!_trackProgress) return;
    final wait = _progressThrottle - DateTime.now().difference(_lastProgressAt);
    if (wait <= Duration.zero) {
      _applyProgress(lat, lng);
      return;
    }
    _pendingPos = (lat: lat, lng: lng);
    _pendingTimer ??= Timer(wait, () {
      _pendingTimer = null;
      final p = _pendingPos;
      _pendingPos = null;
      if (p != null && _trackProgress) _applyProgress(p.lat, p.lng);
    });
  }

  /// Hides all route lines (layers are kept for reuse).
  Future<void> clear() async {
    _trackProgress = false;
    _mainGeometry = const [];
    _cancelPending();
    final style = _map.style;
    for (final src in [_altSrc, _mainSrc, _travelledSrc]) {
      try {
        await style.setStyleSourceProperty(src, 'data', _emptyFc);
      } catch (_) {}
    }
  }

  void dispose() => _cancelPending();

  // ── internals ─────────────────────────────────────────────────────────────

  void _cancelPending() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingPos = null;
  }

  Future<void> _applyProgress(double lat, double lng) async {
    _lastProgressAt = DateTime.now();
    try {
      await _setTravelled(splitAtNearestPoint(_mainGeometry, lat, lng));
    } catch (_) {}
  }

  Future<void> _setTravelled(RouteSplitResult? split) async {
    final style = _map.style;
    final travelled = split?.travelled ?? const <List<double>>[];
    await style.setStyleSourceProperty(_travelledSrc, 'data',
        travelled.length >= 2 ? _lineFeature(travelled) : _emptyFc);
    await style.setStyleLayerProperty(
        _mainLine, 'line-trim-offset', [0.0, split?.progressFraction ?? 0.0]);
  }

  Future<void> _ensureLayers() async {
    final style = _map.style;
    if (await style.styleSourceExists(_mainSrc)) return;

    // Style was (re)loaded — drop any partial leftovers first
    for (final id in [
      _mainLine, _travelledLine, _mainCasing, _altLine, _altCasing,
    ]) {
      try { await style.removeStyleLayer(id); } catch (_) {}
    }
    for (final id in [_altSrc, _mainSrc, _travelledSrc]) {
      try { await style.removeStyleSource(id); } catch (_) {}
    }

    await style.addSource(GeoJsonSource(id: _altSrc, data: _emptyFc));
    await style.addSource(
        GeoJsonSource(id: _mainSrc, data: _emptyFc, lineMetrics: true));
    await style.addSource(GeoJsonSource(id: _travelledSrc, data: _emptyFc));

    const alt = RouteLineStyle.alternateWidthFactor;
    const sel = RouteLineStyle.selectedWidthFactor;

    // First added = bottom
    await style.addLayer(LineLayer(
      id: _altCasing,
      sourceId: _altSrc,
      lineColor: RouteLineStyle.casingColor,
      lineOpacity: 0.6,
      lineWidthExpression:
          RouteLineStyle.widthByZoom(factor: RouteLineStyle.casingFactor(alt)),
      lineCap: RouteLineStyle.cap,
      lineJoin: RouteLineStyle.join,
    ));
    await style.addLayer(LineLayer(
      id: _altLine,
      sourceId: _altSrc,
      lineColorExpression: ['to-color', ['get', 'color']],
      lineOpacity: 0.65,
      lineWidthExpression: RouteLineStyle.widthByZoom(factor: alt),
      lineCap: RouteLineStyle.cap,
      lineJoin: RouteLineStyle.join,
    ));
    await style.addLayer(LineLayer(
      id: _mainCasing,
      sourceId: _mainSrc,
      lineColor: RouteLineStyle.casingColor,
      lineOpacity: RouteLineStyle.casingOpacity,
      lineWidthExpression:
          RouteLineStyle.widthByZoom(factor: RouteLineStyle.casingFactor(sel)),
      lineCap: RouteLineStyle.cap,
      lineJoin: RouteLineStyle.join,
    ));
    await style.addLayer(LineLayer(
      id: _travelledLine,
      sourceId: _travelledSrc,
      lineColor: RouteLineStyle.traveledColor,
      lineOpacity: RouteLineStyle.traveledOpacity,
      lineWidthExpression: RouteLineStyle.widthByZoom(
          factor: sel * RouteLineStyle.travelledWidthFactorScale),
      lineCap: RouteLineStyle.cap,
      lineJoin: RouteLineStyle.join,
    ));
    await style.addLayer(LineLayer(
      id: _mainLine,
      sourceId: _mainSrc,
      lineOpacity: 0.95,
      lineGradientExpression: RouteLineStyle.congestionGradient(const []),
      lineTrimOffset: [0.0, 0.0],
      lineWidthExpression: RouteLineStyle.widthByZoom(factor: sel),
      lineCap: RouteLineStyle.cap,
      lineJoin: RouteLineStyle.join,
    ));
  }

  static List<List<double>> _joinedGeometry(EnhancedRouteModel route) {
    final out = <List<double>>[];
    for (final seg in route.segments) {
      for (final p in seg.geometry) {
        if (p.length < 2) continue;
        if (out.isNotEmpty && out.last[0] == p[0] && out.last[1] == p[1]) {
          continue;
        }
        out.add([p[0], p[1]]);
      }
    }
    return out.length >= 2 ? out : route.geometry;
  }

  static String _lineFeature(List<List<double>> coords) => json.encode({
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {'type': 'LineString', 'coordinates': coords},
      });

  static int _dimColorFor(String routeType) => switch (routeType) {
        'safest' => 0xFF8FCBB1,
        'balanced' => 0xFF9FB8E8,
        'fastest' => 0xFFE8B89A,
        _ => 0xFFB5BFCC,
      };

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
