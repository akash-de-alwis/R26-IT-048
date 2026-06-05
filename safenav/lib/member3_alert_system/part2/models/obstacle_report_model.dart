class ObstacleReportModel {
  final String id;
  final double latitude;
  final double longitude;
  final String obstacleType;
  final String severity;
  final String? userNote;
  final String reportedAt;
  final String expiresAt;

  const ObstacleReportModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.obstacleType,
    required this.severity,
    this.userNote,
    required this.reportedAt,
    required this.expiresAt,
  });

  factory ObstacleReportModel.fromJson(Map<String, dynamic> j) =>
      ObstacleReportModel(
        id: j['id'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        obstacleType: j['obstacle_type'] as String,
        severity: j['severity'] as String,
        userNote: j['user_note'] as String?,
        reportedAt: j['reported_at'] as String,
        expiresAt: j['expires_at'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'obstacle_type': obstacleType,
        'severity': severity,
        'user_note': userNote,
        'reported_at': reportedAt,
        'expires_at': expiresAt,
      };
}
