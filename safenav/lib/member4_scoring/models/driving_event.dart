import 'package:flutter/material.dart';

enum DrivingEventType {
  harshBraking,
  harshAcceleration,
  sharpTurn,
  overSpeeding,
  smoothDriving,
}

class DrivingEvent {
  final DrivingEventType type;
  final DateTime timestamp;
  final double magnitude;
  final double latitude;
  final double longitude;
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
        return const Color(0xFFFF3B5C);
      case DrivingEventType.harshAcceleration:
        return const Color(0xFFFF3B5C);
      case DrivingEventType.sharpTurn:
        return const Color(0xFFFFB300);
      case DrivingEventType.overSpeeding:
        return const Color(0xFFFF3B5C);
      case DrivingEventType.smoothDriving:
        return const Color(0xFF00C06A);
    }
  }
}
