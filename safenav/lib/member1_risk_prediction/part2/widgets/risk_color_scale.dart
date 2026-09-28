import 'package:flutter/painting.dart';

/// Colours for the trip-in-progress sheet at a given risk score.
class RiskPalette {
  final Color top; // gradient start
  final Color bottom; // gradient end (top blended toward white)
  final Color accent; // selected tab text, risk circle, End Trip button

  const RiskPalette({
    required this.top,
    required this.bottom,
    required this.accent,
  });
}

// ── Tunable colour stops (score -> colour) ──────────────────────────────────
const Color kRiskBlue = Color(0xFF2979FF); // 0: safe (original sheet colour)
const Color kRiskViolet = Color(0xFF7E57C2); // 30
const Color kRiskPink = Color(0xFFE0457B); // 55
const Color kRiskRed = Color(0xFFE53935); // 75
const Color kRiskDeepRed = Color(0xFFC62828); // 100

const double kRiskStopBlue = 0;
const double kRiskStopViolet = 30;
const double kRiskStopPink = 55;
const double kRiskStopRed = 75;
const double kRiskStopDeepRed = 100;

/// How far the gradient bottom is blended toward white.
const double kRiskBottomWhiteBlend = 0.28;

const List<(double, Color)> _stops = [
  (kRiskStopBlue, kRiskBlue),
  (kRiskStopViolet, kRiskViolet),
  (kRiskStopPink, kRiskPink),
  (kRiskStopRed, kRiskRed),
  (kRiskStopDeepRed, kRiskDeepRed),
];

/// Base colour for [score] (clamped to 0..100), linearly interpolated
/// between the two nearest stops.
Color riskBaseColor(double score) {
  final s = score.isNaN ? 0.0 : score.clamp(0.0, 100.0);
  for (var i = 0; i < _stops.length; i++) {
    final (stop, color) = _stops[i];
    if (s == stop) return color;
    if (s < stop) {
      final (prevStop, prevColor) = _stops[i - 1];
      final t = (s - prevStop) / (stop - prevStop);
      return Color.lerp(prevColor, color, t)!;
    }
  }
  return _stops.last.$2;
}

RiskPalette paletteForScore(double score) {
  final top = riskBaseColor(score);
  return RiskPalette(
    top: top,
    bottom: Color.lerp(top, const Color(0xFFFFFFFF), kRiskBottomWhiteBlend)!,
    accent: top,
  );
}
