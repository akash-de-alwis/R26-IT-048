import 'package:flutter/material.dart';
import '../models/hotspot_model.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;

  List<HotspotModel> hotspots = [];
  bool isLoadingHotspots = false;
  bool isServerConnected = false;
  Map<String, dynamic>? currentRouteData;
  bool isLoadingRoute = false;
  Map<String, dynamic>? currentRiskData;
  String selectedVehicleType = 'Motorcycle';

  // Origin location — GPS or manually overridden
  double? originLat;
  double? originLng;
  bool isUsingGps = true;
  String originLabel = 'My Location';

  void setGpsLocation(double lat, double lng) {
    if (!isUsingGps) return;
    originLat = lat;
    originLng = lng;
    originLabel = 'My Location';
    notifyListeners();
  }

  void setManualLocation(double lat, double lng, String label) {
    originLat = lat;
    originLng = lng;
    originLabel = label.trim().isEmpty
        ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
        : label.trim();
    isUsingGps = false;
    notifyListeners();
  }

  void resetToGps() {
    isUsingGps = true;
    originLabel = 'My Location';
    notifyListeners();
  }

  Future<void> initializeApp() async {
    isServerConnected = await _apiService.checkHealth();
    if (isServerConnected) {
      await loadHotspots();
    }
    notifyListeners();
  }

  Future<void> loadHotspots() async {
    isLoadingHotspots = true;
    notifyListeners();
    final raw = await _apiService.getHotspots();
    hotspots = raw.map(HotspotModel.fromJson).toList();
    isLoadingHotspots = false;
    notifyListeners();
  }

  Future<void> fetchRouteSafety(
    List<Map<String, dynamic>> points,
    String destination,
  ) async {
    isLoadingRoute = true;
    notifyListeners();
    currentRouteData = await _apiService.getRouteSafety(points, destination);
    isLoadingRoute = false;
    notifyListeners();
  }

  Future<void> updateRealTimeRisk(double lat, double lng) async {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;
    final month = now.month;
    final isNight = (hour >= 20 || hour < 6) ? 1 : 0;
    final isWeekend = (dayOfWeek >= 6) ? 1 : 0;

    currentRiskData = await _apiService.getRealTimeRisk(
      latitude: lat,
      longitude: lng,
      hour: hour,
      dayOfWeek: dayOfWeek,
      month: month,
      isNight: isNight,
      isWeekend: isWeekend,
      vehicleType: selectedVehicleType,
    );
    notifyListeners();
  }
}
