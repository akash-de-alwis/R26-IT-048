import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../member4_scoring/services/sensor_service.dart';
import '../../core/theme/app_colors.dart';
import '../../member4_scoring/widgets/behavior_alerts_widget.dart';
import '../../member4_scoring/widgets/score_gauge_widget.dart';
import '../../member4_scoring/widgets/trip_event_card.dart';

class DriverScoreScreen extends StatelessWidget {
  const DriverScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorService>();
    final trip = sensor.currentTrip;
    final score = (trip?.safetyScore ?? 78).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Based on your driving behavior',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // ── Live trip status card ────────────────────────────────────
            if (sensor.isTracking && trip != null)
              _LiveStatusCard(sensor: sensor, trip: trip),

            // ── Gauge ────────────────────────────────────────────────────
            const SizedBox(height: 8),
            Center(child: ScoreGaugeWidget(score: score)),
            const SizedBox(height: 32),

            // ── Stats grid ───────────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  label: 'Harsh Brakes',
                  value: '${trip?.harshBrakingCount ?? 0}',
                ),
                _StatCard(
                  label: 'Sharp Turns',
                  value: '${trip?.sharpTurnCount ?? 0}',
                ),
                _StatCard(
                  label: 'Max Speed',
                  value:
                      '${trip?.maxSpeedKmh.toStringAsFixed(0) ?? 0} km/h',
                ),
                _StatCard(
                  label: 'Distance',
                  value:
                      '${trip?.totalDistanceKm.toStringAsFixed(1) ?? 0} km',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Behavior alerts ──────────────────────────────────────────
            if (sensor.isTracking && trip != null)
              BehaviorAlertsWidget(trip: trip),

            // ── Events list ──────────────────────────────────────────────
            const Text(
              "Driving events",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _EventsList(sensor: sensor),
            const SizedBox(height: 28),

            // ── Tips ─────────────────────────────────────────────────────
            const _TipsCard(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Live status card ──────────────────────────────────────────────────────────

class _LiveStatusCard extends StatelessWidget {
  final SensorService sensor;
  final dynamic trip;

  const _LiveStatusCard({required this.sensor, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2979FF), Color(0xFF1557D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulsingDot(),
              const SizedBox(width: 6),
              const Text(
                'Live trip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LiveStat(
                  label: 'Duration',
                  value: '${trip.duration} min'),
              _LiveStat(
                  label: 'Distance',
                  value:
                      '${trip.totalDistanceKm.toStringAsFixed(1)} km'),
              _LiveStat(
                  label: 'Speed',
                  value:
                      '${sensor.currentSpeedKmh.toStringAsFixed(0)} km/h'),
            ],
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
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
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
            color: const Color(0xFFF0FFF6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00C06A), width: 0.8),
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
                  color: Color(0xFF00873E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Start a trip to see your driving events',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: events
          .map((e) => TripEventCard.fromDrivingEvent(e))
          .toList(),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to improve',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          ..._tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 5, right: 9),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryDark,
                        height: 1.4,
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
