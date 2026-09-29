import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../features/member4_part2/services/drowsiness_preference_service.dart';
import '../../../features/member6_road_awareness/services/awareness_preference_service.dart';

/// Live on/off chips for Road Awareness (Member 6) and Drowsiness
/// detection (Member 4). Rebuilds whenever either preference changes.
/// Tapping a chip opens Profile, where both settings cards live.
class HomeSafetyStatusStrip extends StatelessWidget {
  const HomeSafetyStatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final awarenessOn =
        context.select<AwarenessPreferenceService, bool>((p) => p.masterEnabled);
    final drowsinessOn = context
        .select<DrowsinessPreferenceService, bool>((p) => p.detectionEnabled);
    void openProfile() => context.go(AppConstants.routeProfile);

    return Row(
      children: [
        _StatusChip(
          icon: Icons.sensors_rounded,
          label: 'Road Awareness',
          on: awarenessOn,
          onTap: openProfile,
        ),
        const SizedBox(width: 8),
        _StatusChip(
          icon: Icons.visibility_rounded,
          label: 'Drowsiness',
          on: drowsinessOn,
          onTap: openProfile,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });

  static const _green = Color(0xFF00C06A);
  static const _grey = Color(0xFFADB8C3);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFEBFBF3) : const Color(0xFFEEF1F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: on ? _green : _grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 13, color: on ? _green : const Color(0xFF5C6B7A)),
            const SizedBox(width: 4),
            Text(
              '$label ${on ? 'on' : 'off'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: on ? const Color(0xFF00884B) : const Color(0xFF5C6B7A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
