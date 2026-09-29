import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'awareness_banner.dart';
import 'route_scan_card.dart';

/// The route-scan card and the awareness alert banner, floating just above
/// the trip sheet's top edge and following it as the sheet is dragged.
///
/// Fill the Stack with this (e.g. inside Positioned.fill). [sheetExtent] is
/// the sheet's current size as a fraction of the screen height. The cards
/// never rise above [minTop], so at tall sheet sizes they stop just under
/// the trip status bar instead of covering it. When the cards rise into
/// the band down to [avoidBottom] (e.g. the camera preview), they narrow
/// by [avoidRightWidth] so they don't run underneath it.
class AwarenessFloatingCards extends StatelessWidget {
  final ValueListenable<double> sheetExtent;
  final double minTop;
  final double gap;
  final double avoidRightWidth;
  final double avoidBottom;

  const AwarenessFloatingCards({
    super.key,
    required this.sheetExtent,
    required this.minTop,
    this.gap = 8,
    this.avoidRightWidth = 0,
    this.avoidBottom = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: sheetExtent,
      builder: (context, extent, child) => CustomSingleChildLayout(
        delegate: _AboveSheetLayout(
          extent: extent,
          minTop: minTop,
          gap: gap,
          avoidRightWidth: avoidRightWidth,
          avoidBottom: avoidBottom,
        ),
        child: child,
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RouteScanCard(),
          AwarenessBanner(),
        ],
      ),
    );
  }
}

class _AboveSheetLayout extends SingleChildLayoutDelegate {
  // Typical height of one card; used to decide the width before layout
  static const _estimatedCardHeight = 110.0;

  final double extent;
  final double minTop;
  final double gap;
  final double avoidRightWidth;
  final double avoidBottom;

  _AboveSheetLayout({
    required this.extent,
    required this.minTop,
    required this.gap,
    required this.avoidRightWidth,
    required this.avoidBottom,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final sheetTop = constraints.maxHeight * (1 - extent);
    final estimatedTop = sheetTop - gap - _estimatedCardHeight;
    final narrow = avoidRightWidth > 0 && estimatedTop < avoidBottom;
    final width =
        math.max(0.0, constraints.maxWidth - (narrow ? avoidRightWidth : 0));
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, constraints.maxHeight - minTop),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Bottom of the cards sits `gap` above the sheet's top edge...
    final sheetTop = size.height * (1 - extent);
    final y = sheetTop - gap - childSize.height;
    // ...but never higher than minTop (below the trip status bar)
    return Offset(0, math.max(minTop, y));
  }

  @override
  bool shouldRelayout(_AboveSheetLayout old) =>
      old.extent != extent ||
      old.minTop != minTop ||
      old.gap != gap ||
      old.avoidRightWidth != avoidRightWidth ||
      old.avoidBottom != avoidBottom;
}
