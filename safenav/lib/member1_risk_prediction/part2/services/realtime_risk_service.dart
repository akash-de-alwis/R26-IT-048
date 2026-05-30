import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/realtime_risk_model.dart';

class RealtimeRiskService extends ChangeNotifier {
  RealtimeRiskModel? currentRisk;
  bool isLoading = false;
  String? errorMessage;

  Timer? _pollTimer;
  String _vehicleType = 'Car';

  String get vehicleType => _vehicleType;
  set vehicleType(String v) {
    _vehicleType = v;
    notifyListeners();
  }

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  int get _pollSeconds {
    final s = dotenv.env['REALTIME_RISK_POLL_SECONDS'] ?? '15';
    return int.tryParse(s) ?? 15;
  }

  void startMonitoring() {
    if (_pollTimer != null) return;
    _fetchOnce();
    _pollTimer = Timer.periodic(
      Duration(seconds: _pollSeconds),
      (_) => _fetchOnce(),
    );
  }

  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
    currentRisk = null;
    notifyListeners();
  }

  Future<void> _fetchOnce() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final speedKmh = pos.speed * 3.6;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/v2/risk/realtime'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'speed_kmh': speedKmh < 0 ? 0.0 : speedKmh,
              'vehicle_type': _vehicleType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        currentRisk = RealtimeRiskModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } else {
        errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Connection failed';
      debugPrint('[RealtimeRiskService] Error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
