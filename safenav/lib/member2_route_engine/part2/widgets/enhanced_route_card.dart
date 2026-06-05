import 'package:flutter/material.dart';
import '../models/enhanced_route_model.dart';
import 'traffic_breakdown_bar.dart';

class EnhancedRouteCard extends StatelessWidget {
  final EnhancedRouteModel route;
  final bool isSelected;
  final VoidCallback onTap;

  const EnhancedRouteCard({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? route.color : const Color(0xFFEEF1F5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: route.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: route.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  route.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: route.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    route.badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: route.color,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 12,
                        color: _safetyColor(route.safetyScore),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${route.safetyScore.toStringAsFixed(0)}/100',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _safetyColor(route.safetyScore),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Metrics row ───────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  _metricItem(
                      Icons.timer_outlined, route.durationDisplay, 'Duration'),
                  _vSeparator(),
                  _metricItem(Icons.straighten_rounded, route.distanceDisplay,
                      'Distance'),
                  _vSeparator(),
                  _metricItem(Icons.warning_amber_rounded,
                      '${route.hotspotsOnRoute}', 'Hotspots'),
                  _vSeparator(),
                  _metricItem(
                    Icons.traffic_rounded,
                    route.traffic.displayLabel,
                    'Traffic',
                    valueColor: route.traffic.overallColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Traffic breakdown bar ─────────────────────────────────────
            const Text(
              'Traffic distribution',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5C6B7A)),
            ),
            const SizedBox(height: 6),
            TrafficBreakdownBar(traffic: route.traffic),

            const SizedBox(height: 10),

            // ── Summary ───────────────────────────────────────────────────
            Text(
              route.summary,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5C6B7A),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(IconData icon, String value, String label,
      {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5C6B7A)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF0D1B2A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFFADB8C3)),
          ),
        ],
      ),
    );
  }

  Widget _vSeparator() => Container(
        width: 1,
        height: 32,
        color: const Color(0xFFEEF1F5),
      );

  Color _safetyColor(double score) {
    if (score >= 75) return const Color(0xFF00C06A);
    if (score >= 50) return const Color(0xFFFFB300);
    return const Color(0xFFFF3B5C);
  }
}
