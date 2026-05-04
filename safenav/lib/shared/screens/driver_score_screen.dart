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
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: AppColors.surface,
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
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
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
            const SizedBox(height: 8),

            // ── Live trip banner ─────────────────────────────────────────
            if (sensor.isTracking && trip != null)
              _LiveStatusCard(sensor: sensor, trip: trip),

            // ── Hero score card ───────────────────────────────────────────
            const SizedBox(height: 4),
            _HeroScoreCard(score: score),
            const SizedBox(height: 24),

            // ── Stats grid ───────────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  label: 'Harsh Brakes',
                  value: '${trip?.harshBrakingCount ?? 0}',
                  icon: Icons.front_hand_rounded,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Sharp Turns',
                  value: '${trip?.sharpTurnCount ?? 0}',
                  icon: Icons.turn_right_rounded,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Max Speed',
                  value: '${trip?.maxSpeedKmh.toStringAsFixed(0) ?? 0} km/h',
                  icon: Icons.speed_rounded,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Distance',
                  value:
                      '${trip?.totalDistanceKm.toStringAsFixed(1) ?? 0} km',
                  icon: Icons.route_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Behavior alerts ──────────────────────────────────────────
            if (sensor.isTracking && trip != null) ...[
              _SectionHeader(
                icon: Icons.warning_amber_rounded,
                label: 'Driving Alerts',
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              BehaviorAlertsWidget(trip: trip),
              const SizedBox(height: 28),
            ],

            // ── Events list ──────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.timeline_rounded,
              label: 'Driving Events',
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            _EventsList(sensor: sensor),
            const SizedBox(height: 28),

            // ── Tips ─────────────────────────────────────────────────────
            const _TipsCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Hero score card ───────────────────────────────────────────────────────────

class _HeroScoreCard extends StatelessWidget {
  final double score;
  const _HeroScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'SAFETY RATING',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Current Trip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'SafeNav',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ScoreGaugeWidget(score: score, onDark: true),
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
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _PulsingDot(),
          const SizedBox(width: 8),
          const Text(
            'Live trip in progress',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _LiveStat(
              label: 'Duration', value: '${trip.duration} min'),
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
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w500,
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
          color: AppColors.success,
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
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 22),
              SizedBox(width: 12),
              Text(
                'No events yet — driving smoothly!',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.success,
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
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
        ),
        child: Row(
          children: const [
            Icon(Icons.directions_car_outlined,
                color: AppColors.textHint, size: 22),
            SizedBox(width: 12),
            Text(
              'Start a trip to see your driving events',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          events.map((e) => TripEventCard.fromDrivingEvent(e)).toList(),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
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
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_rounded,
                    color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 10),
              const Text(
                'How to improve',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
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
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
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
