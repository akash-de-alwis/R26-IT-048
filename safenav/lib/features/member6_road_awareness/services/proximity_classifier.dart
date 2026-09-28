import 'dart:math' as math;
import '../models/proximity_tier.dart';

/// Proximity tier for an object at [distanceM].
///
/// Below 10 km/h (parking, crawling) absolute distances are used; while
/// driving the distance is compared to the safe following gap for
/// [followingTimeS] seconds. A short time-to-collision escalates the tier,
/// and objects beside the path count one tier lower.
ProximityTier classifyProximity({
  required double distanceM,
  required double speedKmh,
  required double followingTimeS, // 2, 3 or 4 from the following rule
  required bool inPath,
  double? ttcSeconds,
}) {
  ProximityTier t;
  if (speedKmh < 10) {
    // parking or crawling: absolute distances
    t = distanceM < 1.5
        ? ProximityTier.critical
        : distanceM < 3.0
            ? ProximityTier.veryClose
            : distanceM < 5.0
                ? ProximityTier.closer
                : distanceM < 8.0
                    ? ProximityTier.far
                    : ProximityTier.none;
  } else {
    // driving: relative to the safe following gap
    final safe = math.max(speedKmh / 3.6 * followingTimeS, 6.0);
    final r = distanceM / safe;
    t = r < 0.45
        ? ProximityTier.critical
        : r < 0.80
            ? ProximityTier.veryClose
            : r < 1.30
                ? ProximityTier.closer
                : r < 2.00
                    ? ProximityTier.far
                    : ProximityTier.none;
  }
  if (ttcSeconds != null) {
    if (ttcSeconds < 2.0) {
      t = ProximityTier.critical;
    } else if (ttcSeconds < 3.5 && t.index < ProximityTier.veryClose.index) {
      t = ProximityTier.veryClose;
    }
  }
  // objects beside the path count one tier lower
  if (!inPath && t != ProximityTier.none) {
    t = ProximityTier.values[t.index - 1];
  }
  return t;
}

/// A large unknown thing directly ahead. Only objects in the path count.
ProximityTier classifyGenericObstacle(double areaFraction, bool inPath) {
  if (!inPath) return ProximityTier.none;
  if (areaFraction >= 0.30) return ProximityTier.critical;
  if (areaFraction >= 0.15) return ProximityTier.veryClose;
  return ProximityTier.none;
}
