import 'dart:math' as math;

/// Result of splitting a route at the driver's position.
class RouteSplitResult {
  /// [[lng, lat], ...] from the route start to the projected position.
  /// Empty when progress is 0.
  final List<List<double>> travelled;

  /// [[lng, lat], ...] from the projected position to the route end.
  /// The full route when progress is 0, empty when progress is 1.
  final List<List<double>> remaining;

  /// Travelled length / total length, 0..1.
  final double progressFraction;

  const RouteSplitResult({
    required this.travelled,
    required this.remaining,
    required this.progressFraction,
  });
}

const double _earthRadiusM = 6371000.0;

/// Great-circle distance in metres.
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Total length in metres of a [[lng, lat], ...] polyline.
double polylineLengthM(List<List<double>> geometry) {
  double total = 0;
  for (int i = 1; i < geometry.length; i++) {
    total += haversineM(
        geometry[i - 1][1], geometry[i - 1][0], geometry[i][1], geometry[i][0]);
  }
  return total;
}

bool _samePoint(List<double> a, List<double> b) => a[0] == b[0] && a[1] == b[1];

/// Splits [geometry] ([[lng, lat], ...]) at the point on the line nearest to
/// ([lat], [lng]). The position is projected onto every segment in a local
/// equirectangular plane (accurate at street scale) and the closest
/// projection wins.
RouteSplitResult splitAtNearestPoint(
    List<List<double>> geometry, double lat, double lng) {
  if (geometry.length < 2) {
    return RouteSplitResult(
        travelled: const [], remaining: List.of(geometry), progressFraction: 0);
  }

  final cosLat = math.cos(lat * math.pi / 180.0);
  int bestIdx = 0;
  double bestT = 0;
  double bestD2 = double.infinity;

  for (int i = 0; i < geometry.length - 1; i++) {
    final ax = (geometry[i][0] - lng) * cosLat;
    final ay = geometry[i][1] - lat;
    final dx = (geometry[i + 1][0] - geometry[i][0]) * cosLat;
    final dy = geometry[i + 1][1] - geometry[i][1];
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
    final px = ax + t * dx;
    final py = ay + t * dy;
    final d2 = px * px + py * py;
    if (d2 < bestD2) {
      bestD2 = d2;
      bestIdx = i;
      bestT = t;
    }
  }

  final a = geometry[bestIdx];
  final b = geometry[bestIdx + 1];
  final proj = [a[0] + bestT * (b[0] - a[0]), a[1] + bestT * (b[1] - a[1])];

  final travelled = <List<double>>[...geometry.sublist(0, bestIdx + 1)];
  if (!_samePoint(travelled.last, proj)) travelled.add(proj);

  final rest = geometry.sublist(bestIdx + 1);
  final remaining = <List<double>>[proj];
  for (final p in rest) {
    if (!_samePoint(remaining.last, p)) remaining.add(p);
  }

  final total = polylineLengthM(geometry);
  final travelledLen = polylineLengthM(travelled);
  final fraction = total <= 0 ? 0.0 : (travelledLen / total).clamp(0.0, 1.0);

  if (travelledLen <= 0) {
    return RouteSplitResult(
        travelled: const [], remaining: List.of(geometry), progressFraction: 0);
  }
  if (remaining.length < 2) {
    return RouteSplitResult(
        travelled: List.of(geometry), remaining: const [], progressFraction: 1);
  }
  return RouteSplitResult(
      travelled: travelled, remaining: remaining, progressFraction: fraction);
}
