class ObstacleAlertText {
  final String shortEn;
  final String shortSi;
  final String voiceEn;
  final String voiceSi;

  const ObstacleAlertText({
    required this.shortEn,
    required this.shortSi,
    required this.voiceEn,
    required this.voiceSi,
  });

  factory ObstacleAlertText.fromJson(Map<String, dynamic> j) =>
      ObstacleAlertText(
        shortEn: j['short_en'] as String,
        shortSi: j['short_si'] as String,
        voiceEn: j['voice_en'] as String,
        voiceSi: j['voice_si'] as String,
      );
}
