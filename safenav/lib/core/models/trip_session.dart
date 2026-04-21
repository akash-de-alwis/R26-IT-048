import 'package:flutter/material.dart';
import 'driving_event.dart';

class TripSession {
  final String tripId;
  final DateTime startTime;
  DateTime? endTime;
  final List<DrivingEvent> events;
  int safetyScore;
  double totalDistanceKm;
  double maxSpeedKmh;
  String? destinationName;

  TripSession({
    required this.tripId,
    required this.startTime,
    this.endTime,
    List<DrivingEvent>? events,
    this.safetyScore = 100,
    this.totalDistanceKm = 0.0,
    this.maxSpeedKmh = 0.0,
    this.destinationName,
  }) : events = events ?? [];

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
        'safetyScore': safetyScore,
        'totalDistanceKm': totalDistanceKm,
        'maxSpeedKmh': maxSpeedKmh,
        'destinationName': destinationName,
      };

  factory TripSession.fromJson(Map<String, dynamic> json) => TripSession(
        tripId: json['tripId'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        events: (json['events'] as List<dynamic>)
            .map((e) => DrivingEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        safetyScore: json['safetyScore'] as int,
        totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
        maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
        destinationName: json['destinationName'] as String?,
      );

  int get harshBrakingCount =>
      events.where((e) => e.type == DrivingEventType.harshBraking).length;

  int get sharpTurnCount =>
      events.where((e) => e.type == DrivingEventType.sharpTurn).length;

  int get overSpeedingCount =>
      events.where((e) => e.type == DrivingEventType.overSpeeding).length;

  int get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  String get scoreLabel {
    if (safetyScore >= 85) return 'Excellent Driver';
    if (safetyScore >= 70) return 'Good Driver';
    if (safetyScore >= 50) return 'Needs Improvement';
    return 'Unsafe Driving';
  }

  Color get scoreColor {
    if (safetyScore >= 85) return const Color(0xFF00C06A);
    if (safetyScore >= 70) return const Color(0xFF2979FF);
    if (safetyScore >= 50) return const Color(0xFFFFB300);
    return const Color(0xFFFF3B5C);
  }
}
