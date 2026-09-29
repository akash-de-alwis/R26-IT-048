import 'package:flutter/material.dart';
import '../../../member4_driver_scoring/part1/models/trip_session.dart';

/// Safe-driving streak + 7-day safety-score sparkline, computed from the
/// same trip history future the Recent Trips section uses.
///
/// A trip counts as high-risk when its safety score is in the model's
/// danger band (< 50, "Unsafe Driving"); trips carry no separate risk level.
class HomeStreakTrendCard extends StatelessWidget {
  final Future<List<TripSession>> tripsFuture;

  const HomeStreakTrendCard({super.key, required this.tripsFuture});

  static const highRiskBelow = 50;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Consecutive days, walking back from today, with no high-risk trip.
  /// Starts at the first day that has history; 0 when there is none.
  static int streakDays(List<TripSession> trips, DateTime now) {
    if (trips.isEmpty) return 0;
    final today = _day(now);
    final highRiskDays = {
      for (final t in trips)
        if (t.safetyScore < highRiskBelow) _day(t.startTime),
    };
    final firstDay =
        trips.map((t) => _day(t.startTime)).reduce((a, b) => a.isBefore(b) ? a : b);
    var streak = 0;
    for (var d = today; !d.isBefore(firstDay); d = DateTime(d.year, d.month, d.day - 1)) {
      if (highRiskDays.contains(d)) break;
      streak++;
    }
    return streak;
  }

  /// Average safety score for each of the last 7 days that has trips,
  /// oldest first. Days with no trips are skipped, not plotted as zero.
  static List<double> weeklyScores(List<TripSession> trips, DateTime now) {
    final today = _day(now);
    final start = DateTime(today.year, today.month, today.day - 6);
    final byDay = <DateTime, List<int>>{};
    for (final t in trips) {
      final d = _day(t.startTime);
      if (d.isBefore(start) || d.isAfter(today)) continue;
      byDay.putIfAbsent(d, () => []).add(t.safetyScore);
    }
    final days = byDay.keys.toList()..sort();
    return [
      for (final d in days)
        byDay[d]!.reduce((a, b) => a + b) / byDay[d]!.length,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TripSession>>(
      future: tripsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Skeleton();
        }
        if (snap.hasError) return const SizedBox.shrink();
        final trips = snap.data ?? const <TripSession>[];
        final now = DateTime.now();
        return _StreakCard(
          streak: streakDays(trips, now),
          scores: weeklyScores(trips, now),
        );
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final List<double> scores;

  const _StreakCard({required this.streak, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF1F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A56CC), Color(0xFF2979FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'DAYS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safe streak',
                  style: TextStyle(fontSize: 11, color: Color(0xFF5C6B7A)),
                ),
                const SizedBox(height: 3),
                Text(
                  streak > 0
                      ? 'No high-risk trips'
                      : 'Drive safely to start a streak',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
              ],
            ),
          ),
          if (scores.length >= 2) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 72,
                  height: 30,
                  child: CustomPaint(painter: _SparklinePainter(scores)),
                ),
                const SizedBox(height: 4),
                const Text(
                  '7-day score',
                  style: TextStyle(fontSize: 9, color: Color(0xFFADB8C3)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;

  _SparklinePainter(this.values);

  static const _accent = Color(0xFF2979FF);

  @override
  void paint(Canvas canvas, Size size) {
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 10) {
      // Keep small wobbles from looking like dramatic swings
      final mid = (hi + lo) / 2;
      lo = mid - 5;
      hi = mid + 5;
    }
    const pad = 3.0;
    Offset at(int i) => Offset(
          pad + (size.width - 2 * pad) * i / (values.length - 1),
          pad + (size.height - 2 * pad) * (1 - (values[i] - lo) / (hi - lo)),
        );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 2.5, Paint()..color = _accent);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EAF0),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
