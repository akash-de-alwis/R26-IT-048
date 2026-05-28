import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/app_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/offline_map_service.dart';
import 'member3_alerts/services/alert_service.dart';
import 'member3_alerts/services/notification_service.dart';
import 'member4_scoring/services/sensor_service.dart';
import 'features/member1_part2/services/realtime_risk_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  MapboxOptions.setAccessToken(AppConstants.mapboxToken);
  await Firebase.initializeApp();
  await _requestPermissions();
  await NotificationService.instance.init();

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

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
        ChangeNotifierProvider(create: (_) => RealtimeRiskService()),
      ],
      child: const SafeNavApp(),
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
