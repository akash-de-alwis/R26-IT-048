import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

enum HotspotSeverity { low, medium, high }

class HotspotMarkerWidget extends StatelessWidget {
  final HotspotSeverity severity;
  final int count;

  const HotspotMarkerWidget({
    super.key,
    required this.severity,
    required this.count,
  });

  Color get _color {
    return switch (severity) {
      HotspotSeverity.low => AppColors.hotspotLow,
      HotspotSeverity.medium => AppColors.warning,
      HotspotSeverity.high => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
