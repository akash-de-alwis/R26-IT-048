import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import './shared/constants/app_constants.dart';
import './shared/providers/app_provider.dart';
import './shared/services/auth_service.dart';
import './shared/services/offline_map_service.dart';
import './member3_alert_system/part1/services/alert_service.dart';
import './member3_alert_system/part1/services/notification_service.dart';
import './member4_driver_scoring/part1/services/sensor_service.dart';
import './member1_risk_prediction/part2/services/realtime_risk_service.dart';
import './member1_risk_prediction/part2/services/vehicle_preference_service.dart';
import './member2_route_engine/part2/services/enhanced_route_service.dart';
import './app.dart';

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
        ChangeNotifierProvider(create: (_) => EnhancedRouteService()),
        ChangeNotifierProvider(
          create: (_) {
            final svc = VehiclePreferenceService();
            svc.loadFromStorage();
            return svc;
          },
        ),
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
