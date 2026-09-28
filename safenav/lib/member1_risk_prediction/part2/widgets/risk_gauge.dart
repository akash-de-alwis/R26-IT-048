import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/realtime_risk_model.dart';

enum RiskTrend { rising, steady, falling }

/// Trend of the latest score against the average of the previous
/// [window] of history. Within [steadyBand] points counts as steady.
/// Returns null with fewer than 3 points.
RiskTrend? riskTrend(
  List<(DateTime, double)> history, {
  Duration window = const Duration(seconds: 60),
  double steadyBand = 3,
}) {
  if (history.length < 3) return null;
  final (latestAt, latest) = history.last;
  final cutoff = latestAt.subtract(window);
  final previous = [
    for (final (t, s) in history.sublist(0, history.length - 1))
      if (!t.isBefore(cutoff)) s,
  ];
  // Long gap between readings: compare with the reading just before
  if (previous.isEmpty) previous.add(history[history.length - 2].$2);
  final avg = previous.reduce((a, b) => a + b) / previous.length;
  final delta = latest - avg;
  if (delta > steadyBand) return RiskTrend.rising;
  if (delta < -steadyBand) return RiskTrend.falling;
  return RiskTrend.steady;
}

/// Semicircular risk gauge: four level segments and an animated needle,
/// with the score, the level chip and a trend chip underneath.
class RiskGauge extends StatelessWidget {
  static const double width = 200;
  static const double height = 112;

  final double score; // 0..100
  final RiskLevel level;
  final String levelLabel; // LOW / MODERATE / HIGH / CRITICAL
  final RiskTrend? trend; // null until there is enough history

  const RiskGauge({
    super.key,
    required this.score,
    required this.level,
    required this.levelLabel,
    this.trend,
  });

  // Darker level shades so white chip text stays readable
  static Color _levelChipColor(RiskLevel l) => switch (l) {
        RiskLevel.low => const Color(0xFF00794A),
        RiskLevel.moderate => const Color(0xFF8A6300),
        RiskLevel.high => const Color(0xFFB34E00),
        RiskLevel.critical => const Color(0xFFC62828),
      };

  @override
  Widget build(BuildContext context) {
    final target = score.clamp(0.0, 100.0);
    return RepaintBoundary(
      child: Column(
        children: [
          // Animates from 0 on first display, then from the current value
          // whenever the score changes.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, value, _) => Column(
              children: [
                SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(painter: _GaugePainter(value)),
                ),
                const SizedBox(height: 2),
                Text(
                  value.round().toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B2A),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _levelChipColor(level),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  levelLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 8),
                _TrendChip(trend: trend!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final RiskTrend trend;
  const _TrendChip({required this.trend});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (trend) {
      RiskTrend.rising => (
          Icons.trending_up_rounded,
          'Rising',
          const Color(0xFFB34E00), // orange, darkened for contrast
        ),
      RiskTrend.steady => (
          Icons.trending_flat_rounded,
          'Steady',
          const Color(0xFF4A5663),
        ),
      RiskTrend.falling => (
          Icons.trending_down_rounded,
          'Falling',
          const Color(0xFF00794A),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  static const _stroke = 14.0;
  static const _gapRad = 0.02; // small visual gap between segments
  static const _segments = [
    (0.0, 25.0, Color(0xFF00C06A)),
    (25.0, 50.0, Color(0xFFFFB300)),
    (50.0, 70.0, Color(0xFFFF8C42)),
    (70.0, 100.0, Color(0xFFFF3B5C)),
  ];

  final double score;
  _GaugePainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final radius = math.min(size.width / 2, size.height - 8) - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (final (from, to, color) in _segments) {
      final start = math.pi + from / 100 * math.pi + _gapRad / 2;
      final sweep = (to - from) / 100 * math.pi - _gapRad;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke,
      );
    }

    // Needle
    final angle = math.pi + score / 100 * math.pi;
    final tip = center +
        Offset(math.cos(angle), math.sin(angle)) * (radius - _stroke / 2 - 6);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFF0D1B2A)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF0D1B2A));
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score;
}
