import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ScoreGaugeWidget extends StatefulWidget {
  final double score;

  const ScoreGaugeWidget({super.key, required this.score});

  @override
  State<ScoreGaugeWidget> createState() => _ScoreGaugeWidgetState();
}

class _ScoreGaugeWidgetState extends State<ScoreGaugeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (widget.score >= 80) return AppColors.success;
    if (widget.score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  String get _scoreLabel {
    if (widget.score >= 80) return 'Good Driver';
    if (widget.score >= 60) return 'Safe Driver';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: [
          // Arc
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) => CustomPaint(
              size: const Size(200, 200),
              painter: _GaugePainter(
                animatedScore: _animation.value,
                color: _scoreColor,
              ),
            ),
          ),
          // Center text — placed slightly above widget center to sit inside the arc
          Align(
            alignment: const Alignment(0, -0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) => Text(
                    _animation.value.round().toString(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: _scoreColor,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'out of 100',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _scoreLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _scoreColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double animatedScore;
  final Color color;

  const _GaugePainter({required this.animatedScore, required this.color});

  // 135° start (bottom-left) → clockwise 270° → ends at 45° (bottom-right)
  static const double _startAngle = 3 * math.pi / 4;
  static const double _totalSweep = 3 * math.pi / 2;
  static const double _radius = 80.0;
  static const double _strokeWidth = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: _radius);

    // Background track
    canvas.drawArc(
      rect,
      _startAngle,
      _totalSweep,
      false,
      Paint()
        ..color = const Color(0xFFEEF1F5)
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Score fill
    if (animatedScore > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _totalSweep * (animatedScore / 100),
        false,
        Paint()
          ..color = color
          ..strokeWidth = _strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.animatedScore != animatedScore || old.color != color;
}
