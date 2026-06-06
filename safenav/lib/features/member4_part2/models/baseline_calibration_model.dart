class BaselineCalibration {
  final double baselineEar;
  final DateTime calibratedAt;

  BaselineCalibration({
    required this.baselineEar,
    required this.calibratedAt,
  });

  bool get isStale =>
      DateTime.now().difference(calibratedAt).inDays > 7;

  Map<String, dynamic> toJson() => {
        'baseline_ear': baselineEar,
        'calibrated_at': calibratedAt.toIso8601String(),
      };

  factory BaselineCalibration.fromJson(Map<String, dynamic> j) =>
      BaselineCalibration(
        baselineEar: (j['baseline_ear'] as num).toDouble(),
        calibratedAt: DateTime.parse(j['calibrated_at'] as String),
      );
}
