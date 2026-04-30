import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_provider.dart';
import 'core/services/offline_map_service.dart';
import 'member3_alerts/services/alert_service.dart';
import 'member4_scoring/services/sensor_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(AppConstants.mapboxToken);
  await _requestPermissions();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('onboarding_complete') ?? false;

  runApp(AppRoot(seenOnboarding: seenOnboarding));
}

class AppRoot extends StatelessWidget {
  final bool seenOnboarding;
  const AppRoot({super.key, required this.seenOnboarding});

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
      ],
      child: SafeNavApp(seenOnboarding: seenOnboarding),
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
