import 'package:flutter/material.dart';

enum DrowsinessLevel { alert, caution, warning, critical }

class DrowsinessMetrics {
  final double currentEar;
  final double perclosPct;
  final int yawnCount60s;
  final int headNods60s;
  final double drowsinessScore;
  final DrowsinessLevel level;
  final DateTime timestamp;

  DrowsinessMetrics({
    required this.currentEar,
    required this.perclosPct,
    required this.yawnCount60s,
    required this.headNods60s,
    required this.drowsinessScore,
    required this.level,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get levelLabel {
    switch (level) {
      case DrowsinessLevel.critical:
        return 'CRITICAL';
      case DrowsinessLevel.warning:
        return 'WARNING';
      case DrowsinessLevel.caution:
        return 'CAUTION';
      default:
        return 'ALERT';
    }
  }

  Color get levelColor {
    switch (level) {
      case DrowsinessLevel.critical:
        return const Color(0xFFFF3B5C);
      case DrowsinessLevel.warning:
        return const Color(0xFFFF8C42);
      case DrowsinessLevel.caution:
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF00C06A);
    }
  }
}
