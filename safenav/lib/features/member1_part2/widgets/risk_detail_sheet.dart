import 'package:flutter/material.dart';
import '../models/realtime_risk_model.dart';
import '../models/risk_factor_model.dart';

class RiskDetailSheet extends StatelessWidget {
  final RealtimeRiskModel risk;

  const RiskDetailSheet({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.93,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: risk.riskColor, width: 3),
          ),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: risk.riskColor.withOpacity(0.12),
                    border: Border.all(color: risk.riskColor, width: 2.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          risk.riskScore.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: risk.riskColor,
                            height: 1,
                          ),
                        ),
                        Text(
                          'risk',
                          style: TextStyle(
                            fontSize: 9,
                            color: risk.riskColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: risk.riskColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          risk.riskLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Real-time Risk Assessment',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5C6B7A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF5C6B7A)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Recommendation card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: risk.riskColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: risk.riskColor.withOpacity(0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                      size: 18, color: risk.riskColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      risk.recommendation,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF0D1B2A),
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section label
            _sectionLabel('Weather Conditions'),
            const SizedBox(height: 10),

            // Weather row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _weatherTile(
                    icon: risk.weather.icon,
                    label:
                        risk.weather.description.split(' ').map((w) {
                      return w.isEmpty
                          ? w
                          : w[0].toUpperCase() + w.substring(1);
                    }).join(' '),
                    value: '',
                    iconColor: const Color(0xFF2979FF),
                  ),
                  _weatherTile(
                    icon: Icons.thermostat_rounded,
                    label: 'Temp',
                    value:
                        '${risk.weather.temperatureC.toStringAsFixed(0)}°C',
                    iconColor: const Color(0xFFFF6B35),
                  ),
                  _weatherTile(
                    icon: Icons.water_drop_rounded,
                    label: 'Humidity',
                    value: '${risk.weather.humidityPct}%',
                    iconColor: const Color(0xFF00B4D8),
                  ),
                  _weatherTile(
                    icon: Icons.air_rounded,
                    label: 'Wind',
                    value:
                        '${risk.weather.windSpeedKmh.toStringAsFixed(0)} km/h',
                    iconColor: const Color(0xFF8B9DC3),
                  ),
                  _weatherTile(
                    icon: Icons.visibility_rounded,
                    label: 'Visibility',
                    value: risk.weather.visibilityM >= 1000
                        ? '${(risk.weather.visibilityM / 1000).toStringAsFixed(1)} km'
                        : '${risk.weather.visibilityM} m',
                    iconColor: const Color(0xFF6A4C93),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Road condition
            _sectionLabel('Road Condition'),
            const SizedBox(height: 10),
            _RoadConditionPill(condition: risk.roadCondition),

            const SizedBox(height: 18),

            // Contributing factors
            _sectionLabel('Risk Factors'),
            const SizedBox(height: 10),
            ...risk.contributingFactors
                .map((f) => _FactorRow(factor: f, accentColor: risk.riskColor)),

            // Hotspot proximity
            if (risk.nearestHotspotDistanceM != null) ...[
              const SizedBox(height: 18),
              _sectionLabel('Nearest Accident Hotspot'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFB300).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFFFFB300), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${risk.nearestHotspotDistanceM!.toStringAsFixed(0)} m away',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1B2A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      risk.nearestHotspotDistanceM! <= 150
                          ? 'Entering hotspot zone'
                          : risk.nearestHotspotDistanceM! <= 350
                              ? 'Approaching hotspot'
                              : 'Hotspot nearby',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Timestamp
            Center(
              child: Text(
                'Updated ${_formatTime(risk.timestamp)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFADB8C3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0D1B2A),
          letterSpacing: 0.2,
        ),
      );

  Widget _weatherTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 4),
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8D9EAD),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Road Condition Pill ───────────────────────────────────────────────────────

class _RoadConditionPill extends StatelessWidget {
  final String condition;
  const _RoadConditionPill({required this.condition});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _meta(condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _meta(String c) {
    switch (c) {
      case 'slippery':
        return ('Slippery', const Color(0xFFE53935), Icons.warning_rounded);
      case 'wet':
        return ('Wet', const Color(0xFF1E88E5), Icons.water_rounded);
      case 'poor_visibility':
        return ('Poor Visibility', const Color(0xFF8E24AA), Icons.foggy);
      default:
        return ('Dry', const Color(0xFF43A047), Icons.check_circle_rounded);
    }
  }
}

// ── Factor Row ────────────────────────────────────────────────────────────────

class _FactorRow extends StatelessWidget {
  final RiskFactor factor;
  final Color accentColor;
  const _FactorRow({required this.factor, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    factor.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ),
                Text(
                  factor.value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5C6B7A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '×${factor.multiplier.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: factor.contributionPct / 100,
                      minHeight: 5,
                      backgroundColor: accentColor.withOpacity(0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${factor.contributionPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
