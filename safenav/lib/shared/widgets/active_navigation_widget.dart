import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../../member4_driver_scoring/part1/services/sensor_service.dart';

class ActiveNavigationWidget extends StatefulWidget {
  const ActiveNavigationWidget({super.key});

  @override
  State<ActiveNavigationWidget> createState() => _ActiveNavigationWidgetState();
}

class _ActiveNavigationWidgetState extends State<ActiveNavigationWidget> {
  bool _dismissed = false;
  bool _wasTracking = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorService>(
      builder: (ctx, sensor, _) {
        // Re-show automatically when a new trip starts
        if (sensor.isTracking && !_wasTracking) {
          _dismissed = false;
        }
        _wasTracking = sensor.isTracking;

        final visible = sensor.isTracking && !_dismissed;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween(
              begin: const Offset(1.2, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: visible
              ? _NavCard(
                  key: const ValueKey('nav'),
                  sensor: sensor,
                  onClose: () => setState(() => _dismissed = true),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        );
      },
    );
  }
}

class _NavCard extends StatelessWidget {
  final SensorService sensor;
  final VoidCallback onClose;
  const _NavCard({super.key, required this.sensor, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isOver = sensor.currentSpeedKmh > AppConstants.overspeedThresholdKmh;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main card ────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => context.go(AppConstants.routeMap),
          child: SizedBox(
            width: 168,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.13),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFF2979FF).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Mini map ───────────────────────────────────────────
                  SizedBox(
                    height: 108,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(color: const Color(0xFFF0F4FF)),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: _MockMapPainter()),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: _RoutePainter()),
                        ),
                        Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2979FF)
                                      .withValues(alpha: 0.40),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.navigation_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // LIVE badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B5C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Info strip ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sensor.currentTrip?.destinationName ??
                              'Your Destination',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D1B2A),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              '${sensor.currentSpeedKmh.toStringAsFixed(0)} km/h',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isOver
                                    ? const Color(0xFFFF3B5C)
                                    : const Color(0xFF5C6B7A),
                              ),
                            ),
                            if (isOver) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B5C)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Over',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFFFF3B5C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFADB8C3), size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Close button ─────────────────────────────────────────────────
        Positioned(
          top: -9,
          left: -9,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF4A5568),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _MockMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDDE8F5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double y = 25; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 32; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_MockMapPainter old) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.90)
      ..quadraticBezierTo(
        size.width * 0.40,
        size.height * 0.50,
        size.width * 0.85,
        size.height * 0.05,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2979FF).withValues(alpha: 0.15)
        ..strokeWidth = 14.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2979FF)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => false;
}
