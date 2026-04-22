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
import '../../member3_alerts/services/alert_service.dart';
import '../../member4_scoring/services/sensor_service.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/widgets/place_search_sheet.dart';
import '../../member2_routing/widgets/route_layer_widget.dart';
import '../../member2_routing/widgets/route_options_sheet.dart';
import '../../member3_alerts/widgets/safety_alert_card.dart';
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
  CircleAnnotationManager? _circleAnnotationManager;
  CircleAnnotationManager? _destinationAnnotationManager;
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
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _appProvider?.removeListener(_onHotspotsUpdated);
    super.dispose();
  }

  void _onHotspotsUpdated() {
    if (!mounted) return;
    if (_circleAnnotationManager != null) _refreshHotspotAnnotations();
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
    final manager = _destinationAnnotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    await manager.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      circleRadius: 10.0,
      circleColor: AppColors.primary.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: Colors.white.toARGB32(),
      circleOpacity: 1.0,
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
    _circleAnnotationManager =
        await map.annotations.createCircleAnnotationManager();
    _destinationAnnotationManager =
        await map.annotations.createCircleAnnotationManager();
    if (!mounted) return;
    final hotspots = _appProvider?.hotspots ?? [];
    if (hotspots.isNotEmpty) await _buildAnnotations(hotspots);
    if (_currentPosition != null) {
      await _flyToLocation(
          _currentPosition!.longitude, _currentPosition!.latitude);
    }
  }

  Future<void> _refreshHotspotAnnotations() async {
    final manager = _circleAnnotationManager;
    if (manager == null) return;
    final hotspots = _appProvider?.hotspots ?? [];
    await manager.deleteAll();
    await _buildAnnotations(hotspots);
  }

  Future<void> _buildAnnotations(List<HotspotModel> hotspots) async {
    final manager = _circleAnnotationManager;
    if (manager == null || hotspots.isEmpty) return;
    final annotations = hotspots
        .map((h) => CircleAnnotationOptions(
              geometry: Point(coordinates: Position(h.longitude, h.latitude)),
              circleColor: h.markerColor.toARGB32(),
              circleRadius: h.markerSize,
              circleStrokeWidth: 2.0,
              circleStrokeColor: Colors.white.toARGB32(),
              circleOpacity: 0.92,
            ))
        .toList();
    await manager.createMulti(annotations);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Future<void> _endTrip(BuildContext context) async {
    final sensorService = context.read<SensorService>();
    final alertService = context.read<AlertService>();
    final nav = Navigator.of(context, rootNavigator: true);
    alertService.stopAlertMonitoring();
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
                          const _LegendRow(),
                          if (appProvider.isLoadingHotspots) ...[
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
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
                  child: _NavActiveBanner(
                    onEndTrip: () => _endTrip(context),
                  ),
                ),
              ),

            // ── Safety alert cards overlay ───────────────────────────────
            Consumer<AlertService>(
              builder: (ctx, alertService, _) {
                if (alertService.activeAlerts.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: 90,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: alertService.activeAlerts.take(2).map((alert) {
                      return SafetyAlertCard(
                        alertData: alert,
                        language: alertService.currentLanguage,
                        onDismiss: () => alertService
                            .dismissAlert(alert['hotspot_id'] as int),
                        onDismissAll: () => alertService.dismissAllAlerts(),
                      );
                    }).toList(),
                  ),
                );
              },
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
                bottom: 160 + bottomPadding,
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
                  onQuickSearch: _openDestinationSearch,
                ),
              ),
          ],
        ),
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

class _NavActiveBanner extends StatelessWidget {
  final VoidCallback onEndTrip;
  const _NavActiveBanner({required this.onEndTrip});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Trip in progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onEndTrip,
            child: const Text(
              'End Trip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF00C06A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Bottom strip ──────────────────────────────────────────────────────────────

class _BottomStrip extends StatelessWidget {
  final double bottomPadding;
  final int hotspotCount;
  final VoidCallback onQuickSearch;

  const _BottomStrip({
    required this.bottomPadding,
    required this.hotspotCount,
    required this.onQuickSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 16, offset: Offset(0, -3)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 12 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 14),
          Row(
            children: [
              _QuickChip(
                  icon: Icons.work_outline, label: 'Work', onTap: onQuickSearch),
              const SizedBox(width: 8),
              _QuickChip(
                  icon: Icons.home_outlined, label: 'Home', onTap: onQuickSearch),
              const SizedBox(width: 8),
              _QuickChip(
                  icon: Icons.history, label: 'Recent', onTap: onQuickSearch),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 5),
              Text(
                '$hotspotCount accident hotspots detected nearby',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
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

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: AppColors.hotspotHigh, label: 'High'),
          SizedBox(width: 14),
          _LegendDot(color: AppColors.hotspotMed, label: 'Medium'),
          SizedBox(width: 14),
          _LegendDot(color: AppColors.hotspotLow, label: 'Low'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

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
