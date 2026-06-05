import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enhanced_route_model.dart';
import '../services/enhanced_route_service.dart';
import 'enhanced_route_card.dart';
import 'road_type_breakdown_card.dart';

class EnhancedRouteOptionsSheet extends StatelessWidget {
  const EnhancedRouteOptionsSheet({super.key});

  static Future<EnhancedRouteModel?> show(
    BuildContext context,
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    context.read<EnhancedRouteService>().fetchRoutes(
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
        );

    return showModalBottomSheet<EnhancedRouteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EnhancedRouteOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Consumer<EnhancedRouteService>(
          builder: (_, service, _) => CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag handle ───────────────────────────────────────
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE3EA),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // ── Header ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2979FF)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.alt_route_rounded,
                              color: Color(0xFF2979FF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose Your Route',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                ),
                                Text(
                                  'Live traffic + accident risk analyzed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF5C6B7A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            iconSize: 22,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFEEF1F5), height: 16),

                    // ── Content ───────────────────────────────────────────
                    if (service.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF2979FF),
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Analyzing routes...',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF5C6B7A)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (service.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_off,
                                  size: 40, color: Color(0xFFADB8C3)),
                              const SizedBox(height: 12),
                              Text(
                                service.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFFF3B5C), fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => service.fetchRoutes(
                                  originLat: 0,
                                  originLng: 0,
                                  destLat: 0,
                                  destLng: 0,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),

                            // Single-route notice banner
                            if (service.routes.length == 1)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFB300)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 16, color: Color(0xFFFFB300)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Only one practical route exists for '
                                        'this trip. For more options, choose a '
                                        'destination further away.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF633806),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Route cards
                            ...service.routes.map(
                              (r) => EnhancedRouteCard(
                                route: r,
                                isSelected: service.selectedRoute?.routeType ==
                                    r.routeType,
                                onTap: () => service.selectRoute(r),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Road type breakdown for selected route
                            if (service.selectedRoute != null) ...[
                              const Text(
                                'Selected Route Details',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1B2A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              RoadTypeBreakdownCard(
                                breakdown:
                                    service.selectedRoute!.roadTypeBreakdown,
                              ),
                              const SizedBox(height: 16),

                              // Start Navigation button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    service.selectedRoute,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2979FF),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.navigation_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Start Navigation',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),
                            // Clear the floating bottom nav bar
                            SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 80,
                            ),
                          ],
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
}
