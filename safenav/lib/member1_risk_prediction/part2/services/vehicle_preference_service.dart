import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehiclePreferenceService extends ChangeNotifier {
  static const String _defaultKey = 'default_vehicle_type';
  static const String _lastUsedKey = 'last_used_vehicle_type';

  String _defaultVehicle = 'Car';
  String _currentVehicle = 'Car';
  bool _hasSelectedThisSession = false;

  String get defaultVehicle => _defaultVehicle;
  String get currentVehicle => _currentVehicle;
  bool get hasSelectedThisSession => _hasSelectedThisSession;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultVehicle = prefs.getString(_defaultKey) ?? 'Car';
    final lastUsed = prefs.getString(_lastUsedKey);
    _currentVehicle = lastUsed ?? _defaultVehicle;
    // If the user previously made an explicit choice, skip the prompt
    if (lastUsed != null) {
      _hasSelectedThisSession = true;
    }
    notifyListeners();
  }

  /// Marks vehicle selection as done for this session (resets on app restart).
  void markSessionSelected() {
    _hasSelectedThisSession = true;
    notifyListeners();
  }

  Future<void> setDefault(String vehicleId) async {
    _defaultVehicle = vehicleId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultKey, vehicleId);
    notifyListeners();
  }

  Future<void> setCurrent(String vehicleId) async {
    _currentVehicle = vehicleId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsedKey, vehicleId);
    notifyListeners();
  }
}
