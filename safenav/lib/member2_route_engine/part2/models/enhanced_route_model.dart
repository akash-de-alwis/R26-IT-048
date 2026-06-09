import 'package:flutter/material.dart';
import 'route_segment_model.dart';
import 'traffic_summary_model.dart';
import 'road_type_breakdown_model.dart';

class EnhancedRouteModel {
  final String routeType;
  final List<List<double>> geometry;
  final List<RouteSegment> segments;
  final double distanceM;
  final double durationSeconds;
  final double durationInTrafficSeconds;
  final double safetyScore;
  final double riskScore;
  final int hotspotsOnRoute;
  final TrafficSummary traffic;
  final List<RoadTypeBreakdown> roadTypeBreakdown;
  final String primaryRoadClass;
  final Color color;
  final String label;
  final String badge;
  final String summary;

  const EnhancedRouteModel({
    required this.routeType,
    required this.geometry,
    required this.segments,
    required this.distanceM,
    required this.durationSeconds,
    required this.durationInTrafficSeconds,
    required this.safetyScore,
    required this.riskScore,
    required this.hotspotsOnRoute,
    required this.traffic,
    required this.roadTypeBreakdown,
    required this.primaryRoadClass,
    required this.color,
    required this.label,
    required this.badge,
    required this.summary,
  });

  factory EnhancedRouteModel.fromJson(Map<String, dynamic> json) {
    final colorHex = (json['color'] as String).replaceAll('#', '0xFF');
    return EnhancedRouteModel(
      routeType: json['route_type'] as String,
      geometry: (json['geometry'] as List<dynamic>)
          .map((p) => (p as List<dynamic>)
              .map((v) => (v as num).toDouble())
              .toList())
          .toList(),
      segments: (json['segments'] as List<dynamic>)
          .map((s) => RouteSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      distanceM: (json['distance_m'] as num).toDouble(),
      durationSeconds: (json['duration_seconds'] as num).toDouble(),
      durationInTrafficSeconds:
          (json['duration_in_traffic_seconds'] as num).toDouble(),
      safetyScore: (json['safety_score'] as num).toDouble(),
      riskScore: (json['risk_score'] as num).toDouble(),
      hotspotsOnRoute: json['hotspots_on_route'] as int,
      traffic:
          TrafficSummary.fromJson(json['traffic'] as Map<String, dynamic>),
      roadTypeBreakdown: (json['road_type_breakdown'] as List<dynamic>)
          .map((r) =>
              RoadTypeBreakdown.fromJson(r as Map<String, dynamic>))
          .toList(),
      primaryRoadClass: json['primary_road_class'] as String,
      color: Color(int.parse(colorHex)),
      label: json['label'] as String,
      badge: json['badge'] as String,
      summary: json['summary'] as String,
    );
  }

  String get durationDisplay {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  String get distanceDisplay =>
      '${(distanceM / 1000).toStringAsFixed(1)} km';

  int get delayMinutes =>
      ((durationInTrafficSeconds - durationSeconds) / 60).round();
}
