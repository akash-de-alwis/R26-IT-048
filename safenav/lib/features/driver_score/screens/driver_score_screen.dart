import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/score_gauge_widget.dart';
import '../widgets/trip_event_card.dart';

class DriverScoreScreen extends StatelessWidget {
  const DriverScoreScreen({super.key});

  static const double _score = 78;

  @override
  Widget build(BuildContext context) {
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

            // ── Section 1: Gauge ─────────────────────────────────────────
            const Center(child: ScoreGaugeWidget(score: _score)),
            const SizedBox(height: 32),

            // ── Section 2: Stats grid ─────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: const [
                _StatCard(label: 'Total Trips', value: '24'),
                _StatCard(label: 'Distance', value: '187 km'),
                _StatCard(label: 'Harsh Brakes', value: '3'),
                _StatCard(label: 'Sharp Turns', value: '7'),
              ],
            ),
            const SizedBox(height: 28),

            // ── Section 3: Today's events ─────────────────────────────────
            const Text(
              "Today's driving events",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            const TripEventCard(
              eventType: TripEventType.harshBraking,
              time: '09:14 AM',
              location: 'Main St & Station Rd',
              points: -5,
            ),
            const TripEventCard(
              eventType: TripEventType.sharpTurn,
              time: '09:22 AM',
              location: 'Panadura Junction',
              points: -3,
            ),
            const TripEventCard(
              eventType: TripEventType.smoothDriving,
              time: '09:30–09:45 AM',
              location: 'Coastal Highway',
              points: 0,
            ),
            const TripEventCard(
              eventType: TripEventType.harshBraking,
              time: '10:05 AM',
              location: 'Highway A1, km 12',
              points: -5,
            ),
            const TripEventCard(
              eventType: TripEventType.smoothDriving,
              time: '10:20 AM',
              location: 'Final approach, Horana Rd',
              points: 0,
            ),
            const SizedBox(height: 28),

            // ── Section 4: Tips ───────────────────────────────────────────
            const _TipsCard(),
            const SizedBox(height: 28),
          ],
        ),
      ),
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
        border: Border.all(
          color: const Color(0xFFE8EDF2),
          width: 0.5,
        ),
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
