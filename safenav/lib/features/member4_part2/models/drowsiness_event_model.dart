class DrowsinessEvent {
  final String id;
  final String tripId;
  final String timestamp;
  final double drowsinessScore;
  final String drowsinessLevel;
  final double perclosPct;
  final double avgEar;
  final double durationSeconds;
  final int yawnCount60s;
  final int headNods60s;

  const DrowsinessEvent({
    required this.id,
    required this.tripId,
    required this.timestamp,
    required this.drowsinessScore,
    required this.drowsinessLevel,
    required this.perclosPct,
    required this.avgEar,
    required this.durationSeconds,
    required this.yawnCount60s,
    required this.headNods60s,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'timestamp': timestamp,
        'drowsiness_score': drowsinessScore,
        'drowsiness_level': drowsinessLevel,
        'perclos_pct': perclosPct,
        'avg_ear': avgEar,
        'duration_seconds': durationSeconds,
        'yawn_count_60s': yawnCount60s,
        'head_nods_60s': headNods60s,
      };

  factory DrowsinessEvent.fromJson(Map<String, dynamic> j) => DrowsinessEvent(
        id: j['id'] as String,
        tripId: j['trip_id'] as String,
        timestamp: j['timestamp'] as String,
        drowsinessScore: (j['drowsiness_score'] as num).toDouble(),
        drowsinessLevel: j['drowsiness_level'] as String,
        perclosPct: (j['perclos_pct'] as num).toDouble(),
        avgEar: (j['avg_ear'] as num).toDouble(),
        durationSeconds: (j['duration_seconds'] as num).toDouble(),
        yawnCount60s: j['yawn_count_60s'] as int,
        headNods60s: j['head_nods_60s'] as int,
      );
}
