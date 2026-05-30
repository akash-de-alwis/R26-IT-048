import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/providers/app_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../member4_driver_scoring/part1/models/trip_session.dart';
import '../../member4_driver_scoring/part1/services/sensor_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<TripSession>> _tripsFuture;

  static const _tips = [
    'Always check hotspot zones before starting your journey.',
    'Reduce speed at night — 40% of accidents happen after dark.',
    'Avoid overtaking on Galle Road near Panadura junction.',
    'Harsh braking lowers your safety score. Anticipate stops early.',
    'Fatigue increases accident risk by 3×. Rest before long trips.',
    'Use the safest route — it only adds 1–2 minutes on average.',
    'Keep 3 seconds following distance from the vehicle ahead.',
  ];

  @override
  void initState() {
    super.initState();
    _tripsFuture = SensorService.instance.getTripHistory();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning!';
    if (h < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  String _tip() => _tips[DateTime.now().day % _tips.length];

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final app = context.watch<AppProvider>();
    final sensor = context.watch<SensorService>();

    final int highCount, medCount, lowCount;
    if (app.hotspots.isNotEmpty) {
      highCount =
          app.hotspots.where((h) => h.riskLevel.toUpperCase() == 'HIGH').length;
      medCount = app.hotspots
          .where((h) => h.riskLevel.toUpperCase() == 'MEDIUM')
          .length;
      lowCount =
          app.hotspots.where((h) => h.riskLevel.toUpperCase() == 'LOW').length;
    } else {
      highCount = AppConstants.hotspotData
          .where((h) => (h['riskScore'] as int) >= 75)
          .length;
      medCount = AppConstants.hotspotData.where((h) {
        final s = h['riskScore'] as int;
        return s >= 45 && s < 75;
      }).length;
      lowCount = AppConstants.hotspotData
          .where((h) => (h['riskScore'] as int) < 45)
          .length;
    }
    final total = app.hotspots.isNotEmpty
        ? app.hotspots.length
        : AppConstants.hotspotData.length;
    final score = sensor.currentTrip?.safetyScore ?? 78;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Blue hero + overlapping dark card ──────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              _HeroSection(auth: auth, greeting: _greeting()),
              Positioned(
                bottom: -48,
                left: 20,
                right: 20,
                child: _DarkActionsCard(
                  score: score,
                  total: total,
                  onMap: () => context.go(AppConstants.routeMap),
                  onScore: () => context.go(AppConstants.routeScore),
                  onHotspots: () => context.go(AppConstants.routeMap),
                ),
              ),
            ],
          ),

          const SizedBox(height: 68),

          // ── FIXED: Risk Summary title ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Risk Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(AppConstants.routeMap),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2979FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SCROLLABLE: Everything below Risk Summary title ────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Risk stat cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _RiskStatCard(
                          value: highCount,
                          label: 'High Risk',
                          color: const Color(0xFFFF3B5C),
                          bgColor: const Color(0xFFFFF0F3),
                          trend: '+2 this week',
                        ),
                        const SizedBox(width: 10),
                        _RiskStatCard(
                          value: medCount,
                          label: 'Medium Risk',
                          color: const Color(0xFFFFB300),
                          bgColor: const Color(0xFFFFF8E8),
                          trend: 'stable',
                        ),
                        const SizedBox(width: 10),
                        _RiskStatCard(
                          value: lowCount,
                          label: 'Low Risk',
                          color: const Color(0xFF00C06A),
                          bgColor: const Color(0xFFEBFBF3),
                          trend: 'safe zone',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Recent trips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _RecentTripsSection(
                      tripsFuture: _tripsFuture,
                      timeAgo: _timeAgo,
                      onViewAll: () => context.go(AppConstants.routeProfile),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Safety tip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _TipCard(tip: _tip()),
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

// ── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final AuthService auth;
  final String greeting;

  const _HeroSection({required this.auth, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A56CC),
      child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: greeting + bell + avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Bell
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              children: [
                                const Center(
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00C06A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Avatar
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: const Color(0xFF2979FF),
                            backgroundImage: auth.userPhotoUrl.isNotEmpty
                                ? NetworkImage(auth.userPhotoUrl)
                                : null,
                            child: auth.userPhotoUrl.isEmpty
                                ? Text(
                                    auth.userInitials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Headline
                  const Text(
                    'Where are you\ngoing today?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // White search bar
                  GestureDetector(
                    onTap: () => context.go(AppConstants.routeMap),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF1A56CC),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Search destination...',
                            style: TextStyle(
                              color: Color(0xFFADB8C3),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A56CC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
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

// ── Dark actions card ─────────────────────────────────────────────────────────

class _DarkActionsCard extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onMap;
  final VoidCallback onScore;
  final VoidCallback onHotspots;

  const _DarkActionsCard({
    required this.score,
    required this.total,
    required this.onMap,
    required this.onScore,
    required this.onHotspots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151E2D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _DarkActionBtn(
            icon: Icons.map_rounded,
            label: 'Open Map',
            isActive: false,
            onTap: onMap,
          ),
          _DarkActionBtn(
            icon: Icons.shield_rounded,
            label: 'My Score',
            isActive: false,
            onTap: onScore,
          ),
          _DarkActionBtn(
            icon: Icons.warning_amber_rounded,
            label: 'Hotspots',
            isActive: true,
            onTap: onHotspots,
          ),
        ],
      ),
    );
  }
}

class _DarkActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DarkActionBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2979FF)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.70),
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskStatCard extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final Color bgColor;
  final String trend;

  const _RiskStatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEF1F5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF5C6B7A),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trend,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent trips section ──────────────────────────────────────────────────────

class _RecentTripsSection extends StatelessWidget {
  final Future<List<TripSession>> tripsFuture;
  final String Function(DateTime) timeAgo;
  final VoidCallback onViewAll;

  const _RecentTripsSection({
    required this.tripsFuture,
    required this.timeAgo,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Trips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2A),
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: const Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2979FF)),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Color(0xFF2979FF),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<TripSession>>(
          future: tripsFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2979FF),
                  ),
                ),
              );
            }
            final trips = snap.data ?? [];
            if (trips.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.route_outlined,
                          size: 40, color: Color(0xFFB5D4F4)),
                      SizedBox(height: 8),
                      Text(
                        'No trips yet',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF5C6B7A)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final shown = trips.take(3).toList();
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEF1F5)),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  for (int i = 0; i < shown.length; i++) ...[
                    _TripRow(trip: shown[i], timeAgo: timeAgo(shown[i].startTime)),
                    if (i < shown.length - 1)
                      const Divider(height: 1, color: Color(0xFFEEF1F5)),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  final TripSession trip;
  final String timeAgo;

  const _TripRow({required this.trip, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trip.scoreColor.withValues(alpha: 0.10),
            ),
            child: Center(
              child: Text(
                '${trip.safetyScore}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: trip.scoreColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Trip info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.destinationName ?? 'Trip',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${trip.totalDistanceKm.toStringAsFixed(1)} km  ·  ${trip.duration} min',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5C6B7A),
                  ),
                ),
              ],
            ),
          ),
          // Score + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${trip.safetyScore}/100',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: trip.scoreColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeAgo,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFADB8C3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tip card ──────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final String tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2979FF).withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFF2979FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety Tip',
                  style: TextStyle(
                    color: Color(0xFF2979FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 12,
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
