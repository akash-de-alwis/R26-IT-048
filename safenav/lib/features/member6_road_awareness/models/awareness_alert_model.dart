import 'package:flutter/material.dart';
import 'proximity_tier.dart';

enum AlertSource { camera, route }

/// The single alert shown in the awareness banner.
class AwarenessAlert {
  final AlertSource source;
  final String title; // e.g. "Pedestrian" or "Sharp bend ahead"
  final String? subtitle; // e.g. "3.2 m" or "120 m ahead"
  final ProximityTier tier;
  final IconData icon;
  final DateTime at;

  /// Route alerts show the backend severity (CAUTION / WARNING / CRITICAL)
  /// in the chip; camera alerts show the tier label.
  final String? severityLabel;

  /// Identifies the underlying object (camera track id or obstacle id) so
  /// the banner can animate only when the alert really changes.
  final String key;

  const AwarenessAlert({
    required this.source,
    required this.title,
    required this.tier,
    required this.icon,
    required this.at,
    required this.key,
    this.subtitle,
    this.severityLabel,
  });

  String get chipLabel => severityLabel ?? tier.label;

  /// Route severity -> tier: CAUTION=closer, WARNING=veryClose,
  /// CRITICAL=critical.
  static ProximityTier tierForRouteSeverity(String severity) =>
      switch (severity) {
        'CRITICAL' => ProximityTier.critical,
        'WARNING' => ProximityTier.veryClose,
        'CAUTION' => ProximityTier.closer,
        _ => ProximityTier.far,
      };

  /// Icon for a camera object's profile group.
  static IconData iconForGroup(String group) => switch (group) {
        'person' => Icons.directions_walk_rounded,
        'cyclist' => Icons.pedal_bike_rounded,
        'motorcycle' => Icons.two_wheeler_rounded,
        'vehicle' => Icons.directions_car_rounded,
        'bus' || 'truck' => Icons.local_shipping_rounded,
        'animal' => Icons.pets_rounded,
        _ => Icons.warning_amber_rounded,
      };
}
