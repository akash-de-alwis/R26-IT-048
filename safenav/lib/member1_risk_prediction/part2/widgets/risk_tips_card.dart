import 'package:flutter/material.dart';

/// All tip texts in one place so they can be translated later.
const Map<String, String> kRiskTipText = {
  'hotspot': 'Accident hotspot nearby. Reduce speed and stay alert.',
  'rain': 'Rain reduces grip. Increase your following distance.',
  'wet_road': 'The road is wet. Brake earlier and avoid sudden turns.',
  'speed': 'You are driving fast for these conditions. Ease off the '
      'accelerator.',
  'small_vehicle': 'Smaller vehicles are more exposed. Take extra care at '
      'junctions.',
  'hard_brakes': 'Several hard brakes recently. Leave a longer gap.',
  'all_good': 'Conditions look good. Keep a safe distance.',
};

const int kMaxTips = 3;

const _rainConditions = {'rain', 'heavy_rain', 'thunderstorm'};
const _wetRoads = {'wet', 'slippery'};
const _smallVehicles = {'Motorcycle', 'Three Wheeler'};

/// Rule-based tips, strongest factor first, at most [kMaxTips].
///
/// [harshBrakesPerMin] is null when the Member 1b stream is not connected.
/// Each matched rule is ranked by its multiplier so the tips follow the
/// top factors; 'all_good' only appears when no other rule matched.
List<String> buildTips({
  double hotspotMultiplier = 1.0,
  String weatherCondition = 'clear',
  double weatherMultiplier = 1.0,
  String roadCondition = 'dry',
  double roadMultiplier = 1.0,
  double speedMultiplier = 1.0,
  String vehicleType = 'Car',
  double vehicleMultiplier = 1.0,
  int? harshBrakesPerMin,
  double volatilityMultiplier = 1.0,
}) {
  final matched = <(double, String)>[];
  if (hotspotMultiplier >= 1.2) matched.add((hotspotMultiplier, 'hotspot'));
  if (_rainConditions.contains(weatherCondition)) {
    matched.add((weatherMultiplier, 'rain'));
  }
  if (_wetRoads.contains(roadCondition)) {
    matched.add((roadMultiplier, 'wet_road'));
  }
  if (speedMultiplier >= 1.2) matched.add((speedMultiplier, 'speed'));
  if (_smallVehicles.contains(vehicleType)) {
    matched.add((vehicleMultiplier, 'small_vehicle'));
  }
  if (harshBrakesPerMin != null && harshBrakesPerMin >= 2) {
    matched.add((volatilityMultiplier, 'hard_brakes'));
  }

  if (matched.isEmpty) return [kRiskTipText['all_good']!];
  // Stable sort: equal multipliers keep the rule order above
  final ranked = [
    for (var i = 0; i < matched.length; i++) (matched[i], i),
  ]..sort((a, b) {
      final c = b.$1.$1.compareTo(a.$1.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
  return ranked
      .take(kMaxTips)
      .map((e) => kRiskTipText[e.$1.$2]!)
      .toList();
}

/// "What you can do" card.
class RiskTipsCard extends StatelessWidget {
  final List<String> tips;
  final Color accent;

  const RiskTipsCard({super.key, required this.tips, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you can do',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 8),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0D1B2A),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
