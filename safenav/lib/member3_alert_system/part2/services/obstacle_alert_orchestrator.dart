import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/obstacle_model.dart';
import 'obstacle_scan_service.dart';
import 'obstacle_voice_service.dart';
import 'obstacle_preference_service.dart';

class ObstacleAlertOrchestrator extends ChangeNotifier {
  ObstacleModel? currentAlertObstacle;
  final Set<String> _alertedIds = {};
  Timer? _pollTimer;

  final ObstacleScanService scanService;
  final ObstacleVoiceService voiceService;
  final ObstaclePreferenceService preferences;

  ObstacleAlertOrchestrator({
    required this.scanService,
    required this.voiceService,
    required this.preferences,
  });

  void startMonitoring() {
    if (!preferences.detectionEnabled) return;
    _pollTimer?.cancel();
    _alertedIds.clear();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkObstacles());
  }

  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
    currentAlertObstacle = null;
    _alertedIds.clear();
    notifyListeners();
  }

  Future<void> _checkObstacles() async {
    if (!preferences.detectionEnabled) {
      stopMonitoring();
      return;
    }
    if (scanService.obstacles.isEmpty) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Find obstacles within 200m that haven't been alerted, filtered by threshold
      final candidates = scanService.obstacles
          .where((o) => !_alertedIds.contains(o.id))
          .where((o) => preferences.shouldAlertFor(o.severity))
          .map((o) {
            final dist = Geolocator.distanceBetween(
              pos.latitude,
              pos.longitude,
              o.latitude,
              o.longitude,
            );
            return MapEntry(o, dist);
          })
          .where((e) => e.value <= 200)
          .toList();

      if (candidates.isEmpty) {
        if (currentAlertObstacle != null) {
          currentAlertObstacle = null;
          notifyListeners();
        }
        return;
      }

      // Pick highest severity first, then nearest within same severity
      const severityOrder = ['CAUTION', 'WARNING', 'CRITICAL'];
      candidates.sort((a, b) {
        final sa = severityOrder.indexOf(a.key.severity);
        final sb = severityOrder.indexOf(b.key.severity);
        if (sa != sb) return sb.compareTo(sa);
        return a.value.compareTo(b.value);
      });

      final winner = candidates.first.key;
      _alertedIds.add(winner.id);
      currentAlertObstacle = winner;
      notifyListeners();

      if (preferences.voiceEnabled) {
        final text = preferences.voiceLanguage == 'si'
            ? winner.alert.voiceSi
            : winner.alert.voiceEn;
        await voiceService.speak(text, preferences.voiceLanguage);
      }

      // Auto-clear banner after 6 seconds
      final alertedId = winner.id;
      Timer(const Duration(seconds: 6), () {
        if (currentAlertObstacle?.id == alertedId) {
          currentAlertObstacle = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[orchestrator] $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
