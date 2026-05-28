import 'package:flutter/material.dart';

class WeatherSnapshot {
  final String condition;
  final double temperatureC;
  final int humidityPct;
  final double windSpeedKmh;
  final int visibilityM;
  final String description;

  WeatherSnapshot({
    required this.condition,
    required this.temperatureC,
    required this.humidityPct,
    required this.windSpeedKmh,
    required this.visibilityM,
    required this.description,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) =>
      WeatherSnapshot(
        condition: json['condition'] as String,
        temperatureC: (json['temperature_c'] as num).toDouble(),
        humidityPct: json['humidity_pct'] as int,
        windSpeedKmh: (json['wind_speed_kmh'] as num).toDouble(),
        visibilityM: json['visibility_m'] as int,
        description: json['description'] as String,
      );

  IconData get icon {
    switch (condition) {
      case 'thunderstorm':
        return Icons.thunderstorm_rounded;
      case 'heavy_rain':
        return Icons.water_drop_rounded;
      case 'rain':
        return Icons.umbrella_rounded;
      case 'fog':
      case 'mist':
        return Icons.foggy;
      case 'clouds':
        return Icons.cloud_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }
}
