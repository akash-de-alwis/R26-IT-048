import 'package:flutter/material.dart';
import '../models/trip_session.dart';
import '../../core/theme/app_colors.dart';

class BehaviorAlertsWidget extends StatelessWidget {
  final TripSession trip;
  const BehaviorAlertsWidget({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final alerts = <({Color color, IconData icon, String title, String body})>[];

    if (trip.overSpeedingCount >= 1) {
      alerts.add((
        color: const Color(0xFFFF3B5C),
        icon: Icons.speed,
        title: 'Overspeeding',
        body:
            '${trip.overSpeedingCount} event${trip.overSpeedingCount > 1 ? "s" : ""} recorded this trip. Reduce your speed immediately.',
      ));
    }

    if (trip.harshBrakingCount >= 3) {
      alerts.add((
        color: const Color(0xFFFF3B5C),
        icon: Icons.warning_amber_rounded,
        title: 'Repeated harsh braking',
        body:
            '${trip.harshBrakingCount} sudden stops detected. Increase following distance to avoid this.',
      ));
    } else if (trip.harshBrakingCount > 0)
      alerts.add((
        color: const Color(0xFFFFB300),
        icon: Icons.warning_amber_rounded,
        title: 'Harsh braking detected',
        body: 'Brake gradually — sudden stops increase rear-collision risk.',
      ));

    if (trip.sharpTurnCount >= 2) {
      alerts.add((
        color: const Color(0xFFFFB300),
        icon: Icons.turn_right,
        title: 'Multiple sharp turns',
        body:
            '${trip.sharpTurnCount} sharp turns recorded. Slow down before corners and roundabouts.',
      ));
    }

    if (trip.safetyScore < 50) {
      alerts.add((
        color: const Color(0xFFFF3B5C),
        icon: Icons.shield_outlined,
        title: 'Safety score critical',
        body:
            'Score dropped to ${trip.safetyScore}/100. Avoid sudden maneuvers and reduce speed.',
      ));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: alerts
          .take(2)
          .map((a) => _BehaviorAlertCard(
                color: a.color,
                icon: a.icon,
                title: a.title,
                body: a.body,
              ))
          .toList(),
    );
  }
}

class _BehaviorAlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  const _BehaviorAlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
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
