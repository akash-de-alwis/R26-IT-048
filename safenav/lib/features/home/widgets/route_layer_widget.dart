import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> drawRoutesOnMap(
  MapboxMap mapboxMap,
  List<Map<String, dynamic>> routes,
  int selectedIndex, {
  List<List<List<double>>>? roadGeometries,
}) async {
  // Remove existing casing, line layers and sources
  for (int i = 0; i < 3; i++) {
    try { await mapboxMap.style.removeStyleLayer('route-casing-$i'); } catch (_) {}
    try { await mapboxMap.style.removeStyleLayer('route-layer-$i'); } catch (_) {}
    try { await mapboxMap.style.removeStyleSource('route-source-$i'); } catch (_) {}
  }

  double minLat = double.infinity, maxLat = -double.infinity;
  double minLng = double.infinity, maxLng = -double.infinity;

  // Unselected routes first so the selected route renders on top
  final drawOrder = [
    for (int i = 0; i < routes.length; i++) i,
  ]..sort((a, b) => (a == selectedIndex ? 1 : 0) - (b == selectedIndex ? 1 : 0));

  // ── Pass 1: add GeoJSON sources ─────────────────────────────────────────────
  final drawnIndices = <int>[];
  for (final i in drawOrder) {
    List<List<double>> coordinates;
    if (roadGeometries != null && roadGeometries.isNotEmpty) {
      // Clamp: never fall back to synthetic straight-line A* paths
      final geoIndex = i < roadGeometries.length ? i : roadGeometries.length - 1;
      coordinates = roadGeometries[geoIndex];
    } else {
      final path = (routes[i]['path'] as List<dynamic>?) ?? [];
      if (path.isEmpty) continue;
      coordinates = path.map((p) => [
        (p['longitude'] as num).toDouble(),
        (p['latitude'] as num).toDouble(),
      ]).toList();
    }

    if (coordinates.isEmpty) continue;

    for (final coord in coordinates) {
      final lng = coord[0], lat = coord[1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    await mapboxMap.style.addSource(GeoJsonSource(
      id: 'route-source-$i',
      data: json.encode({
        'type': 'Feature',
        'geometry': {'type': 'LineString', 'coordinates': coordinates},
      }),
    ));
    drawnIndices.add(i);
  }

  // ── Pass 2: white casing layers (depth / road-like appearance) ──────────────
  for (final i in drawnIndices) {
    final isSelected = i == selectedIndex;
    await mapboxMap.style.addLayer(LineLayer(
      id: 'route-casing-$i',
      sourceId: 'route-source-$i',
      lineColor: 0xFFFFFFFF,
      lineWidth: isSelected ? 10.0 : 5.5,
      lineOpacity: isSelected ? 1.0 : 0.45,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
  }

  // ── Pass 3: colored line layers on top of casings ───────────────────────────
  for (final i in drawnIndices) {
    final isSelected = i == selectedIndex;
    await mapboxMap.style.addLayer(LineLayer(
      id: 'route-layer-$i',
      sourceId: 'route-source-$i',
      lineColor: isSelected ? 0xFF2979FF : 0xFF7FB3F5,
      lineWidth: isSelected ? 5.5 : 2.8,
      lineOpacity: isSelected ? 1.0 : 0.72,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));
  }

  // ── Animate camera to fit all routes ────────────────────────────────────────
  if (minLat.isFinite && maxLat.isFinite) {
    try {
      final camera = await mapboxMap.cameraForCoordinateBounds(
        CoordinateBounds(
          southwest: Point(coordinates: Position(minLng, minLat)),
          northeast: Point(coordinates: Position(maxLng, maxLat)),
          infiniteBounds: false,
        ),
        MbxEdgeInsets(top: 80, left: 80, bottom: 320, right: 80),
        null, null, null, null,
      );
      await mapboxMap.flyTo(camera, MapAnimationOptions(duration: 1100));
    } catch (_) {}
  }
}
