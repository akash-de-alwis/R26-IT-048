import 'dart:math' show sqrt, cos, pi;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../member4_scoring/services/sensor_service.dart';

const _kNearbyRadiusKm = 5.0;

double _distKm(double lat1, double lng1, double lat2, double lng2) {
  const degToRad = pi / 180.0;
  final x = (lng2 - lng1) * degToRad * cos((lat1 + lat2) / 2 * degToRad);
  final y = (lat2 - lat1) * degToRad;
  return 6371.0 * sqrt(x * x + y * y);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeInitGps());
  }

  Future<void> _maybeInitGps() async {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    if (app.originLat != null) return;

    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) return;

      final pos = await geo.Geolocator.getLastKnownPosition() ??
          await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 8));

      if (mounted) app.setGpsLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final app = context.watch<AppProvider>();
    final sensor = context.watch<SensorService>();

    final firstName = auth.userName.split(' ').first;
    final score = (sensor.currentTrip?.safetyScore ?? 78).toDouble();

    final lat = app.originLat;
    final lng = app.originLng;

    final nearby = (lat != null && lng != null)
        ? app.hotspots
            .where((h) =>
                _distKm(lat, lng, h.latitude, h.longitude) <= _kNearbyRadiusKm)
            .toList()
        : <dynamic>[];

    final nearbyHigh = (lat != null)
        ? app.hotspots
            .where((h) =>
                h.riskLevel.toUpperCase() == 'HIGH' &&
                _distKm(lat, lng!, h.latitude, h.longitude) <= _kNearbyRadiusKm)
            .length
        : 0;
    final nearbyMed = (lat != null)
        ? app.hotspots
            .where((h) =>
                h.riskLevel.toUpperCase() == 'MEDIUM' &&
                _distKm(lat, lng!, h.latitude, h.longitude) <= _kNearbyRadiusKm)
            .length
        : 0;
    final nearbyLow = (lat != null)
        ? app.hotspots
            .where((h) =>
                h.riskLevel.toUpperCase() == 'LOW' &&
                _distKm(lat, lng!, h.latitude, h.longitude) <= _kNearbyRadiusKm)
            .length
        : 0;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(greeting: greeting, firstName: firstName),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    _ScoreCard(score: score),
                    const SizedBox(height: 16),
                    _HotspotSummaryCard(
                      high: nearbyHigh,
                      medium: nearbyMed,
                      low: nearbyLow,
                      total: nearby.length,
                      locationReady: lat != null,
                      loading: app.isLoadingHotspots,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionsRow(),
                    const SizedBox(height: 16),
                    _TipsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String greeting;
  final String firstName;

  const _Header({required this.greeting, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 22,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score card ───────────────────────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final double score;
  const _ScoreCard({required this.score});

  Color get _scoreColor {
    if (score >= AppConstants.scoreExcellent) return AppColors.success;
    if (score >= AppConstants.scoreGood) return AppColors.primary;
    if (score >= AppConstants.scoreFair) return AppColors.warning;
    return AppColors.danger;
  }

  String get _scoreLabel {
    if (score >= AppConstants.scoreExcellent) return 'Excellent';
    if (score >= AppConstants.scoreGood) return 'Good';
    if (score >= AppConstants.scoreFair) return 'Fair';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 7,
                  backgroundColor: const Color(0xFFEEF2F8),
                  valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                ),
                Text(
                  score.toInt().toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Score',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _scoreLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap My Score for full breakdown',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go(AppConstants.routeScore),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hotspot summary card ─────────────────────────────────────────────────────
class _HotspotSummaryCard extends StatelessWidget {
  final int high;
  final int medium;
  final int low;
  final int total;
  final bool locationReady;
  final bool loading;

  const _HotspotSummaryCard({
    required this.high,
    required this.medium,
    required this.low,
    required this.total,
    required this.locationReady,
    this.loading = false,
  });

  Color get _heroColor {
    if (total == 0) return AppColors.success;
    if (high > 0) return AppColors.danger;
    if (medium > 0) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with GPS status
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.danger),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Hotspots Near You',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: locationReady ? AppColors.success : AppColors.textHint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                locationReady ? 'GPS' : 'No GPS',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body
          if (loading)
            _buildPlaceholder(Icons.hourglass_empty, 'Loading hotspots...')
          else if (!locationReady)
            _buildPlaceholder(
                Icons.gps_off, 'Enable GPS to see hotspots in your area')
          else ...[
            // Hero count row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: _heroColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'accident hotspots',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'within ${_kNearbyRadiusKm.toInt()} km of you',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Risk breakdown chips
            Row(
              children: [
                Expanded(
                  child: _RiskCountChip(
                    count: high,
                    label: 'High',
                    color: AppColors.hotspotHigh,
                    bgColor: const Color(0xFFFFF0F3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RiskCountChip(
                    count: medium,
                    label: 'Medium',
                    color: AppColors.hotspotMed,
                    bgColor: const Color(0xFFFFF8E6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RiskCountChip(
                    count: low,
                    label: 'Low',
                    color: AppColors.hotspotLow,
                    bgColor: const Color(0xFFE6FAF2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // View on Map button
            GestureDetector(
              onTap: () => context.go(AppConstants.routeMap),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'View on Map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(IconData icon, String message) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textHint, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RiskCountChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bgColor;

  const _RiskCountChip({
    required this.count,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions row ────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.map_outlined,
            label: 'Open Map',
            color: AppColors.primary,
            bgColor: AppColors.primaryLight,
            onTap: () => context.go(AppConstants.routeMap),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.shield_outlined,
            label: 'My Score',
            color: AppColors.success,
            bgColor: const Color(0xFFE6FAF2),
            onTap: () => context.go(AppConstants.routeScore),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.account_circle_outlined,
            label: 'Profile',
            color: const Color(0xFF9C27B0),
            bgColor: const Color(0xFFF3E5F5),
            onTap: () => context.go(AppConstants.routeProfile),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Safety tips card ─────────────────────────────────────────────────────────
class _TipsCard extends StatelessWidget {
  const _TipsCard();

  static const _tips = [
    'Maintain a 3-second following distance at all times.',
    'Reduce speed near junctions marked as high-risk zones.',
    'Avoid distractions — keep your phone away while driving.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56CC), Color(0xFF2979FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Tip',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.4,
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
