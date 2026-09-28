import 'dart:ui' show Rect;
import 'proximity_tier.dart';

/// One tracked object from the rear camera.
class SensedObject {
  final int trackId;
  final String label; // COCO label
  final String group; // from the profile, or 'obstacle'
  final double score;
  final Rect boxNorm; // 0..1 in the upright (portrait) frame
  final double? distanceM; // smoothed, null for generic obstacles
  final double? ttcSeconds; // time to collision if closing
  final bool inPath; // box centre x between 0.2 and 0.8
  final bool vulnerable;
  ProximityTier tier; // filled in later by the orchestrator

  SensedObject({
    required this.trackId,
    required this.label,
    required this.group,
    required this.score,
    required this.boxNorm,
    required this.inPath,
    required this.vulnerable,
    this.distanceM,
    this.ttcSeconds,
    this.tier = ProximityTier.none,
  });

  double get areaFraction => boxNorm.width * boxNorm.height;

  @override
  String toString() => 'SensedObject(#$trackId $label '
      '${distanceM?.toStringAsFixed(1) ?? '-'} m, ttc '
      '${ttcSeconds?.toStringAsFixed(1) ?? '-'} s, inPath: $inPath, $tier)';
}
