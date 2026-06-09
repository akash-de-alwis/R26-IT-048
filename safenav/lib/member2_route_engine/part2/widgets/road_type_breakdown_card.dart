import 'package:flutter/material.dart';
import '../models/road_type_breakdown_model.dart';

class RoadTypeBreakdownCard extends StatelessWidget {
  final List<RoadTypeBreakdown> breakdown;

  const RoadTypeBreakdownCard({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF1F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF2979FF)),
              SizedBox(width: 8),
              Text(
                'Road Type Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1B2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...breakdown.take(4).map((b) => _RoadTypeRow(item: b)),
        ],
      ),
    );
  }
}

class _RoadTypeRow extends StatelessWidget {
  final RoadTypeBreakdown item;

  const _RoadTypeRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final roadColor = RoadTypeBreakdown.colors[item.roadClass] ??
        const Color(0xFF5C6B7A);
    final roadIcon = RoadTypeBreakdown.icons[item.roadClass] ??
        Icons.help_outline_rounded;
    final roadLabel =
        RoadTypeBreakdown.labels[item.roadClass] ?? item.roadClass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: roadColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(roadIcon, size: 14, color: roadColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roadLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0D1B2A),
                      ),
                    ),
                    Text(
                      '${(item.distanceM / 1000).toStringAsFixed(1)} km'
                      ' · risk x${item.riskMultiplier.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF5C6B7A)),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.pctOfRoute.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: roadColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (item.pctOfRoute / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFEEF1F5),
              valueColor: AlwaysStoppedAnimation<Color>(roadColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
