import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';

/// Route API calls owned by Member 2 (IT22054722).
class RouteApiService {
  RouteApiService._();
  static final RouteApiService instance = RouteApiService._();

  static const String _baseUrl = 'http://10.0.2.2:8000';

  Future<RouteResult> fetchRouteSafety({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String destinationName = '',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/route/safety'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'origin': {'latitude': originLat, 'longitude': originLng},
        'destination': {'latitude': destLat, 'longitude': destLng},
        'destination_name': destinationName,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Route safety request failed: ${response.statusCode}');
    }
    return RouteResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}
