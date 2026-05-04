import 'package:flutter/material.dart';
import '../../member4_scoring/models/driving_event.dart';
import '../../member4_scoring/models/trip_session.dart';
import '../../core/theme/app_colors.dart';
import '../../member4_scoring/widgets/score_gauge_widget.dart';
import '../../member4_scoring/widgets/trip_event_card.dart';

class TripSummaryScreen extends StatelessWidget {
  final TripSession trip;

  const TripSummaryScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Score hero card ──────────────────────────────────────────
            _ScoreHeroCard(trip: trip),
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
                  label: 'Duration',
                  value: '${trip.duration} min',
                  icon: Icons.timer_rounded,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Distance',
                  value: '${trip.totalDistanceKm.toStringAsFixed(1)} km',
                  icon: Icons.route_rounded,
                  color: AppColors.success,
                ),
                _StatCard(
                  label: 'Max Speed',
                  value: '${trip.maxSpeedKmh.toStringAsFixed(0)} km/h',
                  icon: Icons.speed_rounded,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Events',
                  value: '${trip.events.length}',
                  icon: Icons.timeline_rounded,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Events breakdown ─────────────────────────────────────────
            if (trip.events.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.bar_chart_rounded,
                label: 'Events Breakdown',
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              _EventsBreakdown(trip: trip),
              const SizedBox(height: 28),
            ],

            // ── Detailed events list ─────────────────────────────────────
            if (trip.events.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.timeline_rounded,
                label: 'All Events',
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              ...trip.events.map((e) => TripEventCard.fromDrivingEvent(e)),
              const SizedBox(height: 28),
            ],

            // ── Tips ─────────────────────────────────────────────────────
            _TipsCard(trip: trip),
            const SizedBox(height: 28),

            // ── Done button ──────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Score hero card ───────────────────────────────────────────────────────────

class _ScoreHeroCard extends StatelessWidget {
  final TripSession trip;
  const _ScoreHeroCard({required this.trip});

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

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
                children: [
                  const Text(
                    'TRIP COMPLETE',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(trip.endTime ?? trip.startTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: trip.scoreColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: trip.scoreColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  trip.scoreLabel,
                  style: TextStyle(
                    color: trip.scoreColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ScoreGaugeWidget(score: trip.safetyScore.toDouble(), onDark: true),
          if (trip.destinationName != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      trip.destinationName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            color: AppColors.shadow,
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

// ── Events breakdown ──────────────────────────────────────────────────────────

class _EventsBreakdown extends StatelessWidget {
  final TripSession trip;
  const _EventsBreakdown({required this.trip});

  Map<DrivingEventType, int> get _counts {
    final map = <DrivingEventType, int>{};
    for (final e in trip.events) {
      map[e.type] = (map[e.type] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    if (counts.isEmpty) return const SizedBox.shrink();

    final total = trip.events.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: counts.entries.map((entry) {
          final event = DrivingEvent(
            type: entry.key,
            timestamp: DateTime.now(),
            magnitude: 0,
            latitude: 0,
            longitude: 0,
            pointsDeducted: 0,
          );
          final fraction = entry.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: event.eventColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(event.eventIcon,
                          color: event.eventColor, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: event.eventColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: event.eventColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: AppColors.surface,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(event.eventColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tips card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  final TripSession trip;
  const _TipsCard({required this.trip});

  List<String> get _tips {
    if (trip.safetyScore >= 85) {
      return ['Excellent trip! Keep maintaining this safe driving style.'];
    }

    final counts = <DrivingEventType, int>{};
    for (final e in trip.events) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tips = <String>[];
    for (final entry in sorted.take(3)) {
      switch (entry.key) {
        case DrivingEventType.harshBraking:
          tips.add('Try to anticipate stops earlier and brake gradually.');
          break;
        case DrivingEventType.harshAcceleration:
          tips.add(
              'Accelerate smoothly — rapid acceleration wastes fuel and increases risk.');
          break;
        case DrivingEventType.sharpTurn:
          tips.add('Slow down before corners instead of turning sharply.');
          break;
        case DrivingEventType.overSpeeding:
          tips.add(
              'Keep to the speed limit — it reduces accident risk by 30%.');
          break;
        case DrivingEventType.smoothDriving:
          tips.add('Great smooth driving stretches — keep it up!');
          break;
      }
    }

    return tips.isEmpty
        ? ['Maintain steady speed and anticipate traffic ahead.']
        : tips;
  }

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
                'Score improvement tips',
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
