import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enhanced_route_model.dart';
import '../services/enhanced_route_service.dart';
import 'enhanced_route_card.dart';
import 'road_type_breakdown_card.dart';

class EnhancedRouteOptionsSheet extends StatelessWidget {
  final String? destinationName;

  const EnhancedRouteOptionsSheet({super.key, this.destinationName});

  static Future<EnhancedRouteModel?> show(
    BuildContext context,
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    String? destinationName,
  }) {
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
      builder: (_) =>
          EnhancedRouteOptionsSheet(destinationName: destinationName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Consumer<EnhancedRouteService>(
          builder: (ctx, service, _) => Column(
            children: [
              // ── Fixed header ─────────────────────────────────────────────
              _buildHandle(),
              _buildHeader(context),
              const Divider(color: Color(0xFFEEF1F5), height: 1),

              // ── Scrollable body ──────────────────────────────────────────
              Expanded(
                child: service.isLoading
                    ? _buildShimmer()
                    : service.errorMessage != null
                        ? _buildError(ctx, service)
                        : _buildRoutes(scrollController, service),
              ),

              // ── Sticky Start Navigation button ───────────────────────────
              if (!service.isLoading && service.selectedRoute != null)
                _buildStartButton(context, service.selectedRoute!),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFDDE3EA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2979FF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.alt_route_rounded,
                color: Color(0xFF2979FF), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Your Route',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destinationName != null
                      ? 'To: $destinationName'
                      : 'Live traffic + accident risk analyzed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5C6B7A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 22,
                color: Color(0xFF5C6B7A)),
          ),
        ],
      ),
    );
  }

  // ── Loading shimmer ─────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: List.generate(3, (i) => _ShimmerRouteCard(delay: i * 180)),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, EnhancedRouteService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 32, color: Color(0xFFFF3B5C)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load routes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              service.errorMessage ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5C6B7A), height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => service.fetchRoutes(
                originLat: 0,
                originLng: 0,
                destLat: 0,
                destLng: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2979FF),
                side: const BorderSide(color: Color(0xFF2979FF)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Route list ──────────────────────────────────────────────────────────────

  Widget _buildRoutes(
      ScrollController scrollController, EnhancedRouteService service) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single-route notice
          if (service.routes.length == 1)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFFFB300)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only one practical route found. Choose a destination '
                      'further away for more options.',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF633806), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // Route cards
          ...service.routes.map(
            (r) => EnhancedRouteCard(
              route: r,
              isSelected: service.selectedRoute?.routeType == r.routeType,
              onTap: () => service.selectRoute(r),
            ),
          ),

          // Road type breakdown for selected route
          if (service.selectedRoute != null) ...[
            const SizedBox(height: 4),
            const Text(
              'Route Details',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 10),
            RoadTypeBreakdownCard(
                breakdown: service.selectedRoute!.roadTypeBreakdown),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Sticky Start Navigation button ─────────────────────────────────────────

  Widget _buildStartButton(
      BuildContext context, EnhancedRouteModel selected) {
    final arrive = DateTime.now()
        .add(Duration(seconds: selected.durationInTrafficSeconds.round()));
    final h = arrive.hour;
    final m = arrive.minute;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final arrivalLabel = '$hour:${m.toString().padLeft(2, '0')} $suffix';

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2979FF),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Start Navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Arrive ~$arrivalLabel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer skeleton card ─────────────────────────────────────────────────────

class _ShimmerRouteCard extends StatefulWidget {
  final int delay;

  const _ShimmerRouteCard({this.delay = 0});

  @override
  State<_ShimmerRouteCard> createState() => _ShimmerRouteCardState();
}

class _ShimmerRouteCardState extends State<_ShimmerRouteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final base = Color.lerp(
          const Color(0xFFF0F3F7),
          const Color(0xFFE2E8F0),
          _anim.value,
        )!;
        final highlight = Colors.white.withValues(alpha: 0.55);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent strip placeholder
                Container(
                  height: 5,
                  color: Color.lerp(
                    const Color(0xFFDDE3EA),
                    const Color(0xFFC8D0DC),
                    _anim.value,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          _box(40, 40, highlight, radius: 11),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _box(110, 14, highlight, radius: 5),
                              const SizedBox(height: 7),
                              _box(64, 10, highlight, radius: 4),
                            ],
                          ),
                          const Spacer(),
                          _box(76, 32, highlight, radius: 10),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Metrics band placeholder
                      _box(double.infinity, 48, highlight, radius: 10),
                      const SizedBox(height: 12),
                      // Traffic bar placeholder
                      _box(double.infinity, 6, highlight, radius: 3),
                      const SizedBox(height: 10),
                      // Summary lines
                      _box(double.infinity, 9, highlight, radius: 3),
                      const SizedBox(height: 5),
                      _box(160, 9, highlight, radius: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _box(double w, double h, Color color, {double radius = 4}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
