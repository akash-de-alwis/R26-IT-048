import 'package:flutter/material.dart';
import '../models/traffic_summary_model.dart';

class TrafficBreakdownBar extends StatelessWidget {
  final TrafficSummary traffic;

  const TrafficBreakdownBar({super.key, required this.traffic});

  @override
  Widget build(BuildContext context) {
    final hasData = traffic.lowPct > 0 ||
        traffic.moderatePct > 0 ||
        traffic.heavyPct > 0 ||
        traffic.severePct > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: hasData
              ? Row(children: [
                  if (traffic.lowPct > 0)
                    Expanded(
                      flex: (traffic.lowPct * 10).round().clamp(1, 1000),
                      child: Container(height: 6, color: const Color(0xFF00C06A)),
                    ),
                  if (traffic.moderatePct > 0)
                    Expanded(
                      flex: (traffic.moderatePct * 10).round().clamp(1, 1000),
                      child: Container(height: 6, color: const Color(0xFFFFB300)),
                    ),
                  if (traffic.heavyPct > 0)
                    Expanded(
                      flex: (traffic.heavyPct * 10).round().clamp(1, 1000),
                      child: Container(height: 6, color: const Color(0xFFFF8C42)),
                    ),
                  if (traffic.severePct > 0)
                    Expanded(
                      flex: (traffic.severePct * 10).round().clamp(1, 1000),
                      child: Container(height: 6, color: const Color(0xFFFF3B5C)),
                    ),
                ])
              : Container(
                  height: 6,
                  color: const Color(0xFF5C6B7A),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legendDot(
                'Clear', '${traffic.lowPct.toStringAsFixed(0)}%', const Color(0xFF00C06A)),
            const SizedBox(width: 12),
            _legendDot(
                'Slow', '${traffic.moderatePct.toStringAsFixed(0)}%', const Color(0xFFFFB300)),
            const SizedBox(width: 12),
            _legendDot(
                'Heavy', '${traffic.heavyPct.toStringAsFixed(0)}%', const Color(0xFFFF8C42)),
            const SizedBox(width: 12),
            _legendDot(
                'Severe', '${traffic.severePct.toStringAsFixed(0)}%', const Color(0xFFFF3B5C)),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: const TextStyle(fontSize: 10, color: Color(0xFF5C6B7A)),
        ),
      ],
    );
  }
}
