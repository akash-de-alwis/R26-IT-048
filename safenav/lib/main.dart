import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(AppConstants.mapboxToken);
  await _requestLocationPermission();
  runApp(const SafeNavApp());
}

Future<void> _requestLocationPermission() async {
  final whenInUse = await Permission.locationWhenInUse.request();
  if (whenInUse.isGranted) {
    await Permission.locationAlways.request();
  }
}
