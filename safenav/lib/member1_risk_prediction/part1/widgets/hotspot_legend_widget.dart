import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// High / Medium / Low risk legend displayed above the map.
class HotspotLegendWidget extends StatelessWidget {
  const HotspotLegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: AppColors.hotspotHigh, label: 'High'),
          SizedBox(width: 14),
          _LegendDot(color: AppColors.hotspotMed, label: 'Medium'),
          SizedBox(width: 14),
          _LegendDot(color: AppColors.hotspotLow, label: 'Low'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
