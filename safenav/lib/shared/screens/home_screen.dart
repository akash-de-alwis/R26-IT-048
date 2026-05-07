import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/hotspot_model.dart';
import '../../core/providers/app_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/offline_map_service.dart';
import '../../member3_alerts/services/alert_service.dart';
import '../../member4_scoring/models/trip_session.dart';
import '../../member4_scoring/services/sensor_service.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/widgets/hotspot_marker_painter.dart';
import '../../features/home/widgets/place_search_sheet.dart';
import '../../member2_routing/widgets/route_layer_widget.dart';
import '../../member2_routing/widgets/route_options_sheet.dart';
import '../../features/home/widgets/search_bar_widget.dart';
import '../../core/services/geocoding_service.dart';
import 'trip_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;
  double? _currentLat;
  double? _currentLng;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotationManager? _destinationPointAnnotationManager;
  AppProvider? _appProvider;
  StreamSubscription<geo.Position>? _positionSub;
  bool _hasFlewToLocation = false;
  bool _isLocating = false;

  String? _destinationLabel;

  // Map pick mode
  bool _isPickingLocation = false;
  bool _pickingForOrigin = false;
  bool _isReverseGeocoding = false;

  // Track what was last drawn to avoid redundant redraws
  int _lastDrawnRouteCount = 0;
  int _lastDrawnSelectedIndex = -1;
  int _lastDrawnGeoCount = -1;

  List<Map<String, dynamic>> _activeAlerts = [];
  AlertService? _alertServiceRef;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    if (_appProvider == null) {
      _appProvider = provider;
      _appProvider!.addListener(_onHotspotsUpdated);
      // Deferred until home screen is reached — not during onboarding
      _appProvider!.initializeApp();
      context.read<OfflineMapService>().checkIfAlreadyDownloaded();
    }
    final alertSvc = context.read<AlertService>();
    if (_alertServiceRef == null) {
      _alertServiceRef = alertSvc;
      _alertServiceRef!.addListener(_onAlertsChanged);
      alertSvc.startAlertMonitoring();
    }
  }

  void _onAlertsChanged() {
    if (!mounted) return;
    setState(() {
      final svc = _alertServiceRef;
      _activeAlerts = (svc != null && svc.isEnabled)
          ? List<Map<String, dynamic>>.from(svc.activeAlerts)
          : [];
    });
  }

  @override
  void dispose() {
    _alertServiceRef?.removeListener(_onAlertsChanged);
    _positionSub?.cancel();
    _appProvider?.removeListener(_onHotspotsUpdated);
    super.dispose();
  }

  void _onHotspotsUpdated() {
    if (!mounted) return;
    if (_pointAnnotationManager != null) _refreshHotspotAnnotations();
    _maybeDrawRoutes();
  }


  void _maybeDrawRoutes() {
    final provider = _appProvider;
    final map = _mapboxMap;
    if (provider == null || map == null) return;

    if (provider.currentRoutes.isEmpty) {
      // Reset so next route load always triggers a fresh draw
      _lastDrawnRouteCount = 0;
      _lastDrawnSelectedIndex = -1;
      _lastDrawnGeoCount = -1;
      return;
    }

    final routeCount = provider.currentRoutes.length;
    final selectedIndex = provider.selectedRouteIndex;
    final geoCount = provider.roadGeometries.length;

    // Skip if nothing changed since last draw
    if (routeCount == _lastDrawnRouteCount &&
        selectedIndex == _lastDrawnSelectedIndex &&
        geoCount == _lastDrawnGeoCount) {
      return;
    }

    _lastDrawnRouteCount = routeCount;
    _lastDrawnSelectedIndex = selectedIndex;
    _lastDrawnGeoCount = geoCount;

    drawRoutesOnMap(
      map,
      provider.currentRoutes,
      selectedIndex,
      roadGeometries: provider.roadGeometries.isNotEmpty
          ? provider.roadGeometries
          : null,
    );
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }

      if (!mounted) return;
      setState(() => _isLocating = true);

      // Force fresh satellite fix — skips stale cached position
      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.bestForNavigation,
        ).timeout(const Duration(seconds: 15));
        if (mounted) _applyPosition(pos, fly: true);
      } catch (_) {}

      // Continuous updates
      _positionSub = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen(
        (pos) {
          if (!mounted) return;
          _applyPosition(pos, fly: !_hasFlewToLocation);
          setState(() => _isLocating = false);
        },
        onError: (_) {
          if (mounted) setState(() => _isLocating = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _applyPosition(geo.Position pos, {bool fly = false}) {
    setState(() {
      _currentPosition = pos;
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
    });
    if (_appProvider?.isUsingGps == true) {
      _appProvider?.setGpsLocation(pos.latitude, pos.longitude);
    }
    if (fly && !_hasFlewToLocation) {
      _hasFlewToLocation = true;
      _flyToLocation(pos.longitude, pos.latitude);
    }
  }

  // ── Map pick mode ─────────────────────────────────────────────────────────

  void _enterPickMode({required bool isOrigin}) {
    setState(() {
      _isPickingLocation = true;
      _pickingForOrigin = isOrigin;
    });
  }

  void _cancelPickMode() => setState(() => _isPickingLocation = false);

  void _onMapTap(MapContentGestureContext context) {
    if (!_isPickingLocation) return;
    final lat = context.point.coordinates.lat.toDouble();
    final lng = context.point.coordinates.lng.toDouble();
    _handlePickedCoordinates(lat, lng);
  }

  Future<void> _confirmPickedLocation() async {
    if (_mapboxMap == null) return;
    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final lat = cameraState.center.coordinates.lat.toDouble();
      final lng = cameraState.center.coordinates.lng.toDouble();
      _handlePickedCoordinates(lat, lng);
    } catch (_) {}
  }

  Future<void> _handlePickedCoordinates(double lat, double lng) async {
    if (_isReverseGeocoding) return;
    setState(() => _isReverseGeocoding = true);
    try {
      final name = await ApiService.instance.reverseGeocode(lat, lng);
      final label = name ?? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      if (!mounted) return;
      setState(() {
        _isPickingLocation = false;
        _isReverseGeocoding = false;
      });
      if (_pickingForOrigin) {
        _appProvider?.setManualLocation(lat, lng, label);
      } else {
        _showRouteOptionsSheet(label, lat, lng);
      }
    } catch (_) {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  // ── Place selected (inline search bar) ───────────────────────────────────

  Future<void> _onPlaceSelected(PlaceSuggestion place) async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(place.longitude, place.latitude)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
    await _setDestinationMarker(place.latitude, place.longitude);
    _showRouteOptionsSheet(place.placeName, place.latitude, place.longitude);
  }

  Future<void> _setDestinationMarker(double lat, double lng) async {
    final manager = _destinationPointAnnotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    final markerImage = await HotspotMarkerPainter.createDestinationMarker();
    await manager.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: markerImage,
      iconSize: 1.0,
      iconAnchor: IconAnchor.CENTER,
    ));
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  void _openOriginSearch() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaceSearchSheet(
        title: 'Set your location',
        hint: 'Search for your starting point…',
        nearLat: _currentPosition?.latitude,
        nearLng: _currentPosition?.longitude,
        showGpsOption: true,
        onUseGps: () {
          _appProvider?.resetToGps();
          if (_currentPosition != null) {
            _appProvider?.setGpsLocation(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            );
          }
          Navigator.pop(context);
        },
        onPickOnMap: () {
          Navigator.pop(context);
          _enterPickMode(isOrigin: true);
        },
        onSelected: (name, lat, lng) {
          _appProvider?.setManualLocation(lat, lng, name);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openDestinationSearch() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlaceSearchSheet(
        title: 'Where to?',
        hint: 'Search for a destination…',
        nearLat: _currentPosition?.latitude,
        nearLng: _currentPosition?.longitude,
        onPickOnMap: () {
          Navigator.pop(context);
          _enterPickMode(isOrigin: false);
        },
        onSelected: (name, lat, lng) {
          Navigator.pop(context);
          _showRouteOptionsSheet(name, lat, lng);
        },
      ),
    );
  }

  void _showRouteOptionsSheet(String destination, double destLat, double destLng) {
    if (!mounted) return;
    setState(() {
      _destinationLabel = destination;
      _lastDrawnRouteCount = 0;
      _lastDrawnSelectedIndex = -1;
      _lastDrawnGeoCount = -1;
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RouteOptionsSheet(
        destination: destination,
        originLat: _currentLat,
        originLng: _currentLng,
        destLat: destLat,
        destLng: destLng,
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────

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
    _pointAnnotationManager =
        await map.annotations.createPointAnnotationManager();
    _destinationPointAnnotationManager =
        await map.annotations.createPointAnnotationManager();
    if (!mounted) return;
    final hotspots = _appProvider?.hotspots ?? [];
    if (hotspots.isNotEmpty) await _buildAnnotations(hotspots);
    if (_currentPosition != null) {
      await _flyToLocation(
          _currentPosition!.longitude, _currentPosition!.latitude);
    }
  }

  Future<void> _refreshHotspotAnnotations() async {
    final manager = _pointAnnotationManager;
    if (manager == null) return;
    final hotspots = _appProvider?.hotspots ?? [];
    await manager.deleteAll();
    await _buildAnnotations(hotspots);
  }

  Future<void> _buildAnnotations(List<HotspotModel> hotspots) async {
    final manager = _pointAnnotationManager;
    if (manager == null || hotspots.isEmpty) return;

    final highImg = await HotspotMarkerPainter.createHotspotMarker('HIGH');
    final medImg = await HotspotMarkerPainter.createHotspotMarker('MEDIUM');
    final lowImg = await HotspotMarkerPainter.createHotspotMarker('LOW');

    final annotations = hotspots.map((h) {
      final img = switch (h.riskLevel.toUpperCase()) {
        'HIGH' => highImg,
        'MEDIUM' => medImg,
        _ => lowImg,
      };
      return PointAnnotationOptions(
        geometry: Point(coordinates: Position(h.longitude, h.latitude)),
        image: img,
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
      );
    }).toList();

    await manager.createMulti(annotations);
  }

  // ── Behavior alert data ───────────────────────────────────────────────────

  List<({Color color, IconData icon, String message, String badge,
      String description, String tip})>
      _buildBehaviorAlerts(TripSession trip) {
    final list = <({
      Color color,
      IconData icon,
      String message,
      String badge,
      String description,
      String tip,
    })>[];

    if (trip.overSpeedingCount >= 1)
      list.add((
        color: const Color(0xFFFF3B5C),
        icon: Icons.speed,
        message: 'Overspeeding — reduce speed immediately',
        badge: 'CRITICAL',
        description:
            'You exceeded safe speed limits ${trip.overSpeedingCount} time${trip.overSpeedingCount > 1 ? "s" : ""} this trip. High speed dramatically increases stopping distance and crash severity.',
        tip:
            'Maintain a steady speed, check your speedometer regularly, and follow posted speed signs.',
      ));

    if (trip.harshBrakingCount >= 3)
      list.add((
        color: const Color(0xFFFF3B5C),
        icon: Icons.warning_amber_rounded,
        message:
            'Harsh braking ${trip.harshBrakingCount}× — increase following distance',
        badge: 'WARNING',
        description:
            '${trip.harshBrakingCount} sudden stops detected this trip. Repeated hard braking raises rear-collision risk and tyre wear.',
        tip:
            'Keep at least a 3-second gap from the vehicle ahead so you can brake smoothly.',
      ));
    else if (trip.harshBrakingCount > 0)
      list.add((
        color: const Color(0xFFFFB300),
        icon: Icons.warning_amber_rounded,
        message: 'Harsh braking detected — brake more gradually',
        badge: 'CAUTION',
        description:
            'A sudden brake was detected. Hard stops increase rear-collision risk, especially in traffic.',
        tip:
            'Anticipate stops early and press the brake pedal smoothly and progressively.',
      ));

    if (trip.sharpTurnCount >= 2)
      list.add((
        color: const Color(0xFFFFB300),
        icon: Icons.turn_right,
        message: 'Sharp turns ${trip.sharpTurnCount}× — slow before corners',
        badge: 'CAUTION',
        description:
            '${trip.sharpTurnCount} sharp turns recorded. Turning at high speed reduces tyre grip and can cause skidding.',
        tip:
            'Reduce speed before entering a corner, then accelerate gently as you exit.',
      ));

    if (trip.safetyScore < 50)
      list.add((
        color: const Color(0xFFFF3B5C),
        icon: Icons.shield_outlined,
        message: 'Score critical: ${trip.safetyScore}/100 — drive carefully',
        badge: 'CRITICAL',
        description:
            'Your safety score has dropped to ${trip.safetyScore}/100 due to multiple unsafe events this trip.',
        tip:
            'Slow down, increase following distance, and avoid sudden maneuvers to recover your score.',
      ));

    return list;
  }

  void _showBehaviorAlertDetail(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String badge,
    required String message,
    required String description,
    required String tip,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BehaviorAlertSheet(
        color: color,
        icon: icon,
        badge: badge,
        message: message,
        description: description,
        tip: tip,
      ),
    );
  }

  void _showProximityAlertDetail(
      BuildContext context, Map<String, dynamic> alert) {
    final hex = (alert['alert_color'] as String? ?? '#2979FF')
        .replaceAll('#', '0xFF');
    final color = Color(int.parse(hex));
    final severity = alert['severity'] as String? ?? 'CAUTION';
    final icon = switch (severity) {
      'CRITICAL' => Icons.warning_rounded,
      'WARNING' => Icons.warning_amber_rounded,
      _ => Icons.info_outline,
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProximityAlertSheet(
        alert: alert,
        color: color,
        icon: icon,
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _legendChip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0D1B2A),
              ),
            ),
          ],
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  Future<void> _endTrip(BuildContext context) async {
    final sensorService = context.read<SensorService>();
    final alertService = context.read<AlertService>();
    final nav = Navigator.of(context, rootNavigator: true);
    alertService.clearAlertsForNewTrip();
    final trip = await sensorService.endTrip();
    if (!mounted || trip == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => TripSummaryScreen(trip: trip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final sensorService = context.watch<SensorService>();
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
              onTapListener: _onMapTap,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                      AppConstants.defaultLng, AppConstants.defaultLat),
                ),
                zoom: AppConstants.defaultZoom,
              ),
            ),

            // ── Normal top overlay ───────────────────────────────────────
            if (!_isPickingLocation && !sensorService.isTracking)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!appProvider.isServerConnected)
                        const _ServerBanner(),
                      _LocationInputCard(
                        originLabel: appProvider.originLabel,
                        destinationLabel: _destinationLabel,
                        isUsingGps: appProvider.isUsingGps,
                        isLocating: _isLocating,
                        onOriginTap: _openOriginSearch,
                        onDestinationTap: _openDestinationSearch,
                      ),
                      const SizedBox(height: 8),
                      SearchBarWidget(onPlaceSelected: _onPlaceSelected),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _legendChip('High', const Color(0xFFFF3B5C)),
                          const SizedBox(width: 6),
                          _legendChip('Medium', const Color(0xFFFFB300)),
                          const SizedBox(width: 6),
                          _legendChip('Low', const Color(0xFF00C06A)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 12, color: Color(0xFFFFB300)),
                                const SizedBox(width: 4),
                                Text(
                                  '${appProvider.hotspots.length} hotspots',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                ),
                                if (appProvider.isLoadingHotspots) ...[
                                  const SizedBox(width: 6),
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── Navigation active banner ─────────────────────────────────
            if (!_isPickingLocation && sensorService.isTracking)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _NavActiveBanner(onEndTrip: () => _endTrip(context)),
                ),
              ),


            // ── Pick mode: floating pin at center ────────────────────────
            if (_isPickingLocation)
              IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2979FF), Color(0xFF1557D6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x502979FF),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.my_location,
                            color: Colors.white, size: 24),
                      ),
                      Container(width: 2, height: 10, color: AppColors.primary),
                      Container(
                        width: 10,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Pick mode: instruction banner at top ─────────────────────
            if (_isPickingLocation)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _cancelPickMode,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back,
                              size: 20, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _pickingForOrigin
                                ? 'Move map to set starting point'
                                : 'Move map to set destination',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Re-center FAB (hidden while picking) ─────────────────────
            if (!_isPickingLocation)
              Positioned(
                right: 16,
                bottom: 180 + bottomPadding,
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

            // ── Pick mode: confirm button at bottom ──────────────────────
            if (_isPickingLocation)
              Positioned(
                bottom: 24 + bottomPadding,
                left: 24,
                right: 24,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isReverseGeocoding ? null : _confirmPickedLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: const StadiumBorder(),
                      ),
                      child: _isReverseGeocoding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _pickingForOrigin
                                  ? 'Confirm Starting Point'
                                  : 'Confirm Destination',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

            // ── Bottom strip (normal mode) ───────────────────────────────
            if (!_isPickingLocation)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomStrip(
                  bottomPadding: bottomPadding,
                  hotspotCount: appProvider.hotspots.length,
                  highRiskCount: appProvider.hotspots
                      .where((h) => h.riskLevel.toUpperCase() == 'HIGH')
                      .length,
                  onQuickSearch: _openDestinationSearch,
                ),
              ),

            // ── Compact alert panel (bottom, above FAB) ──────────────────
            if (!_isPickingLocation)
              Positioned(
                bottom: 220 + bottomPadding,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Behavior alerts — top priority, 1 card max
                    if (sensorService.isTracking &&
                        sensorService.currentTrip != null)
                      ..._buildBehaviorAlerts(sensorService.currentTrip!)
                          .take(1)
                          .map((a) => _CompactAlertCard(
                                color: a.color,
                                icon: a.icon,
                                message: a.message,
                                badge: a.badge,
                                onTap: () => _showBehaviorAlertDetail(
                                  context,
                                  color: a.color,
                                  icon: a.icon,
                                  badge: a.badge,
                                  message: a.message,
                                  description: a.description,
                                  tip: a.tip,
                                ),
                              )),
                    // Proximity alerts — 2 cards max
                    ..._activeAlerts.take(2).map((alert) {
                      final hex =
                          (alert['alert_color'] as String? ?? '#2979FF')
                              .replaceAll('#', '0xFF');
                      final color = Color(int.parse(hex));
                      final severity =
                          alert['severity'] as String? ?? 'CAUTION';
                      final icon = switch (severity) {
                        'CRITICAL' => Icons.warning_rounded,
                        'WARNING' => Icons.warning_amber_rounded,
                        _ => Icons.info_outline,
                      };
                      return _CompactAlertCard(
                        color: color,
                        icon: icon,
                        message: alert['message_en'] as String? ?? '',
                        badge: severity,
                        onTap: () =>
                            _showProximityAlertDetail(context, alert),
                        onDismiss: () => _alertServiceRef?.dismissAlert(
                          alert['hotspot_id'] as int,
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Compact alert card (map overlay) ─────────────────────────────────────────

class _CompactAlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final String badge;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _CompactAlertCard({
    required this.color,
    required this.icon,
    required this.message,
    required this.badge,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            // Message + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2332),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Dismiss button
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

// ── Alert detail bottom sheets ────────────────────────────────────────────────

class _BehaviorAlertSheet extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String badge;
  final String message;
  final String description;
  final String tip;

  const _BehaviorAlertSheet({
    required this.color,
    required this.icon,
    required this.badge,
    required this.message,
    required this.description,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Driving Behaviour Alert',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2332),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 16),
          // What happened
          _SheetSection(
            icon: Icons.info_outline_rounded,
            label: 'What happened',
            color: color,
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4A5568),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // How to improve
          _SheetSection(
            icon: Icons.lightbulb_outline_rounded,
            label: 'How to improve',
            color: const Color(0xFF00C06A),
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4A5568),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Got it',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProximityAlertSheet extends StatelessWidget {
  final Map<String, dynamic> alert;
  final Color color;
  final IconData icon;

  const _ProximityAlertSheet({
    required this.alert,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] as String? ?? 'CAUTION';
    final message = alert['message_en'] as String? ?? '';
    final explanation = alert['explanation_en'] as String? ?? '';
    final roadName = alert['road_name'] as String? ?? '';
    final distanceM = (alert['distance_m'] as num?)?.toInt() ?? 0;
    final riskScore = (alert['risk_score'] as num?)?.toDouble() ?? 0.0;
    final accidentCount = alert['accident_count'] as int? ?? 0;
    final topCause = alert['top_cause'] as String? ?? '';
    final timePeriod = alert['time_period'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        severity,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roadName.isNotEmpty ? roadName : 'Accident Hotspot',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2332),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${distanceM}m ahead',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A9BB0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Message
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SheetSection(
              icon: Icons.analytics_outlined,
              label: 'Why this spot is dangerous',
              color: color,
              child: Text(
                explanation,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A5568),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              if (riskScore > 0)
                Expanded(
                    child: _StatChip(
                  icon: Icons.bar_chart_rounded,
                  label: 'Risk',
                  value: '${riskScore.toInt()}/100',
                  color: color,
                )),
              if (accidentCount > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                    child: _StatChip(
                  icon: Icons.history_rounded,
                  label: 'Accidents',
                  value: '$accidentCount',
                  color: color,
                )),
              ],
              if (topCause.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                    child: _StatChip(
                  icon: Icons.gpp_maybe_outlined,
                  label: 'Top cause',
                  value: topCause,
                  color: color,
                )),
              ],
            ],
          ),
          if (timePeriod.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: Color(0xFF8A9BB0)),
                const SizedBox(width: 5),
                Text(
                  'Peak risk: $timePeriod',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8A9BB0)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Stay Alert',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget child;

  const _SheetSection({
    required this.icon,
    required this.label,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF8A9BB0)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2332),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Location input card (top) ─────────────────────────────────────────────────

class _LocationInputCard extends StatelessWidget {
  final String originLabel;
  final String? destinationLabel;
  final bool isUsingGps;
  final bool isLocating;
  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;

  const _LocationInputCard({
    required this.originLabel,
    required this.destinationLabel,
    required this.isUsingGps,
    required this.isLocating,
    required this.onOriginTap,
    required this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x1A2979FF), blurRadius: 24, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── FROM row ───────────────────────────────────────────────────
          GestureDetector(
            onTap: onOriginTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 6),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isUsingGps
                          ? const Color(0xFFE3EEFF)
                          : const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUsingGps ? Icons.my_location : Icons.place_outlined,
                      color: isUsingGps
                          ? AppColors.primary
                          : AppColors.hotspotMed,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FROM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHint,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isLocating && isUsingGps)
                          Row(
                            children: const [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: AppColors.primary),
                              ),
                              SizedBox(width: 6),
                              Text('Getting location…',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textHint)),
                            ],
                          )
                        else
                          Text(
                            originLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textHint),
                ],
              ),
            ),
          ),

          // ── Dashed connector ───────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(left: 31),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _DashedConnector(),
            ),
          ),

          // ── TO row ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: onDestinationTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: destinationLabel != null
                          ? const Color(0xFFFFEEF1)
                          : const Color(0xFFF5F7FA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: destinationLabel != null
                          ? AppColors.danger
                          : AppColors.textHint,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHint,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destinationLabel ?? 'Where to?',
                          style: TextStyle(
                            fontSize: 13,
                            color: destinationLabel != null
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                            fontWeight: destinationLabel != null
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2979FF), Color(0xFF1557D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search, color: Colors.white, size: 17),
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

// ── Navigation active banner ──────────────────────────────────────────────────

class _NavActiveBanner extends StatefulWidget {
  final VoidCallback onEndTrip;
  const _NavActiveBanner({required this.onEndTrip});

  @override
  State<_NavActiveBanner> createState() => _NavActiveBannerState();
}

class _NavActiveBannerState extends State<_NavActiveBanner> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    final start = context.read<SensorService>().currentTrip?.startTime;
    if (start != null) {
      _elapsedSeconds = DateTime.now().difference(start).inSeconds;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final speed = context.watch<SensorService>().currentSpeedKmh;
    return Container(
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B6E), Color(0xFF1557D6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1557D6).withValues(alpha: 0.50),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF69FF8B),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Trip in Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _fmt(_elapsedSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${speed.toStringAsFixed(0)} km/h',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onEndTrip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 5),
                  Text(
                    'End Trip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
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

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF00E676),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom strip ──────────────────────────────────────────────────────────────

class _BottomStrip extends StatelessWidget {
  final double bottomPadding;
  final int hotspotCount;
  final int highRiskCount;
  final VoidCallback onQuickSearch;

  const _BottomStrip({
    required this.bottomPadding,
    required this.hotspotCount,
    required this.highRiskCount,
    required this.onQuickSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickChip(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: onQuickSearch),
                const SizedBox(width: 8),
                _QuickChip(
                    icon: Icons.work_rounded,
                    label: 'Work',
                    onTap: onQuickSearch),
                const SizedBox(width: 8),
                _QuickChip(
                    icon: Icons.history_rounded,
                    label: 'Recent',
                    onTap: onQuickSearch),
                const SizedBox(width: 8),
                _QuickChip(
                    icon: Icons.local_hospital_rounded,
                    label: 'Hospital',
                    onTap: onQuickSearch),
                const SizedBox(width: 8),
                _QuickChip(
                    icon: Icons.local_gas_station_rounded,
                    label: 'Fuel',
                    onTap: onQuickSearch),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (hotspotCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFFFB300)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$highRiskCount high-risk zones detected in your area',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF633806)),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 8 + bottomPadding),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _ServerBanner extends StatelessWidget {
  const _ServerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 14),
          SizedBox(width: 8),
          Text(
            'No server connection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
                offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.my_location,
            color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _DashedConnector extends StatelessWidget {
  const _DashedConnector();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 2.5),
          child: Container(
            width: 2,
            height: 2.5,
            decoration: BoxDecoration(
              color: const Color(0xFFBDCAD8),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip(
      {required this.icon, required this.label, required this.onTap});

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
