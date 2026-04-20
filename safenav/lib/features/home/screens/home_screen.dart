import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/hotspot_model.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/place_search_sheet.dart';
import '../widgets/route_options_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../../../core/services/geocoding_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;
  CircleAnnotationManager? _circleAnnotationManager;
  CircleAnnotationManager? _destinationAnnotationManager;
  AppProvider? _appProvider;
  StreamSubscription<geo.Position>? _positionSub;
  bool _hasFlewToLocation = false;
  bool _isLocating = false;

  // Map pick mode
  bool _isPickingLocation = false;
  bool _pickingForOrigin = false;
  bool _isReverseGeocoding = false;

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
    if (!mounted || _circleAnnotationManager == null) return;
    _refreshHotspotAnnotations();
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
    setState(() => _currentPosition = pos);
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
        _showRouteOptionsSheet(label);
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
    _showRouteOptionsSheet(place.placeName);
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
          _showRouteOptionsSheet(name);
        },
      ),
    );
  }

  void _showRouteOptionsSheet(String destination) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RouteOptionsSheet(destination: destination),
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

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
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

            // ── Pick mode crosshair (center of screen) ───────────────────
            if (_isPickingLocation)
              IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 52,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      Container(
                        width: 10,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Normal top overlay ───────────────────────────────────────
            if (!_isPickingLocation)
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

            // ── Pick mode header ─────────────────────────────────────────
            if (_isPickingLocation)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _PickModeHeader(
                    isOrigin: _pickingForOrigin,
                    onCancel: _cancelPickMode,
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

            // ── Bottom: confirm panel or normal strip ────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _isPickingLocation
                  ? _PickConfirmPanel(
                      isOrigin: _pickingForOrigin,
                      isLoading: _isReverseGeocoding,
                      bottomPadding: bottomPadding,
                      onConfirm: _confirmPickedLocation,
                      onCancel: _cancelPickMode,
                    )
                  : _BottomStrip(
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

// ── Pick mode widgets ─────────────────────────────────────────────────────────

class _PickModeHeader extends StatelessWidget {
  final bool isOrigin;
  final VoidCallback onCancel;

  const _PickModeHeader({required this.isOrigin, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.arrow_back, size: 20,
                color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOrigin ? 'Set starting point' : 'Set destination',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Tap the map or pan & tap Confirm',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickConfirmPanel extends StatelessWidget {
  final bool isOrigin;
  final bool isLoading;
  final double bottomPadding;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PickConfirmPanel({
    required this.isOrigin,
    required this.isLoading,
    required this.bottomPadding,
    required this.onConfirm,
    required this.onCancel,
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOrigin
                      ? AppColors.primaryLight
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOrigin ? Icons.trip_origin : Icons.flag_outlined,
                  color: isOrigin ? AppColors.primary : AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOrigin
                      ? 'Tap the map or pan to your starting point'
                      : 'Tap the map or pan to your destination',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFFDDE3EA)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm location',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Location input card (top) ─────────────────────────────────────────────────

class _LocationInputCard extends StatelessWidget {
  final String originLabel;
  final bool isUsingGps;
  final bool isLocating;
  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;

  const _LocationInputCard({
    required this.originLabel,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── App header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.navigation,
                    color: AppColors.primary, size: 18),
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
                  child: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary, size: 22),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),

          const Divider(height: 1, indent: 18, endIndent: 18),

          // ── From row ───────────────────────────────────────────────────
          GestureDetector(
            onTap: onOriginTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 14, 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isUsingGps
                          ? AppColors.primary
                          : AppColors.hotspotMed,
                      shape: BoxShape.circle,
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 1),
                        if (isLocating && isUsingGps)
                          Row(
                            children: const [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Getting location…',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textHint),
                              ),
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
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      size: 15, color: AppColors.textHint),
                ],
              ),
            ),
          ),

          // Connector
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              children: [
                Container(
                    width: 2, height: 12, color: const Color(0xFFE0E6EE)),
              ],
            ),
          ),

          // ── To row ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: onDestinationTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.textSecondary, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Where to?',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search,
                        color: Colors.white, size: 16),
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
