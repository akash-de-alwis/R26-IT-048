import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../member5_vehicle_distance/widgets/trip_distance_summary_card.dart';

/// End-of-trip sheet around the Member 5 [TripDistanceSummaryCard].
///
/// Clears the floating bottom navigation bar, scrolls when tall, can be
/// closed with the close button, a drag or a tap outside, and opens at
/// most once per trip.
class AwarenessTripSummarySheet extends StatefulWidget {
  /// Space kept free at the bottom for the floating navigation bar.
  static const navBarClearance = 110.0;
  static const _maxHeightFraction = 0.7;

  /// Trip the sheet was last opened (or considered) for. Trip ids are
  /// unique, so a new trip resets this guard automatically.
  static String? _handledTripId;

  final String tripId;
  final bool initiallyFailed;

  const AwarenessTripSummarySheet({
    super.key,
    required this.tripId,
    this.initiallyFailed = false,
  });

  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  /// total_events for the trip, or null if the stats could not be loaded.
  static Future<int?> fetchTotalEvents(String tripId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/v3/distance/trip/$tripId/stats'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['total_events'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[trip_summary] stats failed: $e');
      return null;
    }
  }

  /// Opens the sheet only if events were logged this trip AND the backend
  /// reports total_events > 0. If the stats cannot be loaded (but events
  /// were logged), it opens with a Retry option instead of the card.
  static Future<void> maybeShow(
    BuildContext context, {
    required String tripId,
    required int loggedEvents,
  }) async {
    if (loggedEvents <= 0) return;
    if (_handledTripId == tripId) return; // once per trip
    _handledTripId = tripId;

    final total = await fetchTotalEvents(tripId);
    if (total == 0) return;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AwarenessTripSummarySheet(
        tripId: tripId,
        initiallyFailed: total == null,
      ),
    );
  }

  @override
  State<AwarenessTripSummarySheet> createState() =>
      _AwarenessTripSummarySheetState();
}

enum _LoadState { loading, ready, failed }

class _AwarenessTripSummarySheetState extends State<AwarenessTripSummarySheet> {
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF5C6B7A);

  late _LoadState _state =
      widget.initiallyFailed ? _LoadState.failed : _LoadState.ready;
  int _attempt = 0; // new key -> the card fetches again

  Future<void> _retry() async {
    setState(() => _state = _LoadState.loading);
    final total = await AwarenessTripSummarySheet.fetchTotalEvents(widget.tripId);
    if (!mounted) return;
    if (total == 0) {
      Navigator.of(context).pop(); // nothing to summarise
      return;
    }
    setState(() {
      _state = total == null ? _LoadState.failed : _LoadState.ready;
      _attempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad =
        mq.padding.bottom + AwarenessTripSummarySheet.navBarClearance;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * AwarenessTripSummarySheet._maxHeightFraction,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6F9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Trip summary',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
            ),
            // Body scrolls if taller than the space left
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPad),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case _LoadState.failed:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 28, color: _muted),
              const SizedBox(height: 8),
              const Text(
                "We couldn't load your trip summary right now.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _ink),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      case _LoadState.ready:
        // The card loads its own stats and shows its own spinner meanwhile
        return TripDistanceSummaryCard(
          key: ValueKey(_attempt),
          tripId: widget.tripId,
        );
    }
  }
}
