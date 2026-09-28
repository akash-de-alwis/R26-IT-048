import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Line chart of this trip's risk scores. Hidden until there are at
/// least [minPoints] readings.
class RiskTrendSparkline extends StatelessWidget {
  static const minPoints = 3;
  static const double _chartHeight = 64;

  final List<double> points;
  final Color accent;

  const RiskTrendSparkline({
    super.key,
    required this.points,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < minPoints) return const SizedBox.shrink();
    final lo = points.reduce(math.min);
    final hi = points.reduce(math.max);
    const labelStyle = TextStyle(fontSize: 12, color: Color(0xFF5C6B7A));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Risk over the last few minutes',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D1B2A),
          ),
        ),
        const SizedBox(height: 8),
        // Fixed height: inside a scroll view the Row's height is unbounded,
        // so every child gets an explicit height (no stretch).
        SizedBox(
          height: _chartHeight,
          child: Row(
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(double.infinity, _chartHeight),
                    painter: _SparklinePainter(points, accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('max ${hi.toStringAsFixed(0)}', style: labelStyle),
                  Text('min ${lo.toStringAsFixed(0)}', style: labelStyle),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  static const _minRange = 10.0; // keep small wiggles from looking huge

  final List<double> points;
  final Color accent;
  _SparklinePainter(this.points, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    var lo = points.reduce(math.min);
    var hi = points.reduce(math.max);
    if (hi - lo < _minRange) {
      final mid = (hi + lo) / 2;
      lo = mid - _minRange / 2;
      hi = mid + _minRange / 2;
    }
    const pad = 5.0; // room for the end dot
    final h = size.height - pad * 2;
    final dx = (size.width - pad * 2) / (points.length - 1);
    Offset at(int i) => Offset(
          pad + i * dx,
          pad + h - (points[i] - lo) / (hi - lo) * h,
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(points.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final last = at(points.length - 1);
    canvas.drawCircle(last, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 3.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.accent != accent || !listEquals(old.points, points);
}
