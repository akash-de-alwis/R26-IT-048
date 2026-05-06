import 'dart:math';
import 'package:flutter/material.dart';

class SegmentedGaugePainter extends CustomPainter {
  final double score;
  final double animatedValue;
  final Color activeColor;
  final Color inactiveColor;

  const SegmentedGaugePainter({
    required this.score,
    required this.animatedValue,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int totalSegments = 16;
    const double startAngle = pi * 0.75;
    const double sweepAngle = pi * 1.5;
    const double segmentGap = 0.08;
    const double segmentWidth = 22.0;
    const double segmentHeight = 12.0;
    const double cornerRadius = 6.0;

    final double cx = size.width / 2;
    final double cy = size.height * 0.58;
    final double radius = size.width * 0.38;

    final double segmentArc =
        (sweepAngle - segmentGap * totalSegments) / totalSegments;

    final int filledCount =
        (animatedValue * (score / 100) * totalSegments).round();

    for (int i = 0; i < totalSegments; i++) {
      final double angle =
          startAngle + i * (segmentArc + segmentGap) + segmentArc / 2;

      final double px = cx + radius * cos(angle);
      final double py = cy + radius * sin(angle);

      final bool isFilled = i < filledCount;

      final double distFromTop =
          (angle - (startAngle + sweepAngle / 2)).abs();
      final double sizeMultiplier =
          1.0 - (distFromTop / (pi * 0.9)) * 0.3;

      final double sW = segmentWidth * sizeMultiplier;
      final double sH = segmentHeight * sizeMultiplier;

      final paint = Paint()
        ..color = isFilled ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(angle + pi / 2);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: sW, height: sH),
        const Radius.circular(cornerRadius),
      );

      canvas.drawRRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SegmentedGaugePainter old) =>
      old.animatedValue != animatedValue || old.score != score;
}

class SegmentedGauge extends StatefulWidget {
  final double score;
  final Color activeColor;
  final Color inactiveColor;
  final double size;

  const SegmentedGauge({
    super.key,
    required this.score,
    required this.activeColor,
    required this.inactiveColor,
    required this.size,
  });

  @override
  State<SegmentedGauge> createState() => _SegmentedGaugeState();
}

class _SegmentedGaugeState extends State<SegmentedGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size * 0.65),
        painter: SegmentedGaugePainter(
          score: widget.score,
          animatedValue: _animation.value,
          activeColor: widget.activeColor,
          inactiveColor: widget.inactiveColor,
        ),
      ),
    );
  }
}
