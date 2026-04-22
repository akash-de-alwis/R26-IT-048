/// Typed wrapper for a single alert dict returned by /alerts/nearby — Member 3 (IT22081452).
class AlertData {
  final int hotspotId;
  final String severity;
  final String messageEn;
  final String messageSi;
  final String explanation;
  final String topCause;
  final double riskScore;
  final double distanceM;
  final String roadName;
  final bool shouldSpeak;
  final String alertColor;

  const AlertData({
    required this.hotspotId,
    required this.severity,
    required this.messageEn,
    required this.messageSi,
    required this.explanation,
    required this.topCause,
    required this.riskScore,
    required this.distanceM,
    required this.roadName,
    required this.shouldSpeak,
    required this.alertColor,
  });

  factory AlertData.fromJson(Map<String, dynamic> json) => AlertData(
        hotspotId: json['hotspot_id'] as int,
        severity: json['severity'] as String,
        messageEn: json['message_en'] as String,
        messageSi: json['message_si'] as String,
        explanation: json['explanation'] as String,
        topCause: json['top_cause'] as String,
        riskScore: (json['risk_score'] as num).toDouble(),
        distanceM: (json['distance_m'] as num).toDouble(),
        roadName: json['road_name'] as String? ?? '',
        shouldSpeak: json['should_speak'] as bool? ?? false,
        alertColor: json['alert_color'] as String? ?? '#2979FF',
      );

  Map<String, dynamic> toJson() => {
        'hotspot_id': hotspotId,
        'severity': severity,
        'message_en': messageEn,
        'message_si': messageSi,
        'explanation': explanation,
        'top_cause': topCause,
        'risk_score': riskScore,
        'distance_m': distanceM,
        'road_name': roadName,
        'should_speak': shouldSpeak,
        'alert_color': alertColor,
      };
}
