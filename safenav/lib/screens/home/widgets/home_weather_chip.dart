import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../member1_risk_prediction/part2/models/realtime_risk_model.dart';
import '../../../member1_risk_prediction/part2/models/weather_snapshot_model.dart';

/// Small "{temp}°C · {condition}" pill for the Home header.
///
/// Uses the same request as Member 1's trip Weather strip
/// (POST /v2/risk/realtime, parsed with [RealtimeRiskModel]) at the
/// device's current location, independently of any trip. Results are cached
/// in memory for 10 minutes. Hidden entirely on any failure or when
/// location permission has not been granted.
class HomeWeatherChip extends StatefulWidget {
  const HomeWeatherChip({super.key});

  @override
  State<HomeWeatherChip> createState() => _HomeWeatherChipState();
}

class _HomeWeatherChipState extends State<HomeWeatherChip> {
  static const _cacheFor = Duration(minutes: 10);
  static WeatherSnapshot? _cached;
  static DateTime? _cachedAt;
  static Future<WeatherSnapshot?>? _inFlight;

  WeatherSnapshot? _weather;

  @override
  void initState() {
    super.initState();
    _weather = _freshCache();
    if (_weather == null) _load();
  }

  static WeatherSnapshot? _freshCache() {
    final at = _cachedAt;
    if (_cached == null || at == null) return null;
    return DateTime.now().difference(at) < _cacheFor ? _cached : null;
  }

  Future<void> _load() async {
    final w = await (_inFlight ??= _fetch().whenComplete(() => _inFlight = null));
    if (mounted && w != null) setState(() => _weather = w);
  }

  static Future<WeatherSnapshot?> _fetch() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 8));

      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
      final response = await http
          .post(
            Uri.parse('$baseUrl/v2/risk/realtime'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'speed_kmh': 0.0,
              'vehicle_type': 'Car',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final weather = RealtimeRiskModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).weather;
      _cached = weather;
      _cachedAt = DateTime.now();
      return weather;
    } catch (e) {
      debugPrint('[HomeWeatherChip] weather unavailable: $e');
      return null;
    }
  }

  static IconData _icon(String condition) {
    switch (condition) {
      case 'thunderstorm':
        return Icons.thunderstorm_rounded;
      case 'rain':
      case 'heavy_rain':
      case 'drizzle':
        return Icons.water_drop_rounded;
      case 'clouds':
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'fog':
      case 'mist':
        return Icons.foggy;
      case 'clear':
        return Icons.wb_sunny_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  static String _label(String condition) {
    final text = condition.replaceAll('_', ' ').trim();
    if (text.isEmpty) return 'Clear';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final w = _weather;
    if (w == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(w.condition), size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${w.temperatureC.round()}°C · ${_label(w.condition)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
