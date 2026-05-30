import 'package:flutter/material.dart';
import './weather_snapshot_model.dart';
import './risk_factor_model.dart';

enum RiskLevel { low, moderate, high, critical }

class RealtimeRiskModel {
  final double riskScore;
  final RiskLevel riskLevel;
  final Color riskColor;
  final double baseModelProbability;
  final double speedMultiplier;
  final double weatherMultiplier;
  final double roadConditionMultiplier;
  final double hotspotProximityMultiplier;
  final double? nearestHotspotDistanceM;
  final WeatherSnapshot weather;
  final String roadCondition;
  final List<RiskFactor> contributingFactors;
  final String recommendation;
  final DateTime timestamp;

  RealtimeRiskModel({
    required this.riskScore,
    required this.riskLevel,
    required this.riskColor,
    required this.baseModelProbability,
    required this.speedMultiplier,
    required this.weatherMultiplier,
    required this.roadConditionMultiplier,
    required this.hotspotProximityMultiplier,
    required this.nearestHotspotDistanceM,
    required this.weather,
    required this.roadCondition,
    required this.contributingFactors,
    required this.recommendation,
    required this.timestamp,
  });

  factory RealtimeRiskModel.fromJson(Map<String, dynamic> json) {
    RiskLevel parseLevel(String v) {
      switch (v) {
        case 'CRITICAL':
          return RiskLevel.critical;
        case 'HIGH':
          return RiskLevel.high;
        case 'MODERATE':
          return RiskLevel.moderate;
        default:
          return RiskLevel.low;
      }
    }

    return RealtimeRiskModel(
      riskScore: (json['risk_score'] as num).toDouble(),
      riskLevel: parseLevel(json['risk_level'] as String),
      riskColor: Color(
          int.parse((json['risk_color'] as String).replaceAll('#', '0xFF'))),
      baseModelProbability:
          (json['base_model_probability'] as num).toDouble(),
      speedMultiplier: (json['speed_multiplier'] as num).toDouble(),
      weatherMultiplier: (json['weather_multiplier'] as num).toDouble(),
      roadConditionMultiplier:
          (json['road_condition_multiplier'] as num).toDouble(),
      hotspotProximityMultiplier:
          (json['hotspot_proximity_multiplier'] as num).toDouble(),
      nearestHotspotDistanceM: json['nearest_hotspot_distance_m'] != null
          ? (json['nearest_hotspot_distance_m'] as num).toDouble()
          : null,
      weather: WeatherSnapshot.fromJson(
          json['weather'] as Map<String, dynamic>),
      roadCondition: json['road_condition'] as String,
      contributingFactors: (json['contributing_factors'] as List<dynamic>)
          .map((f) => RiskFactor.fromJson(f as Map<String, dynamic>))
          .toList(),
      recommendation: json['recommendation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String get riskLabel {
    switch (riskLevel) {
      case RiskLevel.critical:
        return 'CRITICAL';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.moderate:
        return 'MODERATE';
      case RiskLevel.low:
        return 'LOW';
    }
  }
}
