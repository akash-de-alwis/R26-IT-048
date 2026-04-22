import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ScoreGaugeWidget extends StatefulWidget {
  final double score;

  const ScoreGaugeWidget({super.key, required this.score});

  @override
  State<ScoreGaugeWidget> createState() => _ScoreGaugeWidgetState();
}

class _ScoreGaugeWidgetState extends State<ScoreGaugeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Track animated range explicitly so we can update it safely
  double _fromScore = 0;
  double _toScore = 0;

  @override
  void initState() {
    super.initState();
    _fromScore = 0;
    _toScore = widget.score;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ScoreGaugeWidget old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      // Defer to avoid calling forward() during a build phase, which would
      // synchronously notify AnimatedBuilder and trigger setState mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _fromScore = _currentDisplayScore;
          _toScore = widget.score;
        });
        _controller.forward(from: 0);
      });
    }
  }

  double get _currentDisplayScore =>
      _fromScore + (_toScore - _fromScore) * _controller.value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorFor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  String _labelFor(double score) {
    if (score >= 80) return 'Good Driver';
    if (score >= 60) return 'Safe Driver';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final displayed = _currentDisplayScore;
              final color = _colorFor(_toScore);
              return CustomPaint(
                size: const Size(200, 200),
                painter: _GaugePainter(animatedScore: displayed, color: color),
              );
            },
          ),
          Align(
            alignment: const Alignment(0, -0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final displayed = _currentDisplayScore;
                    final color = _colorFor(_toScore);
                    return Text(
                      displayed.round().toString(),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.0,
                      ),
                    );
                  },
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
                  _labelFor(_toScore),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _colorFor(_toScore),
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

  static const double _startAngle = 3 * math.pi / 4;
  static const double _totalSweep = 3 * math.pi / 2;
  static const double _radius = 80.0;
  static const double _strokeWidth = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: _radius);

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
