import 'package:flutter/material.dart';

import '../services/driving_camera_controller.dart';

/// "Re-center" pill shown during a trip once the user has panned away
/// from the driver. Tapping it resumes the driving camera.
class RecenterPill extends StatelessWidget {
  final DrivingCameraController controller;

  const RecenterPill({super.key, required this.controller});

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.isActive && !controller.isFollowing;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: visible
              ? _Pill(key: const ValueKey('pill'), onTap: controller.recenter)
              : const SizedBox.shrink(key: ValueKey('none')),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final VoidCallback onTap;

  const _Pill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: RecenterPill.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RecenterPill.height / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RecenterPill.height / 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation_rounded,
                    size: 18, color: Color(0xFF2979FF)),
                SizedBox(width: 6),
                Text(
                  'Re-center',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
