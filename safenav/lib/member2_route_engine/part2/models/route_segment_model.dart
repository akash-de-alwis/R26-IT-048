class RouteSegment {
  final List<List<double>> geometry; // [[lng, lat], ...]
  final String congestion;
  final double distanceM;
  final String colorHex;

  const RouteSegment({
    required this.geometry,
    required this.congestion,
    required this.distanceM,
    required this.colorHex,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
        geometry: (json['geometry'] as List<dynamic>)
            .map((p) => (p as List<dynamic>)
                .map((v) => (v as num).toDouble())
                .toList())
            .toList(),
        congestion: json['congestion'] as String,
        distanceM: (json['distance_m'] as num).toDouble(),
        colorHex: json['color'] as String,
      );
}
