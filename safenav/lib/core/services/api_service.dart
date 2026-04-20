import 'dart:convert';
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

  Future<Map<String, dynamic>?> getRouteSafety(
    List<Map<String, dynamic>> routePoints,
    String destinationName,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/route/safety'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'route_points': routePoints,
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

  /// Reverse-geocode a coordinate to a human-readable place name.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
          '?access_token=${AppConstants.mapboxToken}&limit=1';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        if (features.isNotEmpty) {
          final name = features[0]['place_name'] as String?;
          if (name != null) {
            final comma = name.indexOf(',');
            return comma > 0 ? name.substring(0, comma).trim() : name;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('reverseGeocode error: $e');
      return null;
    }
  }

  /// Mapbox Geocoding — returns [{name, lat, lng}, …]
  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    try {
      final encoded = Uri.encodeComponent(query);
      var url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
          '?access_token=${AppConstants.mapboxToken}'
          '&limit=6'
          '&types=place,locality,neighborhood,address,poi';
      if (nearLat != null && nearLng != null) {
        url += '&proximity=$nearLng,$nearLat';
      }
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        return features.map((f) {
          final center = f['center'] as List<dynamic>;
          return <String, dynamic>{
            'name': f['place_name'] as String,
            'lng': (center[0] as num).toDouble(),
            'lat': (center[1] as num).toDouble(),
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
