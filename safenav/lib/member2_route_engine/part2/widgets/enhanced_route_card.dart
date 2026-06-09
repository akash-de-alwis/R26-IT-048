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
    final c = route.color;
    final safetyC = _safetyColor(route.safetyScore);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? c : const Color(0xFFEEF1F5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Colored top accent strip ──────────────────────────────────
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c, c.withValues(alpha: 0.45)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(_routeIcon, size: 20, color: c),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1B2A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  route.badge,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: c,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Safety score pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: safetyC.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded,
                                  size: 13, color: safetyC),
                              const SizedBox(width: 4),
                              Text(
                                route.safetyScore.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: safetyC,
                                  height: 1,
                                ),
                              ),
                              Text(
                                '/100',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: safetyC.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                                color: c, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                size: 15, color: Colors.white),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Metrics band ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _metric(Icons.timer_outlined,
                                route.durationDisplay, 'Duration'),
                            _divider(),
                            _metric(Icons.straighten_rounded,
                                route.distanceDisplay, 'Distance'),
                            _divider(),
                            _metric(Icons.warning_amber_rounded,
                                '${route.hotspotsOnRoute}', 'Hotspots'),
                            _divider(),
                            _metric(
                              Icons.traffic_rounded,
                              route.traffic.displayLabel,
                              'Traffic',
                              valueColor: route.traffic.overallColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Traffic breakdown bar ─────────────────────────────────
                    TrafficBreakdownBar(traffic: route.traffic),

                    const SizedBox(height: 8),

                    // ── Summary ───────────────────────────────────────────────
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
            ],
          ),
        ),
      ),
    );
  }

  IconData get _routeIcon {
    switch (route.routeType) {
      case 'safest':
        return Icons.shield_outlined;
      case 'fastest':
        return Icons.bolt_rounded;
      case 'balanced':
        return Icons.balance_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  Widget _metric(IconData icon, String value, String label,
      {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8A97A8)),
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

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: const Color(0xFFEEF1F5),
      );

  Color _safetyColor(double score) {
    if (score >= 75) return const Color(0xFF00C06A);
    if (score >= 50) return const Color(0xFFFFB300);
    return const Color(0xFFFF3B5C);
  }
}
