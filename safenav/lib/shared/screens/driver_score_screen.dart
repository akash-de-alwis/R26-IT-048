import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../member4_scoring/services/sensor_service.dart';
import '../../member4_scoring/models/trip_session.dart';
import '../../member4_scoring/widgets/trip_event_card.dart';
import '../../features/driver_score/widgets/segmented_gauge.dart';

// ── Score helpers ─────────────────────────────────────────────────────────────

Color _getScoreColor(int score) {
  if (score >= 70) return const Color(0xFF2979FF);
  if (score >= 50) return const Color(0xFFFFB300);
  return const Color(0xFFFF3B5C);
}

String _getScoreLabel(int score) {
  if (score >= 85) return 'Excellent Driver';
  if (score >= 70) return 'Good Driver';
  if (score >= 50) return 'Needs Improvement';
  return 'Unsafe Driving';
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DriverScoreScreen extends StatelessWidget {
  const DriverScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorService>();
    final trip = sensor.currentTrip;
    final int score = trip?.safetyScore ?? 78;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'My Safety Score',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D1B2A),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Based on your driving behavior',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5C6B7A),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Live trip banner ───────────────────────────────────────────
            if (sensor.isTracking && trip != null)
              _LiveStatusCard(sensor: sensor, trip: trip),

            // ── Main score card ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MainScoreCard(score: score, isTracking: sensor.isTracking),
            ),

            // ── Stat cards grid ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _StatsGrid(trip: trip),
            ),

            // ── Events list ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    icon: Icons.timeline_rounded,
                    label: 'Driving Events',
                    color: const Color(0xFF2979FF),
                  ),
                  const SizedBox(height: 12),
                  _EventsList(sensor: sensor),
                ],
              ),
            ),

            // ── Tips card ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: const _TipsCard(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main score card ───────────────────────────────────────────────────────────

class _MainScoreCard extends StatelessWidget {
  final int score;
  final bool isTracking;

  const _MainScoreCard({required this.score, required this.isTracking});

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(score);
    final scoreLabel = _getScoreLabel(score);
    final gaugeWidth = MediaQuery.of(context).size.width - 80;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Top row: label + badge ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SAFETY RATING',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Color(0xFFADB8C3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTracking ? 'Current Trip' : 'Overall Score',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ],
              ),
              isTracking
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B5C).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B5C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Color(0xFFFF3B5C),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEF1F5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield_rounded,
                              size: 14, color: Color(0xFF2979FF)),
                          SizedBox(width: 5),
                          Text(
                            'SafeNav',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),

          // ── Rank chip ────────────────────────────────────────────────────
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    size: 16, color: Color(0xFF2979FF)),
                const SizedBox(width: 8),
                _RankMessage(score: score),
              ],
            ),
          ),

          // ── Gauge + score overlay ────────────────────────────────────────
          const SizedBox(height: 24),
          SizedBox(
            width: gaugeWidth,
            height: gaugeWidth * 0.65,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SegmentedGauge(
                  score: score.toDouble(),
                  activeColor: scoreColor,
                  inactiveColor: const Color(0xFFEEF1F5),
                  size: gaugeWidth,
                ),
                Positioned(
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1B2A),
                          letterSpacing: -2,
                        ),
                      ),
                      const Text(
                        'out of 100',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFADB8C3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: scoreColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          scoreLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ],
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

// ── Rank message with highlighted percentage ──────────────────────────────────

class _RankMessage extends StatelessWidget {
  final int score;
  const _RankMessage({required this.score});

  @override
  Widget build(BuildContext context) {
    if (score < 50) {
      return const Text(
        'Below average — keep improving!',
        style: TextStyle(fontSize: 12, color: Color(0xFF5C6B7A)),
      );
    }

    final String pct = score >= 85
        ? 'top 10%'
        : score >= 70
            ? 'top 25%'
            : 'top 50%';

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Color(0xFF5C6B7A)),
        children: [
          const TextSpan(text: "You're in the "),
          TextSpan(
            text: pct,
            style: const TextStyle(
              color: Color(0xFF2979FF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: ' of SafeNav drivers'),
        ],
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final TripSession? trip;
  const _StatsGrid({required this.trip});

  @override
  Widget build(BuildContext context) {
    final brakes = trip?.harshBrakingCount ?? 0;
    final turns = trip?.sharpTurnCount ?? 0;
    final maxSpeed = trip?.maxSpeedKmh ?? 0.0;
    final distance = trip?.totalDistanceKm ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          icon: Icons.pan_tool_rounded,
          color: const Color(0xFF2979FF),
          value: '$brakes',
          label: 'Harsh Brakes',
          chipText: brakes > 0 ? 'Risk events' : 'All clear',
          chipColor:
              brakes > 0 ? const Color(0xFFFF3B5C) : const Color(0xFF00C06A),
        ),
        _StatCard(
          icon: Icons.turn_right_rounded,
          color: const Color(0xFF5B9BFF),
          value: '$turns',
          label: 'Sharp Turns',
          chipText: turns > 0 ? 'Risk events' : 'All clear',
          chipColor:
              turns > 0 ? const Color(0xFFFF3B5C) : const Color(0xFF00C06A),
        ),
        _StatCard(
          icon: Icons.speed_rounded,
          color: const Color(0xFF1557D6),
          value: '${maxSpeed.toStringAsFixed(0)} km/h',
          label: 'Max Speed',
          chipText: maxSpeed > 70 ? 'Over limit' : 'Safe speed',
          chipColor: maxSpeed > 70
              ? const Color(0xFFFF3B5C)
              : const Color(0xFF00C06A),
        ),
        _StatCard(
          icon: Icons.route_rounded,
          color: const Color(0xFF448AFF),
          value: '${distance.toStringAsFixed(1)} km',
          label: 'Distance',
          chipText: 'This trip',
          chipColor: const Color(0xFF5C6B7A),
        ),
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String chipText;
  final Color chipColor;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.chipText,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF1F5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    fontSize: 9,
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF5C6B7A)),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D1B2A),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ── Live status banner ────────────────────────────────────────────────────────

class _LiveStatusCard extends StatelessWidget {
  final SensorService sensor;
  final TripSession trip;

  const _LiveStatusCard({required this.sensor, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF00C06A).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00C06A).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          _PulsingDot(),
          const SizedBox(width: 8),
          const Text(
            'Live trip in progress',
            style: TextStyle(
              color: Color(0xFF00C06A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _LiveStat(label: 'Duration', value: '${trip.duration} min'),
          const SizedBox(width: 16),
          _LiveStat(
            label: 'Distance',
            value: '${trip.totalDistanceKm.toStringAsFixed(1)} km',
          ),
          const SizedBox(width: 16),
          _LiveStat(
            label: 'Speed',
            value: '${sensor.currentSpeedKmh.toStringAsFixed(0)} km/h',
          ),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;
  const _LiveStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF5C6B7A),
                fontSize: 9,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF00C06A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Events list ───────────────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  final SensorService sensor;
  const _EventsList({required this.sensor});

  @override
  Widget build(BuildContext context) {
    final events =
        sensor.currentTrip?.events.reversed.take(10).toList() ?? [];

    if (events.isEmpty) {
      if (sensor.isTracking) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF00C06A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF00C06A).withValues(alpha: 0.3),
                width: 0.8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFF00C06A), size: 22),
              SizedBox(width: 12),
              Text(
                'No events yet — driving smoothly!',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF00C06A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.directions_car_outlined,
                color: Color(0xFFADB8C3), size: 22),
            SizedBox(width: 12),
            Text(
              'Start a trip to see your driving events',
              style:
                  TextStyle(fontSize: 13, color: Color(0xFF5C6B7A)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: events.map((e) => TripEventCard.fromDrivingEvent(e)).toList(),
    );
  }
}

// ── Tips card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  static const _tips = [
    'Brake gradually, not suddenly',
    'Maintain steady speed on highways',
    'Avoid sharp turns above 40 km/h',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2979FF).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: Color(0xFF2979FF), size: 17),
              ),
              const SizedBox(width: 10),
              const Text(
                'How to improve',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2979FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 5.5, right: 10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2979FF),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0D1B2A),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
