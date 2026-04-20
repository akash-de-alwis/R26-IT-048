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

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as List<dynamic>;
    final name = json['place_name'] as String;
    return PlaceSuggestion(
      placeId: json['id'] as String,
      placeName: name,
      shortName: name.split(',')[0].trim(),
      latitude: (center[1] as num).toDouble(),
      longitude: (center[0] as num).toDouble(),
    );
  }
}

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.length < 3) return [];
    try {
      final encoded = Uri.encodeComponent(query);
      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
          '?access_token=${AppConstants.mapboxToken}'
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
        final features = (data['features'] as List<dynamic>?) ?? [];
        return features
            .map((f) => PlaceSuggestion.fromJson(f as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('GeocodingService.searchPlaces error: $e');
      return [];
    }
  }
}
