import 'package:flutter/material.dart';

class TrafficLegend extends StatelessWidget {
  const TrafficLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.traffic_rounded, size: 14, color: Color(0xFF5C6B7A)),
          const SizedBox(width: 6),
          _dot(const Color(0xFF00C06A)),
          const SizedBox(width: 3),
          const Text('Clear', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 8),
          _dot(const Color(0xFFFFB300)),
          const SizedBox(width: 3),
          const Text('Slow', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 8),
          _dot(const Color(0xFFFF8C42)),
          const SizedBox(width: 3),
          const Text('Heavy', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 8),
          _dot(const Color(0xFFFF3B5C)),
          const SizedBox(width: 3),
          const Text('Severe', style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
