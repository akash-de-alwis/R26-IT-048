import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Model representing a detected driving event used by the scoring system
// and UI. Each instance contains the event category, when it occurred,
// how severe it was, where it happened, and the score penalty applied.

// Types of driving events that the app recognizes for scoring.
enum DrivingEventType {
  harshBraking,
  harshAcceleration,
  sharpTurn,
  overSpeeding,
  smoothDriving,
}

// A single driving event instance with metadata used for display
// and to compute scoring/penalties.
class DrivingEvent {
  // Category of the event (braking, turn, speeding, etc.).
  final DrivingEventType type;

  // When the event was detected.
  final DateTime timestamp;

  // Numeric measure of severity: for accelerometer events this is in g,
  // for speed events it may represent km/h.
  final double magnitude;

  // Latitude and longitude where the event occurred.
  final double latitude;

  final double longitude;

  // Points deducted from the user's score for this event (if any).
  final int pointsDeducted;

  const DrivingEvent({
    required this.type,
    required this.timestamp,
    required this.magnitude,
    required this.latitude,
    required this.longitude,
    required this.pointsDeducted,
  });

  String get label {
    switch (type) {
      case DrivingEventType.harshBraking:
        return 'Harsh Braking';
      case DrivingEventType.harshAcceleration:
        return 'Harsh Acceleration';
      case DrivingEventType.sharpTurn:
        return 'Sharp Turn';
      case DrivingEventType.overSpeeding:
        return 'Overspeeding';
      case DrivingEventType.smoothDriving:
        return 'Smooth Driving';
    }
  }

  String get description {
    switch (type) {
      case DrivingEventType.harshBraking:
        // Human-friendly message describing the event and magnitude.
        return 'Sudden brake detected (${magnitude.toStringAsFixed(2)}g)';
      case DrivingEventType.harshAcceleration:
        return 'Rapid acceleration (${magnitude.toStringAsFixed(2)}g)';
      case DrivingEventType.sharpTurn:
        return 'Sharp turn detected (${magnitude.toStringAsFixed(2)}g)';
      case DrivingEventType.overSpeeding:
        return 'Speed exceeded limit (${magnitude.toStringAsFixed(0)} km/h)';
      case DrivingEventType.smoothDriving:
        return 'Smooth driving stretch — well done!';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'just now';
    // Simplified relative time for display in lists.
    return '${diff.inMinutes} min ago';
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'magnitude': magnitude,
        'latitude': latitude,
        'longitude': longitude,
        'pointsDeducted': pointsDeducted,
      };

  factory DrivingEvent.fromJson(Map<String, dynamic> json) => DrivingEvent(
        type: DrivingEventType.values.firstWhere(
            (e) => e.name == (json['type'] as String)),
        timestamp: DateTime.parse(json['timestamp'] as String),
        magnitude: (json['magnitude'] as num).toDouble(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        pointsDeducted: json['pointsDeducted'] as int,
      );

  Color get eventColor {
    switch (type) {
      case DrivingEventType.harshBraking:
        // Color used by the UI to indicate severity.
        return AppColors.danger;
      case DrivingEventType.harshAcceleration:
        return AppColors.danger;
      case DrivingEventType.sharpTurn:
        return AppColors.warning;
      case DrivingEventType.overSpeeding:
        return AppColors.danger;
      case DrivingEventType.smoothDriving:
        return AppColors.success;
    }
  }

  IconData get eventIcon {
    switch (type) {
      case DrivingEventType.harshBraking:
        // Icon displayed alongside the event in lists/cards.
        return Icons.front_hand_rounded;
      case DrivingEventType.harshAcceleration:
        return Icons.bolt_rounded;
      case DrivingEventType.sharpTurn:
        return Icons.turn_right_rounded;
      case DrivingEventType.overSpeeding:
        return Icons.speed_rounded;
      case DrivingEventType.smoothDriving:
        return Icons.check_circle_rounded;
    }
  }
}
