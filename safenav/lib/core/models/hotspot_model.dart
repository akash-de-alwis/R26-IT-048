import 'package:flutter/material.dart';

class HotspotModel {
  final int hotspotId;
  final double latitude;
  final double longitude;
  final double riskScore;
  final String riskLevel;
  final int accidentCount;
  final int highSevPct;
  final int nightPct;
  final List<String> topCauses;
  final String peakPeriod;
  final String roadName;

  const HotspotModel({
    required this.hotspotId,
    required this.latitude,
    required this.longitude,
    required this.riskScore,
    required this.riskLevel,
    required this.accidentCount,
    required this.highSevPct,
    required this.nightPct,
    required this.topCauses,
    required this.peakPeriod,
    required this.roadName,
  });

  factory HotspotModel.fromJson(Map<String, dynamic> json) {
    return HotspotModel(
      hotspotId: (json['hotspot_id'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level'] as String? ?? 'LOW',
      accidentCount: (json['accident_count'] as num?)?.toInt() ?? 0,
      highSevPct: (json['high_sev_pct'] as num?)?.toInt() ?? 0,
      nightPct: (json['night_pct'] as num?)?.toInt() ?? 0,
      topCauses: (json['top_causes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      peakPeriod: json['peak_period'] as String? ?? '',
      roadName: json['road_name'] as String? ?? '',
    );
  }

  Color get markerColor {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFFF3B5C);
      case 'MEDIUM':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF00C06A);
    }
  }

  double get markerSize {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return 18.0;
      case 'MEDIUM':
        return 14.0;
      default:
        return 11.0;
    }
  }
}
