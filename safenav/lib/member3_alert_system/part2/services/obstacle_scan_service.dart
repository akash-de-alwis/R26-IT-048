import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/obstacle_model.dart';
import 'obstacle_preference_service.dart';

class ObstacleScanService extends ChangeNotifier {
  List<ObstacleModel> obstacles = [];
  bool isLoading = false;
  String? errorMessage;

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  Future<void> scanRoute(
    List<List<double>> geometry,
    ObstaclePreferenceService preferences,
  ) async {
    if (!preferences.detectionEnabled) {
      obstacles = [];
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v2/obstacles/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'route_geometry': geometry}),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        obstacles = (data['obstacles'] as List)
            .map((o) => ObstacleModel.fromJson(o as Map<String, dynamic>))
            .toList();
      } else {
        errorMessage = 'Obstacle scan returned ${response.statusCode}';
        debugPrint('[obstacle_scan] ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      errorMessage = 'Obstacle scan failed';
      debugPrint('[obstacle_scan] $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    obstacles = [];
    errorMessage = null;
    notifyListeners();
  }
}
