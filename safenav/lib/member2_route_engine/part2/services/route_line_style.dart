import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/route_segment_model.dart';
import 'route_geometry_splitter.dart';

/// Pure helpers for building Mapbox line-layer properties for route lines.
/// Expressions are raw style-spec JSON lists, which is what the
/// `*Expression` properties in mapbox_maps_flutter 2.x accept.
class RouteLineStyle {
  RouteLineStyle._();

  /// Main line width at zoom 14 with factor 1.0; used to convert
  /// [casingExtra] (px) into a width factor.
  static const double baseWidth = 5.5;

  /// Width scales with zoom, like Google Maps (thin when zoomed out, thick
  /// when zoomed in). Multiply per layer with [factor].
  static List<Object> widthByZoom({double factor = 1.0}) => [
        'interpolate', ['linear'], ['zoom'],
        10, 3.0 * factor,
        14, 5.5 * factor,
        16, 7.5 * factor,
        18, 10.0 * factor,
      ];

  /// Casing width factor for a line drawn at [mainFactor].
  static double casingFactor(double mainFactor) =>
      mainFactor + casingExtra / baseWidth;

  static const double casingExtra = 4.0; // casing is main width + this
  static const int casingColor = 0xFFFFFFFF;
  static const double casingOpacity = 0.95;
  static const int traveledColor = 0xFFB9C2CC;
  static const double traveledOpacity = 0.85;

  static const double selectedWidthFactor = 1.0;
  static const double alternateWidthFactor = 0.6;
  static const double travelledWidthFactorScale = 0.85;

  static const LineCap cap = LineCap.ROUND;
  static const LineJoin join = LineJoin.ROUND;

  /// Distance (m) over which neighbouring congestion colours blend.
  static const double gradientBlendM = 30.0;

  /// Builds a `line-gradient` expression over `line-progress` from the
  /// route's congestion segments. Colours come straight from each
  /// segment's existing `colorHex`; only the transition between them is
  /// softened over [gradientBlendM] metres. Fractions are measured with the
  /// same haversine length as the drawn geometry (the segments joined).
  static List<Object> congestionGradient(List<RouteSegment> segments,
      {String fallbackHex = '#2979FF'}) {
    final spans = <({double len, String color})>[];
    for (final seg in segments) {
      final geo = seg.geometry.where((p) => p.length >= 2).toList();
      if (geo.length < 2) continue;
      spans.add((len: polylineLengthM(geo), color: seg.colorHex.toLowerCase()));
    }
    final total = spans.fold<double>(0, (s, e) => s + e.len);
    if (spans.isEmpty || total <= 0) {
      return _flat(fallbackHex.toLowerCase());
    }

    final stops = <(double, String)>[(0.0, spans.first.color)];
    double cursor = 0;
    for (int i = 0; i < spans.length - 1; i++) {
      cursor += spans[i].len;
      final a = spans[i], b = spans[i + 1];
      if (a.color == b.color) continue;
      final blend = [gradientBlendM, a.len / 2, b.len / 2]
          .reduce((x, y) => x < y ? x : y);
      stops.add(((cursor - blend) / total, a.color));
      stops.add(((cursor + blend) / total, b.color));
    }
    stops.add((1.0, spans.last.color));

    // interpolate needs strictly ascending inputs in [0, 1]
    final expr = <Object>['interpolate', ['linear'], ['line-progress']];
    double last = -1;
    for (final (f, c) in stops) {
      final frac = f.clamp(0.0, 1.0);
      if (frac <= last) continue;
      expr..add(frac)..add(c);
      last = frac;
    }
    if (expr.length < 7) return _flat(spans.first.color);
    return expr;
  }

  static List<Object> _flat(String hex) =>
      ['interpolate', ['linear'], ['line-progress'], 0.0, hex, 1.0, hex];
}
