import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ObstacleReportService {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static Future<bool> submitReport({
    required double latitude,
    required double longitude,
    required String obstacleType,
    required String severity,
    String? userNote,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v2/obstacles/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'obstacle_type': obstacleType,
          'severity': severity,
          if (userNote != null && userNote.isNotEmpty) 'user_note': userNote,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[obstacle_report] $e');
      return false;
    }
  }
}
