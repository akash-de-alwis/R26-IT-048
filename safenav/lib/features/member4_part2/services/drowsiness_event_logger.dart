import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/drowsiness_metrics_model.dart';

class DrowsinessEventLogger {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static Future<void> log({
    required String tripId,
    required DrowsinessMetrics metrics,
    required double durationSeconds,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/v2/drowsiness/event'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trip_id': tripId,
              'timestamp': metrics.timestamp.toIso8601String(),
              'drowsiness_score': metrics.drowsinessScore,
              'drowsiness_level': metrics.levelLabel,
              'perclos_pct': metrics.perclosPct,
              'yawn_count_60s': metrics.yawnCount60s,
              'head_nods_60s': metrics.headNods60s,
              'avg_ear': metrics.currentEar,
              'duration_seconds': durationSeconds,
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('[drowsiness_logger] $e');
    }
  }
}
