import 'dart:math' as math;
import 'dart:ui' show Rect;
import '../models/object_profiles.dart';
import 'awareness_preference_service.dart';

/// Monocular distance: distance = realSizeMeters * focalPx / sizeInPixels.
class DistanceCalibrationService {
  /// Assumed horizontal field of view when not calibrated.
  static const defaultHfovDegrees = 55.0;

  final AwarenessPreferenceService prefs;
  DistanceCalibrationService(this.prefs);

  /// Focal length in pixels for a frame [frameWidthPx] wide. A calibrated
  /// value is scaled if it was measured at a different frame width.
  double focalPx(int frameWidthPx) {
    final saved = prefs.focalLengthPx;
    if (saved != null) {
      final calibW = prefs.calibratedFrameWidthPx;
      return (calibW == null || calibW <= 0)
          ? saved
          : saved * frameWidthPx / calibW;
    }
    return (frameWidthPx / 2) /
        math.tan(defaultHfovDegrees / 2 * math.pi / 180);
  }

  /// Estimated distance in metres, or null for labels with no profile.
  double? estimate(String label, Rect boxNorm, int frameW, int frameH) {
    final profile = objectProfiles[label];
    if (profile == null) return null;
    final sizePx = _sizePx(profile, boxNorm, frameW, frameH);
    if (sizePx <= 0) return null;
    return profile.meters * focalPx(frameW) / sizePx;
  }

  /// The user places an object of known size at [knownDistanceM]. Solves
  /// the same formula for the focal length, saves and returns it.
  Future<double> calibrate({
    required String label,
    required double knownDistanceM,
    required Rect boxNorm,
    required int frameW,
    required int frameH,
  }) async {
    final profile = objectProfiles[label];
    if (profile == null) {
      throw ArgumentError('No size profile for "$label"');
    }
    final sizePx = _sizePx(profile, boxNorm, frameW, frameH);
    if (sizePx <= 0 || knownDistanceM <= 0) {
      throw ArgumentError('Box size and distance must be positive');
    }
    final focal = knownDistanceM * sizePx / profile.meters;
    await prefs.setFocalLength(focal, frameW);
    return focal;
  }

  double _sizePx(ObjectProfile p, Rect boxNorm, int frameW, int frameH) =>
      p.dim == Dim.height ? boxNorm.height * frameH : boxNorm.width * frameW;
}
