import 'package:flutter/material.dart';
import '../../../core/models/driving_event.dart';
import '../../../core/models/trip_session.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/score_gauge_widget.dart';
import '../widgets/trip_event_card.dart';

class TripSummaryScreen extends StatelessWidget {
  final TripSession trip;

  const TripSummaryScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip Summary',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            // ── Score hero card ──────────────────────────────────────────
            _ScoreHeroCard(trip: trip),
            const SizedBox(height: 24),

            // ── Stats row ────────────────────────────────────────────────
            _StatsRow(trip: trip),
            const SizedBox(height: 24),

            // ── Events breakdown ─────────────────────────────────────────
            _EventsBreakdown(trip: trip),
            const SizedBox(height: 24),

            // ── Detailed events list ─────────────────────────────────────
            if (trip.events.isNotEmpty) ...[
              const Text(
                'All events',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...trip.events.map(
                (e) => TripEventCard.fromDrivingEvent(e),
              ),
              const SizedBox(height: 20),
            ],

            // ── Tips ─────────────────────────────────────────────────────
            _TipsCard(trip: trip),
            const SizedBox(height: 32),

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Center(child: ScoreGaugeWidget(score: trip.safetyScore.toDouble())),
          const SizedBox(height: 12),
          Text(
            trip.scoreLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: trip.scoreColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trip completed · ${_formatTime(trip.endTime ?? trip.startTime)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (trip.destinationName != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on,
                    size: 12, color: AppColors.textHint),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    trip.destinationName!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final TripSession trip;
  const _StatsRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
            label: 'Duration', value: '${trip.duration} min'),
        _StatChip(
            label: 'Distance',
            value: '${trip.totalDistanceKm.toStringAsFixed(1)} km'),
        _StatChip(
            label: 'Max Speed',
            value: '${trip.maxSpeedKmh.toStringAsFixed(0)} km/h'),
        _StatChip(
            label: 'Events',
            value: '${trip.events.length}'),
      ]
          .expand((w) => [w, const SizedBox(width: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Events breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...counts.entries.map((entry) {
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
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: event.eventColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: const Color(0xFFEEF1F5),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(event.eventColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
          tips.add(
              'Try to anticipate stops earlier and brake gradually.');
          break;
        case DrivingEventType.harshAcceleration:
          tips.add(
              'Accelerate smoothly — rapid acceleration wastes fuel and increases risk.');
          break;
        case DrivingEventType.sharpTurn:
          tips.add(
              'Slow down before corners instead of turning sharply.');
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score improvement tips',
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
