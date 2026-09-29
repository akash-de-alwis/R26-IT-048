import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../models/enhanced_route_model.dart';
import '../services/enhanced_route_service.dart';
import 'enhanced_route_card.dart';
import 'road_type_breakdown_card.dart';

class EnhancedRouteOptionsSheet extends StatefulWidget {
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
    final service = context.read<EnhancedRouteService>();
    service.fetchRoutes(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    return showModalBottomSheet<EnhancedRouteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Light scrim so the selected route stays readable behind the sheet
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (_) =>
          EnhancedRouteOptionsSheet(destinationName: destinationName),
    ).whenComplete(service.onSheetClosed);
  }

  @override
  State<EnhancedRouteOptionsSheet> createState() =>
      _EnhancedRouteOptionsSheetState();
}

class _EnhancedRouteOptionsSheetState extends State<EnhancedRouteOptionsSheet> {
  // Initial / full-list size leaves ~40% of the map visible above the sheet.
  static const double _fullSize = 0.60;
  static const double _maxSize = 0.95;
  static const Duration _snapDuration = Duration(milliseconds: 300);

  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  /// false = full comparison list, true = compact peek card.
  bool _peek = false;
  bool _programmaticMove = false;

  // Measured heights (logical px) used to size the peek state exactly.
  double? _peekContentH;
  double? _startButtonH;
  double? _sheetParentH;

  /// minChildSize passed to the sheet in the last build.
  double _appliedMinSize = 0.30;

  String? get destinationName => widget.destinationName;

  @override
  void initState() {
    super.initState();
    _sheetCtrl.addListener(_onSheetMoved);
  }

  @override
  void dispose() {
    _sheetCtrl.removeListener(_onSheetMoved);
    _sheetCtrl.dispose();
    super.dispose();
  }

  /// Peek size = measured peek content + Start Navigation button (which
  /// already includes the bottom safe-area inset), as a fraction of the
  /// sheet's parent height. Falls back to estimates until measured.
  double get _peekSize {
    final parent = _sheetParentH;
    if (parent == null || parent <= 0) return _appliedMinSize;
    final px = (_peekContentH ?? 150) + (_startButtonH ?? 112);
    return (px / parent).clamp(0.10, _fullSize - 0.05);
  }

  void _onPeekContentSize(Size size) {
    _peekContentH = size.height;
    _syncMinSize();
  }

  void _onStartButtonSize(Size size) {
    _startButtonH = size.height;
    _syncMinSize();
  }

  /// Rebuilds with the measured min size; if resting in peek, settles the
  /// sheet onto it so no gap is left above the Start button.
  void _syncMinSize() {
    if (!mounted || (_peekSize - _appliedMinSize).abs() < 0.002) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _peek && !_programmaticMove) _animateSheetTo(_peekSize);
    });
  }

  /// Full list dragged down to the peek minimum collapses to peek (once a
  /// route is selected). Peek drags are handled by [_onPeekDragUpdate].
  void _onSheetMoved() {
    if (_peek || _programmaticMove || !_sheetCtrl.isAttached) return;
    if (_sheetCtrl.size <= _appliedMinSize + 0.02 &&
        context.read<EnhancedRouteService>().selectedRoute != null) {
      _collapseToPeek();
    }
  }

  Future<void> _animateSheetTo(double size) async {
    if (!_sheetCtrl.isAttached) return;
    _programmaticMove = true;
    try {
      await _sheetCtrl.animateTo(
        size,
        duration: _snapDuration,
        curve: Curves.easeOut,
      );
    } finally {
      _programmaticMove = false;
    }
  }

  /// Card tap in the full list: select (redraw + camera fit happen through
  /// the service's existing onRouteChanged hook), then collapse to peek.
  void _onRouteCardTap(EnhancedRouteService service, EnhancedRouteModel r) {
    if (service.selectedRoute?.routeType != r.routeType) {
      service.selectRoute(r);
    }
    _collapseToPeek();
  }

  /// Swap to the peek content first, then animate once the new scroll view
  /// is attached and the peek content has been measured (animating in the
  /// same frame as the swap leaves the sheet at full-list size).
  void _collapseToPeek() {
    setState(() => _peek = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Measurement callbacks from this frame run after this one; wait one
      // more frame so the sheet's minChildSize reflects them.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _peek) _animateSheetTo(_peekSize);
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  /// Same swap-then-animate ordering as [_collapseToPeek].
  void _openFullList() {
    setState(() => _peek = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_peek) _animateSheetTo(_fullSize);
    });
  }

  /// Peek drags move the sheet directly, so the content is not swapped
  /// mid-gesture and the modal route can never be dragged closed.
  void _onPeekDragUpdate(DragUpdateDetails d) {
    final parent = _sheetParentH;
    if (!_sheetCtrl.isAttached || parent == null) return;
    _sheetCtrl.jumpTo(
      (_sheetCtrl.size - d.delta.dy / parent).clamp(_appliedMinSize, _maxSize),
    );
  }

  /// On release: dragged up past a small threshold (or flung up) reopens
  /// the full list, otherwise settle back onto the peek minimum.
  void _onPeekDragEnd(DragEndDetails d) {
    if (!_sheetCtrl.isAttached) return;
    final flungUp = (d.primaryVelocity ?? 0) < -500;
    if (flungUp || _sheetCtrl.size > _appliedMinSize + 0.06) {
      _openFullList();
    } else {
      _animateSheetTo(_appliedMinSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _sheetParentH = constraints.maxHeight;
        _appliedMinSize = _peekSize;
        return _buildSheet(context);
      },
    );
  }

  Widget _buildSheet(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: _fullSize,
      minChildSize: _appliedMinSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_fullSize],
      snapAnimationDuration: _snapDuration,
      // Resting at the peek minimum must never close route selection.
      shouldCloseOnMinExtent: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Consumer<EnhancedRouteService>(
          builder: (ctx, service, _) {
            final showPeek =
                _peek && !service.isLoading && service.selectedRoute != null;
            return GestureDetector(
              onVerticalDragUpdate: showPeek ? _onPeekDragUpdate : null,
              onVerticalDragEnd: showPeek ? _onPeekDragEnd : null,
              child: Column(
                children: [
                  if (showPeek)
                    // ── Peek: compact selected-route card ────────────────────
                    Expanded(child: _buildPeek(scrollController, service))
                  else ...[
                    // ── Fixed header ─────────────────────────────────────────
                    _buildHandle(),
                    _buildHeader(context),
                    const Divider(color: Color(0xFFEEF1F5), height: 1),

                    // ── Scrollable body ──────────────────────────────────────
                    Expanded(
                      child: service.isLoading
                          ? _buildShimmer(service)
                          : service.routes.isEmpty &&
                                service.errorMessage != null
                          ? _buildError(ctx, service)
                          : _buildRoutes(scrollController, service),
                    ),
                  ],

                  // ── Sticky Start Navigation button ─────────────────────────
                  if (!service.isLoading && service.selectedRoute != null)
                    _MeasureSize(
                      onSize: _onStartButtonSize,
                      child: _buildStartButton(context, service.selectedRoute!),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Peek state ──────────────────────────────────────────────────────────────

  static IconData _routeIcon(String routeType) {
    switch (routeType) {
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

  static Color _safetyColor(double score) {
    if (score >= 75) return const Color(0xFF00C06A);
    if (score >= 50) return const Color(0xFFFFB300);
    return const Color(0xFFFF3B5C);
  }

  Widget _buildPeek(
    ScrollController scrollController,
    EnhancedRouteService service,
  ) {
    final r = service.selectedRoute!;
    final c = r.color;
    final safetyC = _safetyColor(r.safetyScore);

    // Stays attached to the sheet's controller (animateTo needs a position)
    // but does not scroll: peek drags go through _onPeekDragUpdate.
    return SingleChildScrollView(
      controller: scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: _MeasureSize(
        onSize: _onPeekContentSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Material(
                color: c.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: c, width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openFullList,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            _routeIcon(r.routeType),
                            size: 19,
                            color: c,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1B2A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${r.durationDisplay} · ${r.distanceDisplay}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5C6B7A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.shield_rounded,
                                    size: 12,
                                    color: safetyC,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    r.safetyScore.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: safetyC,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 20,
                              color: Color(0xFF5C6B7A),
                            ),
                            Text(
                              'Compare',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5C6B7A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (service.routes.length > 1) _buildRouteSwitcher(service),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Compact chips to switch routes while staying in peek.
  Widget _buildRouteSwitcher(EnhancedRouteService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final r in service.routes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _routeChip(
                  r,
                  selected: service.selectedRoute?.routeType == r.routeType,
                  onTap: () {
                    if (service.selectedRoute?.routeType != r.routeType) {
                      service.selectRoute(r);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _routeChip(
    EnhancedRouteModel r, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = r.color;
    return Material(
      color: selected ? c.withValues(alpha: 0.12) : const Color(0xFFF4F6F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _routeIcon(r.routeType),
                size: 14,
                color: selected ? c : const Color(0xFF5C6B7A),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  r.durationDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? c : const Color(0xFF5C6B7A),
                  ),
                ),
              ),
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

  Widget _buildShimmer(EnhancedRouteService service) {
    final status = service.isSlow
        ? 'Slow connection - still trying (attempt '
            '${service.attemptCount.clamp(1, EnhancedRouteService.maxAttempts)} '
            'of ${EnhancedRouteService.maxAttempts})...'
        : 'Finding safe routes...';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: service.isSlow
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF2979FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF5C6B7A)),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(3, (i) => _ShimmerRouteCard(delay: i * 180)),
        ],
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, EnhancedRouteService service) {
    final (IconData icon, String title, String message) =
        switch (service.errorType) {
      RouteErrorType.offline => (
          Icons.wifi_off_rounded,
          "You're offline",
          "We'll retry automatically when you're back online.",
        ),
      RouteErrorType.timeout => (
          Icons.hourglass_bottom_rounded,
          'Connection is slow',
          'Try again, or move to an area with better signal.',
        ),
      RouteErrorType.server => (
          Icons.cloud_off_rounded,
          'Service is busy',
          'Please try again in a moment.',
        ),
      _ => (
          Icons.cloud_off_rounded,
          'Could not load routes',
          service.errorMessage ?? 'Please check your connection and try again.',
        ),
    };

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
              child: Icon(icon, size: 32, color: const Color(0xFFFF3B5C)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5C6B7A), height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: service.retry,
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
            if (service.errorDetail != null) ...[
              const SizedBox(height: 12),
              Text(
                service.errorDetail!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFFA0AAB5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Saved-route banner ──────────────────────────────────────────────────────

  Widget _buildSavedBanner(EnhancedRouteService service) {
    final savedAt = service.savedAt;
    String? age;
    if (savedAt != null) {
      final mins = DateTime.now().difference(savedAt).inMinutes;
      age = mins < 1
          ? 'Saved just now'
          : mins < 60
              ? 'Saved $mins min ago'
              : 'Saved ${mins ~/ 60} h ago';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 16, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Showing a saved route - live data unavailable',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF633806), height: 1.4),
                ),
                if (age != null)
                  Text(
                    age,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF8A6A3A)),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: service.retry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2979FF),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Refresh',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
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
          // Saved / degraded data notice
          if (service.showingSavedRoutes) _buildSavedBanner(service),

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
              onTap: () => _onRouteCardTap(service, r),
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
      builder: (_, _) {
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

// ── Size reporter ─────────────────────────────────────────────────────────────

/// Reports its child's laid-out size after the frame whenever it changes.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSize;

  const _MeasureSize({required this.onSize, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  ValueChanged<Size> onSize;
  Size? _last;

  _RenderMeasureSize(this.onSize);

  @override
  void performLayout() {
    super.performLayout();
    final current = size;
    if (current == _last) return;
    _last = current;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(current));
  }
}
