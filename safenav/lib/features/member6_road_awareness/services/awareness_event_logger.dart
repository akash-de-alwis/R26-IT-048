import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/proximity_tier.dart';

/// Logs close-proximity events to the existing Member 5 backend endpoint
/// (POST /v3/distance/event), so the trip distance summary keeps working.
class AwarenessEventLogger {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  /// Returns true if the backend accepted the event. Never throws.
  static Future<bool> log({
    required String tripId,
    required double distanceM,
    required double safeDistanceM,
    required double speedKmh,
    required ProximityTier tier,
    double? ttcSeconds,
    required double durationSeconds,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/v3/distance/event'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trip_id': tripId,
              'timestamp': DateTime.now().toIso8601String(),
              'distance_m': distanceM,
              'safe_distance_m': safeDistanceM,
              'following_gap_ratio':
                  safeDistanceM > 0 ? distanceM / safeDistanceM : 0,
              'speed_kmh': speedKmh,
              'severity': tier.backendSeverity,
              'ttc_seconds': ttcSeconds,
              'duration_seconds': durationSeconds,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode >= 200 && res.statusCode < 300) return true;
      debugPrint('[awareness_logger] HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('[awareness_logger] $e');
    }
    return false;
  }
}
