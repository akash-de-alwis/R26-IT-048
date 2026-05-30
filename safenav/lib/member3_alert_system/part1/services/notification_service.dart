import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  Future<void> showAlert({
    required int id,
    required String title,
    required String body,
    required String severity,
  }) async {
    if (!_initialized) return;

    final color = switch (severity) {
      'CRITICAL' => const Color(0xFFFF3B5C),
      'WARNING' => const Color(0xFFFFB300),
      _ => const Color(0xFF2979FF),
    };

    final androidDetails = AndroidNotificationDetails(
      'safenav_alerts',
      'Safety Alerts',
      channelDescription: 'Nearby accident hotspot alerts',
      importance:
          severity == 'CRITICAL' ? Importance.max : Importance.high,
      priority: severity == 'CRITICAL' ? Priority.max : Priority.high,
      color: color,
      enableLights: true,
      ledColor: color,
      ledOnMs: 1000,
      ledOffMs: 500,
      playSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}
