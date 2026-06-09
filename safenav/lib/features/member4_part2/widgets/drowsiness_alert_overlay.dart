import 'package:flutter/material.dart';
import '../models/drowsiness_metrics_model.dart';

class DrowsinessAlertOverlay extends StatefulWidget {
  final DrowsinessMetrics metrics;
  final VoidCallback? onDismiss;

  const DrowsinessAlertOverlay({
    super.key,
    required this.metrics,
    this.onDismiss,
  });

  @override
  State<DrowsinessAlertOverlay> createState() =>
      _DrowsinessAlertOverlayState();
}

class _DrowsinessAlertOverlayState extends State<DrowsinessAlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _recommendation {
    return widget.metrics.level == DrowsinessLevel.critical
        ? 'Please pull over safely and rest immediately.'
        : 'Consider stopping for a short break.';
  }

  IconData get _icon {
    return widget.metrics.level == DrowsinessLevel.critical
        ? Icons.warning_rounded
        : Icons.bedtime_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.metrics.levelColor;

    return SlideTransition(
      position: _slideAnim,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Severity icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.metrics.levelLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _recommendation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Drowsiness score circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.metrics.drowsinessScore.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'score',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.70), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
