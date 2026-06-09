import 'dart:math' as math;
import 'package:flutter/material.dart';

class DrowsinessCalibrationOverlay extends StatefulWidget {
  final int secondsRemaining;
  final VoidCallback onCancel;

  const DrowsinessCalibrationOverlay({
    super.key,
    required this.secondsRemaining,
    required this.onCancel,
  });

  @override
  State<DrowsinessCalibrationOverlay> createState() =>
      _DrowsinessCalibrationOverlayState();
}

class _DrowsinessCalibrationOverlayState
    extends State<DrowsinessCalibrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.secondsRemaining / 15.0;

    return Material(
      color: Colors.black.withValues(alpha: 0.90),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Calibrating Your Eyes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Look forward and keep your eyes naturally open',
                style: TextStyle(color: Color(0xFFB5D4F4), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),

            // Countdown ring around face icon
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _CountdownRingPainter(progress: progress),
                  ),
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, child) => Transform.scale(
                      scale: 1.0 + _pulseCtrl.value * 0.06,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56CC).withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2979FF),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.face_rounded,
                          color: Color(0xFF2979FF),
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.secondsRemaining}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Sit normally, face the camera, and avoid looking away',
                style: TextStyle(color: Color(0xFF8899AA), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),

            TextButton(
              onPressed: widget.onCancel,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8899AA), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  const _CountdownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1A2A40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = const Color(0xFF2979FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.progress != progress;
}
