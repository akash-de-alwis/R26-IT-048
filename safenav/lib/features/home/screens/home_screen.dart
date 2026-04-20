import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/route_options_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      await _flyToLocation(pos.longitude, pos.latitude);
    } catch (_) {}
  }

  void _showRouteOptionsSheet(String destination) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RouteOptionsSheet(destination: destination),
    );
  }

  Future<void> _flyToLocation(double lng, double lat) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: AppConstants.defaultZoom,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: AppColors.primary.toARGB32(),
        pulsingMaxRadius: 50.0,
      ),
    );

    await _addHotspotMarkers(map);

    if (_currentPosition != null) {
      await _flyToLocation(_currentPosition!.longitude, _currentPosition!.latitude);
    }
  }

  Future<void> _addHotspotMarkers(MapboxMap map) async {
    final manager = await map.annotations.createCircleAnnotationManager();

    final annotations = AppConstants.hotspotData.map((h) {
      final score = h['riskScore'] as int;
      final int color;
      final double radius;

      if (score >= 70) {
        color = AppColors.hotspotHigh.toARGB32();
        radius = 8.0;
      } else if (score >= 40) {
        color = AppColors.hotspotMed.toARGB32();
        radius = 7.0;
      } else {
        color = AppColors.hotspotLow.toARGB32();
        radius = 6.0;
      }

      return CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(h['lng'] as double, h['lat'] as double),
        ),
        circleColor: color,
        circleRadius: radius,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleOpacity: 0.92,
      );
    }).toList();

    await manager.createMulti(annotations);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── Full-screen map ──────────────────────────────────────────
            MapWidget(
              key: const ValueKey('homeMap'),
              styleUri: AppConstants.mapboxStyle,
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates:
                      Position(AppConstants.defaultLng, AppConstants.defaultLat),
                ),
                zoom: AppConstants.defaultZoom,
              ),
            ),

            // ── Top overlay: header + legend ─────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _HeaderCard(),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _LegendRow(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Re-center FAB ────────────────────────────────────────────
            Positioned(
              right: 16,
              bottom: 200 + bottomPadding,
              child: _RecenterButton(
                onTap: () {
                  if (_currentPosition != null) {
                    _flyToLocation(
                      _currentPosition!.longitude,
                      _currentPosition!.latitude,
                    );
                  }
                },
              ),
            ),

            // ── Bottom search card ───────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomSearchCard(
                bottomPadding: bottomPadding,
                hotspotCount: AppConstants.hotspotData.length,
                onSearch: _showRouteOptionsSheet,
                onSearchTap: _showRouteOptionsSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          const Text(
            'SafeNav',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendChip(color: AppColors.hotspotHigh, label: 'High'),
          SizedBox(width: 14),
          _LegendChip(color: AppColors.hotspotMed, label: 'Medium'),
          SizedBox(width: 14),
          _LegendChip(color: AppColors.hotspotLow, label: 'Low'),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location,
          color: AppColors.primary,
          size: 22,
        ),
      ),
    );
  }
}

class _BottomSearchCard extends StatelessWidget {
  final double bottomPadding;
  final int hotspotCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSearchTap;

  const _BottomSearchCard({
    required this.bottomPadding,
    required this.hotspotCount,
    required this.onSearch,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDF2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Label
          const Text(
            'Where do you want to go?',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          // Search input
          SearchBarWidget(
            onSubmitted: onSearch,
            onSearchTap: onSearchTap,
          ),
          const SizedBox(height: 12),

          // Quick destination chips
          Row(
            children: [
              _QuickChip(
                icon: Icons.work_outline,
                label: 'Work',
                onTap: () => onSearch('Work'),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () => onSearch('Home'),
              ),
              const SizedBox(width: 8),
              _QuickChip(
                icon: Icons.history,
                label: 'Recent',
                onTap: () => onSearch('Recent'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hotspot warning
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 5),
              Text(
                '$hotspotCount accident hotspots detected nearby',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
