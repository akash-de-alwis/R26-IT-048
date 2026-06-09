import 'package:flutter/material.dart';
import 'obstacle_alert_text_model.dart';

class ObstacleModel {
  final String id;
  final String obstacleType;
  final String severity;
  final double latitude;
  final double longitude;
  final double distanceFromRouteM;
  final String iconName;
  final String colorHex;
  final double? metricValue;
  final String? metricUnit;
  final String descriptionEn;
  final String descriptionSi;
  final ObstacleAlertText alert;

  const ObstacleModel({
    required this.id,
    required this.obstacleType,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.distanceFromRouteM,
    required this.iconName,
    required this.colorHex,
    this.metricValue,
    this.metricUnit,
    required this.descriptionEn,
    required this.descriptionSi,
    required this.alert,
  });

  factory ObstacleModel.fromJson(Map<String, dynamic> j) => ObstacleModel(
        id: j['id'] as String,
        obstacleType: j['obstacle_type'] as String,
        severity: j['severity'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        distanceFromRouteM: (j['distance_from_route_m'] as num).toDouble(),
        iconName: j['icon_name'] as String,
        colorHex: j['color'] as String,
        metricValue: j['metric_value'] != null
            ? (j['metric_value'] as num).toDouble()
            : null,
        metricUnit: j['metric_unit'] as String?,
        descriptionEn: j['description_en'] as String,
        descriptionSi: j['description_si'] as String,
        alert: ObstacleAlertText.fromJson(
            j['alert'] as Map<String, dynamic>),
      );

  Color get severityColor {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData get materialIcon => switch (iconName) {
        'turn_sharp_right' => Icons.turn_sharp_right,
        'trending_up' => Icons.trending_up,
        'compress' => Icons.compress,
        'share' => Icons.share_rounded,
        'horizontal_rule' => Icons.horizontal_rule_rounded,
        'block' => Icons.block_rounded,
        'directions_walk' => Icons.directions_walk_rounded,
        'flag' => Icons.flag_rounded,
        _ => Icons.warning_amber_rounded,
      };
}
