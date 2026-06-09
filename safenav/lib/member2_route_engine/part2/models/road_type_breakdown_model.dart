import 'package:flutter/material.dart';

class RoadTypeBreakdown {
  final String roadClass;
  final double distanceM;
  final double pctOfRoute;
  final double riskMultiplier;

  const RoadTypeBreakdown({
    required this.roadClass,
    required this.distanceM,
    required this.pctOfRoute,
    required this.riskMultiplier,
  });

  factory RoadTypeBreakdown.fromJson(Map<String, dynamic> json) =>
      RoadTypeBreakdown(
        roadClass: json['road_class'] as String,
        distanceM: (json['distance_m'] as num).toDouble(),
        pctOfRoute: (json['pct_of_route'] as num).toDouble(),
        riskMultiplier: (json['risk_multiplier'] as num).toDouble(),
      );

  static const Map<String, String> labels = {
    'motorway': 'Highway',
    'trunk': 'Trunk Road',
    'primary': 'Main Road',
    'secondary': 'Secondary Road',
    'tertiary': 'Local Arterial',
    'residential': 'Residential',
    'service': 'Service Road',
    'unclassified': 'Unclassified',
  };

  static const Map<String, IconData> icons = {
    'motorway': Icons.alt_route_rounded,
    'trunk': Icons.timeline_rounded,
    'primary': Icons.linear_scale_rounded,
    'secondary': Icons.linear_scale_rounded,
    'tertiary': Icons.share_rounded,
    'residential': Icons.home_work_rounded,
    'service': Icons.local_parking_rounded,
    'unclassified': Icons.help_outline_rounded,
  };

  static const Map<String, Color> colors = {
    'motorway': Color(0xFF2979FF),
    'trunk': Color(0xFF5C9AFF),
    'primary': Color(0xFF00C06A),
    'secondary': Color(0xFFFFB300),
    'tertiary': Color(0xFFFF8C42),
    'residential': Color(0xFFFF3B5C),
    'service': Color(0xFFFF3B5C),
    'unclassified': Color(0xFF5C6B7A),
  };
}
