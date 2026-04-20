import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/stat_card_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary,
                          child: const Text(
                            'AT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ashan T.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'SafeNav Member',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(
                      color: Color(0xFFEEF1F5),
                      thickness: 1,
                      height: 1,
                    ),
                  ],
                ),
              ),
            ),

            // ── Safety badge ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _SafetyBadgeCard(),
            ),

            // ── Stats grid ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: const [
                  StatCardWidget(
                    label: 'Total distance',
                    value: '187 km',
                    icon: Icons.route_outlined,
                    color: AppColors.primary,
                  ),
                  StatCardWidget(
                    label: 'Trips this month',
                    value: '12',
                    icon: Icons.calendar_today_outlined,
                    color: AppColors.primary,
                  ),
                  StatCardWidget(
                    label: 'Hotspots avoided',
                    value: '34',
                    icon: Icons.shield_outlined,
                    color: AppColors.success,
                  ),
                  StatCardWidget(
                    label: 'Best score',
                    value: '94 / 100',
                    icon: Icons.star_rounded,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),

            // ── Recent trips ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _RecentTripsSection(),
            ),

            // ── Settings ─────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _SettingsSection(),
            ),

            // ── Sign out ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(double.infinity, 52),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Safety badge card ─────────────────────────────────────────────────────────

class _SafetyBadgeCard extends StatelessWidget {
  const _SafetyBadgeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your safety rating',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Advanced Driver',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 3 filled + 2 outline stars
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < 3
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: i < 3
                                    ? AppColors.primary
                                    : const Color(0xFFDDE3EA),
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress bar — 3/5 = 60%
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: 0.6,
                            backgroundColor: Color(0xFFEEF1F5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent trips ──────────────────────────────────────────────────────────────

class _RecentTripsSection extends StatelessWidget {
  const _RecentTripsSection();

  static const _trips = [
    (
      origin: 'Home',
      destination: 'Panadura Town',
      meta: 'Today, 8:30 AM · 4.2 km',
      score: 82,
    ),
    (
      origin: 'Office',
      destination: 'Panadura Junction',
      meta: 'Yesterday, 6:10 PM · 2.8 km',
      score: 75,
    ),
    (
      origin: 'Pinwatta',
      destination: 'Aluthgama',
      meta: 'Mon, 9:00 AM · 7.1 km',
      score: 91,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent trips',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _trips.length,
          (i) => _TripRow(
            origin: _trips[i].origin,
            destination: _trips[i].destination,
            meta: _trips[i].meta,
            score: _trips[i].score,
          ),
        ),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  final String origin;
  final String destination;
  final String meta;
  final int score;

  const _TripRow({
    required this.origin,
    required this.destination,
    required this.meta,
    required this.score,
  });

  Color get _scoreColor {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
        ),
        child: Row(
          children: [
            // Route line icon
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 18,
                  color: const Color(0xFFDDE3EA),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textHint,
                      width: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Trip info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$origin → $destination',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Score pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Score: $score',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _scoreColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings ──────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
          ),
          child: Column(
            children: const [
              _SettingRow(
                icon: Icons.notifications_outlined,
                label: 'Alert preferences',
              ),
              _SettingRow(
                icon: Icons.language_outlined,
                label: 'Language',
                rightText: 'English / සිංහල',
              ),
              _SettingRow(
                icon: Icons.lock_outline,
                label: 'Privacy',
              ),
              _SettingRow(
                icon: Icons.info_outline,
                label: 'About SafeNav',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? rightText;
  final bool isLast;

  const _SettingRow({
    required this.icon,
    required this.label,
    this.rightText,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEF1F5), width: 0.5),
                ),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (rightText != null) ...[
              Text(
                rightText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
