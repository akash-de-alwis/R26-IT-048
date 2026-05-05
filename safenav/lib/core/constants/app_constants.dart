class AppConstants {
  AppConstants._();

  static const String appName = 'SafeNav';

  // Switch between emulator (10.0.2.2) and physical device (machine's WiFi IP)
  static const String backendUrl = 'http://10.0.2.2:8000';

  static const String mapboxToken =
      'pk.eyJ1IjoiYWthc2gtMDAwMDciLCJhIjoiY21vM2FuMnQyMGl0cjJxczRlNGdoZGFtYiJ9.qajO-RfHK8_RDavHfKChyA';
  static const String mapboxStyle = 'mapbox://styles/mapbox/light-v11';

  static const double defaultLat = 6.7086;
  static const double defaultLng = 79.9054;
  static const double defaultZoom = 14.0;
  static const double navigationZoom = 17.0;

  static const double riskRadiusMeters = 300.0;

  static const List<Map<String, dynamic>> hotspotData = [
    {'lat': 6.7112, 'lng': 79.9080, 'riskScore': 88, 'label': 'Panadura Junction'},
    {'lat': 6.7055, 'lng': 79.9021, 'riskScore': 62, 'label': 'Pinwatta Road'},
    {'lat': 6.7198, 'lng': 79.9143, 'riskScore': 45, 'label': 'Heenetiyana Rd'},
    {'lat': 6.7034, 'lng': 79.8997, 'riskScore': 91, 'label': 'Pallansena Bridge'},
    {'lat': 6.7162, 'lng': 79.9067, 'riskScore': 30, 'label': 'Aluthgama Bypass'},
    {'lat': 6.7089, 'lng': 79.9110, 'riskScore': 74, 'label': 'Railway Crossing'},
  ];

  // Driver score thresholds
  static const double scoreExcellent = 90.0;
  static const double scoreGood = 75.0;
  static const double scoreFair = 60.0;

  // Sensor thresholds (m/s²)
  static const double harshBrakingThreshold = 8.0;
  static const double harshAccelerationThreshold = 6.0;
  static const double sharpTurnThreshold = 7.0;

  // Route paths
  static const String routeHome = '/home';
  static const String routeMap = '/map';
  static const String routeScore = '/score';
  static const String routeProfile = '/profile';
}
