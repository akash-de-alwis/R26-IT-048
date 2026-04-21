import 'package:flutter/material.dart';
import '../../../core/models/driving_event.dart';
import '../../../core/theme/app_colors.dart';

enum TripEventType {
  harshBraking,
  harshAcceleration,
  sharpTurn,
  smoothDriving,
  accident,
}

class TripEventCard extends StatelessWidget {
  final TripEventType eventType;
  final String time;
  final String location;

  /// Negative = point deduction (shown red), zero or positive = green
  final int points;

  const TripEventCard({
    super.key,
    required this.eventType,
    required this.time,
    required this.location,
    required this.points,
  });

  factory TripEventCard.fromDrivingEvent(DrivingEvent event) {
    final type = switch (event.type) {
      DrivingEventType.harshBraking      => TripEventType.harshBraking,
      DrivingEventType.harshAcceleration => TripEventType.harshAcceleration,
      DrivingEventType.sharpTurn         => TripEventType.sharpTurn,
      DrivingEventType.overSpeeding      => TripEventType.smoothDriving,
      DrivingEventType.smoothDriving     => TripEventType.smoothDriving,
    };
    return TripEventCard(
      eventType: type,
      time: event.timeAgo,
      location: event.description,
      points: event.pointsDeducted,
    );
  }

  String get _eventName => switch (eventType) {
        TripEventType.harshBraking => 'Harsh Braking',
        TripEventType.harshAcceleration => 'Harsh Acceleration',
        TripEventType.sharpTurn => 'Sharp Turn',
        TripEventType.smoothDriving => 'Smooth Driving',
        TripEventType.accident => 'Accident Detected',
      };

  (IconData, Color) get _iconProps => switch (eventType) {
        TripEventType.harshBraking => (Icons.pan_tool_outlined, AppColors.danger),
        TripEventType.harshAcceleration => (Icons.speed, AppColors.danger),
        TripEventType.sharpTurn => (Icons.turn_sharp_right, AppColors.warning),
        TripEventType.smoothDriving =>
          (Icons.check_circle_outline, AppColors.success),
        TripEventType.accident => (Icons.car_crash_outlined, AppColors.danger),
      };

  String get _pointsLabel {
    if (points > 0) return '+$points pts';
    if (points == 0) return '+0 pts';
    return '$points pts';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _iconProps;
    final isDeduction = points < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8EDF2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Colored icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),

          // Event name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$time · $location',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Points change
          Text(
            _pointsLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDeduction ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
