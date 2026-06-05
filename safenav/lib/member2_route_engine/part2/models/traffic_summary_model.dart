import 'package:flutter/material.dart';

class TrafficSummary {
  final String overallLevel;
  final double lowPct;
  final double moderatePct;
  final double heavyPct;
  final double severePct;

  const TrafficSummary({
    required this.overallLevel,
    required this.lowPct,
    required this.moderatePct,
    required this.heavyPct,
    required this.severePct,
  });

  factory TrafficSummary.fromJson(Map<String, dynamic> json) => TrafficSummary(
        overallLevel: json['overall_level'] as String,
        lowPct: (json['low_pct'] as num).toDouble(),
        moderatePct: (json['moderate_pct'] as num).toDouble(),
        heavyPct: (json['heavy_pct'] as num).toDouble(),
        severePct: (json['severe_pct'] as num).toDouble(),
      );

  Color get overallColor {
    switch (overallLevel) {
      case 'low':
        return const Color(0xFF00C06A);
      case 'moderate':
        return const Color(0xFFFFB300);
      case 'heavy':
        return const Color(0xFFFF8C42);
      case 'severe':
        return const Color(0xFFFF3B5C);
      default:
        return const Color(0xFF5C6B7A);
    }
  }

  String get displayLabel {
    switch (overallLevel) {
      case 'low':
        return 'Clear';
      case 'moderate':
        return 'Slow';
      case 'heavy':
        return 'Heavy';
      case 'severe':
        return 'Severe';
      default:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (overallLevel) {
      case 'low':
        return Icons.check_circle_rounded;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'heavy':
        return Icons.traffic_rounded;
      case 'severe':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
