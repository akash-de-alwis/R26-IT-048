import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/offline_map_service.dart';
import 'member3_alerts/services/alert_service.dart';
import 'member4_scoring/services/sensor_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(AppConstants.mapboxToken);
  await Firebase.initializeApp();
  await _requestPermissions();

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('onboarding_complete') ?? false;
  final User? user = FirebaseAuth.instance.currentUser;

  String initialRoute = '/splash';
  if (seenOnboarding && user != null) {
    initialRoute = AppConstants.routeHome;
  } else if (seenOnboarding && user == null) {
    initialRoute = '/login';
  }

  runApp(AppRoot(initialRoute: initialRoute));
}

class AppRoot extends StatelessWidget {
  final String initialRoute;
  const AppRoot({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => OfflineMapService()),
        ChangeNotifierProvider(create: (_) => SensorService.instance),
        ChangeNotifierProvider(
          create: (ctx) => AlertService(
            sensorService: ctx.read<SensorService>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: SafeNavApp(initialRoute: initialRoute),
    );
  }
}

Future<void> _requestPermissions() async {
  final whenInUse = await Permission.locationWhenInUse.request();
  if (whenInUse.isGranted) {
    await Permission.locationAlways.request();
  }
  await Permission.notification.request();
}
