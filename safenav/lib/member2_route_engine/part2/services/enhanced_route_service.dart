import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/enhanced_route_model.dart';

class EnhancedRouteService extends ChangeNotifier {
  List<EnhancedRouteModel> routes = [];
  EnhancedRouteModel? selectedRoute;
  bool isLoading = false;
  String? errorMessage;

  /// Map can subscribe to react immediately when the selection changes.
  void Function(EnhancedRouteModel)? onRouteChanged;

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  Future<void> fetchRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/v2/route/safety'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin': {'latitude': originLat, 'longitude': originLng},
              'destination': {'latitude': destLat, 'longitude': destLng},
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        routes = (data['routes'] as List<dynamic>)
            .map((r) =>
                EnhancedRouteModel.fromJson(r as Map<String, dynamic>))
            .toList();
        if (routes.isNotEmpty) {
          selectedRoute = routes.first;
          // Notify map immediately so it can draw the initial route
          onRouteChanged?.call(routes.first);
        }
      } else {
        errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Failed to fetch routes';
      debugPrint('[EnhancedRouteService] $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectRoute(EnhancedRouteModel route) {
    selectedRoute = route;
    notifyListeners();
    onRouteChanged?.call(route);
  }

  void clearRoutes() {
    routes = [];
    selectedRoute = null;
    notifyListeners();
  }
}
