import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/sensor_service.dart';
import '../../../core/theme/app_colors.dart';

class RouteOptionsSheet extends StatefulWidget {
  final String destination;
  final double? originLat;
  final double? originLng;
  final double destLat;
  final double destLng;

  const RouteOptionsSheet({
    super.key,
    required this.destination,
    this.originLat,
    this.originLng,
    required this.destLat,
    required this.destLng,
  });

  @override
  State<RouteOptionsSheet> createState() => _RouteOptionsSheetState();
}

class _RouteOptionsSheetState extends State<RouteOptionsSheet> {
  int _selectedIndex = 0;

  void _fetchRoutes(AppProvider p) {
    p.fetchRouteSafety(
      originLat: widget.originLat ?? p.originLat ?? 6.7133,
      originLng: widget.originLng ?? p.originLng ?? 79.9063,
      destLat: widget.destLat,
      destLng: widget.destLng,
      destinationName: widget.destination,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchRoutes(context.read<AppProvider>());
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDragHandle(),
            _buildHeader(context),
            const SizedBox(height: 4),
            if (appProvider.isLoadingRoute)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (appProvider.currentRoutes.isEmpty)
              _buildErrorState(appProvider)
            else
              _buildRouteList(appProvider),
            const SizedBox(height: 16),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteList(AppProvider appProvider) {
    final routes = appProvider.currentRoutes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < routes.length; i++) ...[
            _RouteCard(
              route: routes[i],
              isSelected: _selectedIndex == i,
              isSafest: i == 0,
              onTap: () {
                setState(() => _selectedIndex = i);
                appProvider.selectRoute(i);
              },
            ),
            if (i < routes.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(AppProvider appProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'Could not load route data. Check server connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _fetchRoutes(appProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDE3EA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dest = widget.destination.trim().isEmpty
        ? 'Your destination'
        : widget.destination.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your route',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap a route to preview it on the map',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dest,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                context.read<SensorService>().startTrip(widget.destination);
                Navigator.pop(context);
              },
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
              child: const Text('Start Navigation'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ── Route card ────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final bool isSelected;
  final bool isSafest;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.isSafest,
    required this.onTap,
  });

  Color _barColor(double score) {
    if (score < 40) return const Color(0xFF00C06A);
    if (score < 70) return const Color(0xFFFFB300);
    return const Color(0xFFFF3B5C);
  }

  @override
  Widget build(BuildContext context) {
    final label = route['label'] as String? ?? 'Route';
    final riskScore = (route['risk_score'] as num?)?.toDouble() ?? 0.0;
    final hotspotCount = (route['hotspot_count'] as num?)?.toInt() ?? 0;
    final badge = route['recommendation_badge'] as String?;
    final durationMin = (route['duration_min'] as num?)?.toInt() ?? 0;
    final distanceKm =
        (route['total_distance_km'] as num?)?.toDouble() ?? 0.0;
    final hotspots = (route['hotspots_on_path'] as List<dynamic>?) ?? [];
    final barColor = _barColor(riskScore);

    final causes = <String>[];
    for (final h in hotspots.take(2)) {
      if (h is Map<String, dynamic>) {
        final topCauses = h['top_causes'] as List<dynamic>?;
        if (topCauses != null && topCauses.isNotEmpty) {
          causes.add(topCauses[0].toString());
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.45)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE8EDF2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: barColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (badge != null && badge.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            if (isSafest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'A* algorithm',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Meta row
                        Row(
                          children: [
                            const Icon(Icons.straighten_outlined,
                                size: 12, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.access_time_outlined,
                                size: 12, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '$durationMin min',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        // Risk bar
                        Row(
                          children: [
                            const Text(
                              'Risk',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textHint),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 6,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: riskScore / 100,
                                    backgroundColor:
                                        const Color(0xFFE8EDF2),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            barColor),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${riskScore.toInt()}/100',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Factors row
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 9, color: barColor),
                                const SizedBox(width: 3),
                                Text(
                                  '$hotspotCount hotspots',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            ...causes.map(
                              (c) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_outlined,
                                      size: 9, color: AppColors.warning),
                                  const SizedBox(width: 3),
                                  Text(
                                    c,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: _RadioCircle(selected: isSelected)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioCircle extends StatelessWidget {
  final bool selected;
  const _RadioCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFCDD5DE),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 12)
          : null,
    );
  }
}
