import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obstacle_alert_orchestrator.dart';
import '../services/obstacle_preference_service.dart';

class ObstacleAlertBanner extends StatelessWidget {
  const ObstacleAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ObstacleAlertOrchestrator>(
      builder: (ctx, orchestrator, _) {
        final obs = orchestrator.currentAlertObstacle;
        if (obs == null) return const SizedBox.shrink();

        final lang = ctx.watch<ObstaclePreferenceService>().voiceLanguage;
        final text = lang == 'si' ? obs.alert.shortSi : obs.alert.shortEn;

        return AnimatedSlide(
          offset: Offset.zero,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: obs.severityColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: obs.severityColor.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Severity icon circle
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: obs.severityColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: obs.severityColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    obs.materialIcon,
                    size: 22,
                    color: obs.severityColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: obs.severityColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          obs.severity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
