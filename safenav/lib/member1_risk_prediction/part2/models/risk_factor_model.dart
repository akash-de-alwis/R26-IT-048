class RiskFactor {
  final String name;
  final String value;
  final double multiplier;
  final double contributionPct;

  RiskFactor({
    required this.name,
    required this.value,
    required this.multiplier,
    required this.contributionPct,
  });

  factory RiskFactor.fromJson(Map<String, dynamic> json) => RiskFactor(
        name: json['name'] as String,
        value: json['value'] as String,
        multiplier: (json['multiplier'] as num).toDouble(),
        contributionPct: (json['contribution_pct'] as num).toDouble(),
      );
}
