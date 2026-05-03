import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ScoreGaugeWidget extends StatefulWidget {
  final double score;
  final bool onDark;

  const ScoreGaugeWidget({super.key, required this.score, this.onDark = false});

  @override
  State<ScoreGaugeWidget> createState() => _ScoreGaugeWidgetState();
}

class _ScoreGaugeWidgetState extends State<ScoreGaugeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _fromScore = 0;
  double _toScore = 0;

  @override
  void initState() {
    super.initState();
    _fromScore = 0;
    _toScore = widget.score;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ScoreGaugeWidget old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
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
    final trackColor =
        widget.onDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFEEF1F5);

    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final displayed = _currentDisplayScore;
              final color = _colorFor(_toScore);
              return CustomPaint(
                size: const Size(210, 210),
                painter: _GaugePainter(
                  animatedScore: displayed,
                  color: color,
                  trackColor: trackColor,
                ),
              );
            },
          ),
          Align(
            alignment: const Alignment(0, -0.15),
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
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        color: widget.onDark ? Colors.white : color,
                        height: 1.0,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'out of 100',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.onDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorFor(_toScore).withValues(alpha: widget.onDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labelFor(_toScore),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.onDark
                          ? _colorFor(_toScore)
                          : _colorFor(_toScore),
                    ),
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
  final Color trackColor;

  const _GaugePainter({
    required this.animatedScore,
    required this.color,
    required this.trackColor,
  });

  static const double _startAngle = 3 * math.pi / 4;
  static const double _totalSweep = 3 * math.pi / 2;
  static const double _radius = 85.0;
  static const double _strokeWidth = 13.0;

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
        ..color = trackColor
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
      old.animatedScore != animatedScore ||
      old.color != color ||
      old.trackColor != trackColor;
}
