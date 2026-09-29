import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../member4_driver_scoring/part1/services/sensor_service.dart';
import '../../../member1_risk_prediction/part2/services/realtime_risk_service.dart';
import '../../../member1_risk_prediction/part2/widgets/risk_color_scale.dart';
import '../../../features/member1b_realtime_pipeline/services/realtime_pipeline_service.dart';

/// Single dark bar shown during an active trip: live dot, label, elapsed
/// time, speed and one risk score badge. The badge shows the member1b
/// stream score when the pipeline is connected, otherwise the polled
/// Member 1 score. Long-press on the badge fires [onBadgeLongPress].
class TripStatusBar extends StatefulWidget {
  final VoidCallback? onBadgeLongPress;

  const TripStatusBar({super.key, this.onBadgeLongPress});

  /// Matches the height of the previous "Trip in Progress" banner.
  static const double height = 42;

  @override
  State<TripStatusBar> createState() => _TripStatusBarState();
}

class _TripStatusBarState extends State<TripStatusBar>
    with SingleTickerProviderStateMixin {
  static const _liveGreen = Color(0xFF00E08A);

  late final AnimationController _pulseCtrl;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final start = context.read<SensorService>().currentTrip?.startTime;
    if (start != null) {
      _elapsedSeconds = DateTime.now().difference(start).inSeconds;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final speed = context.select<SensorService, double>(
        (s) => s.currentSpeedKmh);

    return RepaintBoundary(
      child: Container(
        height: TripStatusBar.height,
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0D1117).withValues(alpha: 0.95),
              const Color(0xFF1A2234).withValues(alpha: 0.90),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(TripStatusBar.height / 2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFF00C06A),
                    _liveGreen,
                    _pulseCtrl.value,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _liveGreen
                          .withValues(alpha: 0.25 + 0.35 * _pulseCtrl.value),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Trip in progress',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _fmt(_elapsedSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Container(
              width: 1,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.white.withValues(alpha: 0.18),
            ),
            Text(
              '${speed.toStringAsFixed(0)} km/h',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            _RiskScoreBadge(
              pulse: _pulseCtrl,
              onLongPress: widget.onBadgeLongPress,
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskScoreBadge extends StatelessWidget {
  final Animation<double> pulse;
  final VoidCallback? onLongPress;

  const _RiskScoreBadge({required this.pulse, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final pipeline = context.watch<RealtimePipelineService>();
    final polled = context.watch<RealtimeRiskService>().currentRisk;

    final streamUpdate = pipeline.latestUpdate;
    final isLive = pipeline.isConnected && streamUpdate != null;
    final double? score = isLive ? streamUpdate.riskScore : polled?.riskScore;

    final background = score == null
        ? Colors.white.withValues(alpha: 0.14)
        : paletteForScore(score).top;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1.0).animate(pulse),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                score?.toStringAsFixed(0) ?? '--',
                key: ValueKey<String>(score?.toStringAsFixed(0) ?? '--'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
