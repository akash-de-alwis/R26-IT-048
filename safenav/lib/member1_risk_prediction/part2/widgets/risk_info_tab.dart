import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/member1b_realtime_pipeline/models/stream_risk_update_model.dart';
import '../../../features/member1b_realtime_pipeline/services/realtime_pipeline_service.dart';
import '../models/realtime_risk_model.dart';
import '../models/risk_factor_model.dart';
import '../services/realtime_risk_service.dart';
import 'risk_factor_row.dart';
import 'risk_gauge.dart';
import 'risk_tips_card.dart';
import 'risk_trend_sparkline.dart';

const _ink = Color(0xFF0D1B2A);
const _muted = Color(0xFF5C6B7A);
const _sectionGap = 16.0;
const _cardRadius = 16.0;

Widget _sectionTitle(String text) => Text(
      text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
    );

/// Content of the trip sheet's "Risk Info" tab: gauge with level and
/// trend, biggest factor, weather, sorted factors, trend line and tips.
/// Shows skeletons until the first risk response of the trip arrives.
///
/// The parent rebuilds often (sensor ticks, the 3 s stream), so each
/// section is memoised and only rebuilt when its own values change.
class RiskInfoTab extends StatefulWidget {
  final Color accent;

  const RiskInfoTab({super.key, required this.accent});

  @override
  State<RiskInfoTab> createState() => _RiskInfoTabState();
}

class _RiskInfoTabState extends State<RiskInfoTab> {
  final Map<String, (Object, Widget)> _memo = {};

  /// Returns the cached widget for [slot] while [spec] is unchanged, so
  /// Flutter skips rebuilding that subtree.
  Widget _memoized(String slot, Object spec, Widget Function() build) {
    final hit = _memo[slot];
    if (hit != null && hit.$1 == spec) return hit.$2;
    final widget = build();
    _memo[slot] = (spec, widget);
    return widget;
  }

  /// Member 1b stream update, or null when missing / disconnected.
  StreamRiskUpdate? _streamUpdate(BuildContext context) {
    try {
      final p = context.watch<RealtimePipelineService>();
      return p.isConnected ? p.latestUpdate : null;
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final riskSvc = context.watch<RealtimeRiskService>();
    final risk = riskSvc.currentRisk;
    if (risk == null) return const _RiskInfoSkeleton();

    final stream = _streamUpdate(context);
    final history = riskSvc.scoreHistory;
    final trend = riskTrend(riskSvc.timedScoreHistory);
    final factors = [...risk.contributingFactors]
      ..sort((a, b) => b.contributionPct.compareTo(a.contributionPct));
    final biggest = factors.isEmpty ? null : factors.first;
    RiskFactor? vehicleFactor;
    for (final f in factors) {
      if (f.name == 'Vehicle Type') vehicleFactor = f;
    }

    final tips = buildTips(
      hotspotMultiplier: risk.hotspotProximityMultiplier,
      weatherCondition: risk.weather.condition,
      weatherMultiplier: risk.weatherMultiplier,
      roadCondition: risk.roadCondition,
      roadMultiplier: risk.roadConditionMultiplier,
      speedMultiplier: risk.speedMultiplier,
      vehicleType: vehicleFactor?.value ?? riskSvc.vehicleType,
      vehicleMultiplier: vehicleFactor?.multiplier ?? 1.0,
      harshBrakesPerMin: stream?.rollingFeatures.harshBrakeEvents,
      volatilityMultiplier: stream?.volatilityMultiplier ?? 1.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // a) Gauge, level and trend
        _memoized(
          'gauge',
          (risk.riskScore, risk.riskLevel, trend),
          () => Center(
            child: RiskGauge(
              score: risk.riskScore,
              level: risk.riskLevel,
              levelLabel: risk.riskLabel,
              trend: trend,
            ),
          ),
        ),

        // b) Biggest factor callout
        if (biggest != null) ...[
          const SizedBox(height: 12),
          _memoized(
            'callout',
            (biggest.name, biggest.value, biggest.multiplier,
                biggest.contributionPct),
            () => _BiggestFactorCallout(factor: biggest),
          ),
        ],

        // c) Weather
        const SizedBox(height: _sectionGap),
        _sectionTitle('Weather'),
        const SizedBox(height: 8),
        _memoized(
          'weather',
          (risk.weather.condition, risk.weather.description,
              risk.weather.temperatureC, risk.weather.humidityPct,
              risk.weather.windSpeedKmh),
          () => _WeatherStrip(risk: risk),
        ),

        // d) Factors, highest contribution first
        const SizedBox(height: _sectionGap),
        _sectionTitle('What is driving your risk'),
        const SizedBox(height: 4),
        for (var i = 0; i < factors.length; i++)
          _memoized(
            'factor_${factors[i].name}',
            (factors[i].value, factors[i].multiplier,
                factors[i].contributionPct, i == 0),
            () => RiskFactorRow(
              key: ValueKey(factors[i].name),
              name: factors[i].name,
              value: factors[i].value,
              multiplier: factors[i].multiplier,
              contributionPct: factors[i].contributionPct,
              isBiggest: i == 0,
              icon: riskFactorIcon(factors[i].name, value: factors[i].value),
            ),
          ),
        // Live row, only while the Member 1b stream is connected
        if (stream != null)
          _memoized(
            'driving',
            (stream.rollingFeatures.harshBrakeEvents,
                stream.volatilityMultiplier),
            () => RiskFactorRow(
              key: const ValueKey('driving_behaviour'),
              name: 'Driving behaviour',
              value: _hardBrakesText(stream.rollingFeatures.harshBrakeEvents),
              multiplier: stream.volatilityMultiplier,
              isLive: true,
              icon: Icons.traffic_rounded,
            ),
          ),

        // e) Trend line (hidden until 3 points)
        if (history.length >= RiskTrendSparkline.minPoints) ...[
          const SizedBox(height: _sectionGap),
          _memoized(
            'sparkline',
            (accent, history.length, Object.hashAll(history)),
            () => RiskTrendSparkline(points: history, accent: accent),
          ),
        ],

        // f) Tips
        const SizedBox(height: _sectionGap),
        _memoized(
          'tips',
          (accent, tips.join('|')),
          () => RiskTipsCard(tips: tips, accent: accent),
        ),
      ],
    );
  }

  // "per minute" is shown in the LIVE chip's tooltip
  static String _hardBrakesText(int n) =>
      '$n hard ${n == 1 ? 'brake' : 'brakes'}';
}

class _BiggestFactorCallout extends StatelessWidget {
  final RiskFactor factor;
  const _BiggestFactorCallout({required this.factor});

  @override
  Widget build(BuildContext context) {
    final color = multiplierColor(factor.multiplier);
    final iconColor = multiplierTextColor(factor.multiplier);
    final name = factor.name.isEmpty
        ? factor.name
        : factor.name[0].toUpperCase() + factor.name.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(riskFactorIcon(factor.name, value: factor.value),
              size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$name adds the most risk right now '
              '(${factor.contributionPct.toStringAsFixed(0)}%)',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  final RealtimeRiskModel risk;
  const _WeatherStrip({required this.risk});

  @override
  Widget build(BuildContext context) {
    final w = risk.weather;
    final desc = w.description.isEmpty
        ? '--'
        : w.description[0].toUpperCase() + w.description.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Row(
        children: [
          _item(w.icon, desc, 'Sky'),
          _item(Icons.thermostat_rounded,
              '${w.temperatureC.toStringAsFixed(0)}°C', 'Temp'),
          _item(Icons.water_drop_outlined, '${w.humidityPct}%', 'Humidity'),
          _item(Icons.air_rounded,
              '${w.windSpeedKmh.toStringAsFixed(0)} km/h', 'Wind'),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2979FF)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
          ),
          Text(label,
              style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }
}

/// Grey placeholders shown until the first risk response arrives.
class _RiskInfoSkeleton extends StatelessWidget {
  const _RiskInfoSkeleton();

  Widget _box(double w, double h, {double r = 8}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF1F5),
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Waiting for live data...',
                style: TextStyle(fontSize: 13, color: _muted)),
          ],
        ),
        const SizedBox(height: _sectionGap),
        Center(child: _box(RiskGauge.width, RiskGauge.height / 1.3, r: 100)),
        const SizedBox(height: 12),
        Center(child: _box(90, 22)),
        const SizedBox(height: _sectionGap),
        _box(double.infinity, 64, r: _cardRadius),
        const SizedBox(height: _sectionGap),
        for (var i = 0; i < 3; i++) ...[
          Row(
            children: [
              _box(36, 36, r: 18),
              const SizedBox(width: 10),
              Expanded(child: _box(double.infinity, 14)),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// The trip sheet's End Trip button in the given accent.
class EndTripButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onPressed;

  const EndTripButton({
    super.key,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop_circle_outlined, size: 18),
            SizedBox(width: 8),
            Text('End Trip',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// End Trip footer shown BELOW the Risk Info scroll view (not over it).
/// A solid bar in the sheet's bottom colour; bottom padding keeps the
/// button clear of the floating navigation bar and the system inset.
class RiskInfoEndTripFooter extends StatelessWidget {
  /// Minimum space under the button for the floating navigation bar.
  static const double navBarClearance = 110;
  static const double _gapAboveNavBar = 12;

  final Color accent;
  final Color barColor;
  final VoidCallback onEndTrip;

  const RiskInfoEndTripFooter({
    super.key,
    required this.accent,
    required this.barColor,
    required this.onEndTrip,
  });

  @override
  Widget build(BuildContext context) {
    // On the map screen the bottom padding already includes the floating
    // nav bar (the shell extends its body under it), so only a small gap is
    // added; the minimum covers layouts where it does not.
    final inset = MediaQuery.of(context).padding.bottom + _gapAboveNavBar;
    final bottom = inset > navBarClearance ? inset : navBarClearance;
    return ColoredBox(
      color: barColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
        child: EndTripButton(accent: accent, onPressed: onEndTrip),
      ),
    );
  }
}
