import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String baseUrl = 'http://10.0.2.2:8000';
  static bool isServerReachable = false;

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'ok') {
          isServerReachable = true;
          return true;
        }
      }
      isServerReachable = false;
      return false;
    } catch (e) {
      debugPrint('checkHealth error: $e');
      isServerReachable = false;
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHotspots() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/hotspots'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      debugPrint('getHotspots error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRouteSafety({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String destinationName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/route/safety'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin': {'latitude': originLat, 'longitude': originLng},
              'destination': {'latitude': destLat, 'longitude': destLng},
              'destination_name': destinationName,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('getRouteSafety error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRealTimeRisk({
    required double latitude,
    required double longitude,
    required int hour,
    required int dayOfWeek,
    required int month,
    required int isNight,
    required int isWeekend,
    required String vehicleType,
    double speedKmh = 0.0,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/predict/realtime'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'hour': hour,
              'day_of_week': dayOfWeek,
              'month': month,
              'is_night': isNight,
              'is_weekend': isWeekend,
              'vehicle_type': vehicleType,
              'speed_kmh': speedKmh,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('getRealTimeRisk error: $e');
      return null;
    }
  }

  /// Fetch 3 real road-following geometries from Mapbox Directions API.
  ///
  /// Makes 3 parallel calls, each forced through a different intermediate
  /// waypoint (perpendicular offsets of the midpoint), guaranteeing 3
  /// distinct road-snapped routes even on short urban trips where
  /// alternatives=true would return only 1–2 options.
  Future<List<List<List<double>>>> getMapboxRoadGeometries({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // Perpendicular unit vector — same offsets as the A* waypoint builder
    final dlat = destLat - originLat;
    final dlng = destLng - originLng;
    final len = math.sqrt(dlat * dlat + dlng * dlng);
    final perpLat = len > 0 ? -dlng / len : 0.0;
    final perpLng = len > 0 ? dlat / len : 0.0;

    final midLat = (originLat + destLat) / 2;
    final midLng = (originLng + destLng) / 2;
    const offset = 0.003; // ~330 m — enough to force different road choices

    final coordSets = [
      // Route 0: direct (main road)
      '$originLng,$originLat;$destLng,$destLat',
      // Route 1: via midpoint offset to one side
      '$originLng,$originLat'
          ';${midLng + offset * perpLng},${midLat + offset * perpLat}'
          ';$destLng,$destLat',
      // Route 2: via midpoint offset to the other side
      '$originLng,$originLat'
          ';${midLng - offset * perpLng},${midLat - offset * perpLat}'
          ';$destLng,$destLat',
    ];

    final results = await Future.wait(coordSets.map(_fetchDirectionsGeometry));
    return results.whereType<List<List<double>>>().toList();
  }

  /// Calls the Mapbox Directions API for [coords] and returns the first
  /// route's GeoJSON LineString coordinates as [[lng, lat], …].
  Future<List<List<double>>?> _fetchDirectionsGeometry(String coords) async {
    try {
      final url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
          '?geometries=geojson'
          '&overview=full'
          '&access_token=${AppConstants.mapboxToken}';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = (data['routes'] as List<dynamic>?) ?? [];
        if (routes.isEmpty) return null;
        final geometry = routes[0]['geometry'] as Map<String, dynamic>;
        final raw = geometry['coordinates'] as List<dynamic>;
        return raw.map((c) {
          final pair = c as List<dynamic>;
          return [
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          ];
        }).toList();
      }
      return null;
    } catch (e) {
      debugPrint('_fetchDirectionsGeometry error: $e');
      return null;
    }
  }

  /// Reverse-geocode a coordinate to a human-readable place name.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url =
          'https://api.mapbox.com/search/geocode/v6/reverse?longitude=$lng&latitude=$lat'
          '&access_token=${AppConstants.mapboxToken}&limit=1&language=en';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        if (features.isNotEmpty) {
          final props =
              features[0]['properties'] as Map<String, dynamic>? ?? {};
          final name = (props['name'] as String?) ??
              (props['full_address'] as String?);
          return name;
        }
      }
      return null;
    } catch (e) {
      debugPrint('reverseGeocode error: $e');
      return null;
    }
  }

  /// Mapbox Geocoding v6 — returns [{name, lat, lng}, …]
  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final encoded = Uri.encodeComponent(query);
      var url =
          'https://api.mapbox.com/search/geocode/v6/forward?q=$encoded'
          '&access_token=${AppConstants.mapboxToken}'
          '&autocomplete=true'
          '&limit=6'
          '&language=en'
          '&types=place,locality,neighborhood,address,postcode';
      if (nearLat != null && nearLng != null) {
        url += '&proximity=$nearLng,$nearLat';
      }
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        return features.map((f) {
          final geometry = f['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List<dynamic>;
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final fullAddress = (props['full_address'] as String?) ??
              (props['place_formatted'] as String?) ??
              (props['name'] as String?) ??
              '';
          return <String, dynamic>{
            'name': fullAddress,
            'lng': (coords[0] as num).toDouble(),
            'lat': (coords[1] as num).toDouble(),
          };
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('searchPlaces error: $e');
      return [];
    }
  }
}
