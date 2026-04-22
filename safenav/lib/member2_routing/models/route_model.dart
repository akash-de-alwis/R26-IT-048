// Typed wrappers for the /route/safety API response — Member 2 (IT22054722).

class RouteOption {
  final int routeId;
  final String label;
  final double riskScore;
  final String riskLevel;
  final int hotspotCount;
  final String recommendationBadge;
  final int durationMin;
  final double totalDistanceKm;

  const RouteOption({
    required this.routeId,
    required this.label,
    required this.riskScore,
    required this.riskLevel,
    required this.hotspotCount,
    required this.recommendationBadge,
    required this.durationMin,
    required this.totalDistanceKm,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        routeId: json['route_id'] as int,
        label: json['label'] as String,
        riskScore: (json['risk_score'] as num).toDouble(),
        riskLevel: json['risk_level'] as String,
        hotspotCount: json['hotspot_count'] as int,
        recommendationBadge: json['recommendation_badge'] as String? ?? '',
        durationMin: json['duration_min'] as int,
        totalDistanceKm: (json['total_distance_km'] as num).toDouble(),
      );
}

class RouteResult {
  final List<RouteOption> routes;
  final String algorithmUsed;
  final String analysisNote;

  const RouteResult({
    required this.routes,
    required this.algorithmUsed,
    required this.analysisNote,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) => RouteResult(
        routes: (json['routes'] as List<dynamic>)
            .map((r) => RouteOption.fromJson(r as Map<String, dynamic>))
            .toList(),
        algorithmUsed: json['algorithm_used'] as String,
        analysisNote: json['analysis_note'] as String,
      );
}
