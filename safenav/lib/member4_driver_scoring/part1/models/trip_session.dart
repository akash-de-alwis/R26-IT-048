import 'package:flutter/material.dart';
import './driving_event.dart';
import '../../../shared/theme/app_colors.dart';

class TripSession {
  final String tripId;
  final DateTime startTime;
  DateTime? endTime;
  final List<DrivingEvent> events;
  int safetyScore;
  double totalDistanceKm;
  double maxSpeedKmh;
  String? destinationName;
  // Represents a single trip session containing detected driving events,
  // summary statistics and a safety score used by the scoring UI and services.

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
    // Duration in minutes between start and end (or now if ongoing).
    return end.difference(startTime).inMinutes;
  }

  String get scoreLabel {
    // Human-readable label for the current safety score band.
    if (safetyScore >= 85) return 'Excellent Driver';
    if (safetyScore >= 70) return 'Good Driver';
    if (safetyScore >= 50) return 'Needs Improvement';
    return 'Unsafe Driving';
  }

  Color get scoreColor {
    // UI color representing the safety score band.
    if (safetyScore >= 85) return AppColors.success;
    if (safetyScore >= 70) return AppColors.primary;
    if (safetyScore >= 50) return AppColors.warning;
    return AppColors.danger;
  }
}
