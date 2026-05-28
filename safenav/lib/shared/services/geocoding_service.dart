import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class PlaceSuggestion {
  final String placeId;
  final String placeName;
  final String shortName;
  final double latitude;
  final double longitude;

  const PlaceSuggestion({
    required this.placeId,
    required this.placeName,
    required this.shortName,
    required this.latitude,
    required this.longitude,
  });
}

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  String _sessionToken = _newToken();
  static String _newToken() => 'snv${DateTime.now().millisecondsSinceEpoch}';
  void _resetSession() => _sessionToken = _newToken();

  /// Step 1: autocomplete suggestions (no coords yet).
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.length < 3) return [];
    try {
      final encoded = Uri.encodeComponent(query);
      final url =
          'https://api.mapbox.com/search/searchbox/v1/suggest?q=$encoded'
          '&access_token=${AppConstants.mapboxToken}'
          '&session_token=$_sessionToken'
          '&autocomplete=true'
          '&country=LK'
          '&proximity=${AppConstants.defaultLng},${AppConstants.defaultLat}'
          '&limit=7'
          '&language=en'
          '&types=poi,address,place,neighborhood,locality,postcode';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['suggestions'] as List<dynamic>?) ?? [];
        return list
            .map((s) {
              final m = s as Map<String, dynamic>;
              final name = (m['name'] as String?) ?? '';
              final full = (m['full_address'] as String?) ??
                  (m['place_formatted'] as String?) ??
                  name;
              final id = (m['mapbox_id'] as String?) ?? '';
              if (id.isEmpty) return null;
              return PlaceSuggestion(
                placeId: id,
                placeName: full,
                shortName: name,
                latitude: 0.0,
                longitude: 0.0,
              );
            })
            .whereType<PlaceSuggestion>()
            .toList();
      }
      debugPrint('suggest ${response.statusCode}: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('GeocodingService.searchPlaces: $e');
      return [];
    }
  }

  /// Step 2: resolve coordinates for a selected suggestion.
  Future<PlaceSuggestion?> retrievePlace(PlaceSuggestion suggestion) async {
    try {
      final url =
          'https://api.mapbox.com/search/searchbox/v1/retrieve/${suggestion.placeId}'
          '?access_token=${AppConstants.mapboxToken}'
          '&session_token=$_sessionToken';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      _resetSession();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        if (features.isNotEmpty) {
          final feat = features[0] as Map<String, dynamic>;
          final props = feat['properties'] as Map<String, dynamic>? ?? {};
          final coords =
              props['coordinates'] as Map<String, dynamic>? ??
              (feat['geometry']?['coordinates'] != null
                  ? null
                  : null);
          double? lat, lng;
          if (coords != null) {
            lat = (coords['latitude'] as num?)?.toDouble();
            lng = (coords['longitude'] as num?)?.toDouble();
          }
          if (lat == null || lng == null) {
            final geo = feat['geometry'] as Map<String, dynamic>?;
            final c = geo?['coordinates'] as List<dynamic>?;
            if (c != null && c.length >= 2) {
              lng = (c[0] as num).toDouble();
              lat = (c[1] as num).toDouble();
            }
          }
          if (lat != null && lng != null) {
            return PlaceSuggestion(
              placeId: suggestion.placeId,
              placeName: suggestion.placeName,
              shortName: suggestion.shortName,
              latitude: lat,
              longitude: lng,
            );
          }
        }
      }
      debugPrint('retrieve ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('GeocodingService.retrievePlace: $e');
      return null;
    }
  }
}
