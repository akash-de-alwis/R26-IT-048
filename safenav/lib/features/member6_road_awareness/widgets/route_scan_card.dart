import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../member3_alert_system/part2/services/obstacle_scan_service.dart';

/// Card shown while the route hazard scan runs. When the scan finishes it
/// briefly shows the result, then dismisses itself; a failed scan hides at
/// once. Driven by [ObstacleScanService.isLoading].
class RouteScanCard extends StatefulWidget {
  const RouteScanCard({super.key});

  @override
  State<RouteScanCard> createState() => _RouteScanCardState();
}

enum _Phase { hidden, scanning, done }

class _RouteScanCardState extends State<RouteScanCard> {
  static const _doneHold = Duration(milliseconds: 2500);

  late final ObstacleScanService _scan;
  _Phase _phase = _Phase.hidden;
  int _found = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scan = context.read<ObstacleScanService>();
    _scan.addListener(_onScanChanged);
    if (_scan.isLoading) _phase = _Phase.scanning;
  }

  @override
  void dispose() {
    _scan.removeListener(_onScanChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScanChanged() {
    if (!mounted) return;
    if (_scan.isLoading) {
      _hideTimer?.cancel();
      if (_phase != _Phase.scanning) setState(() => _phase = _Phase.scanning);
    } else if (_phase == _Phase.scanning) {
      if (_scan.errorMessage != null) {
        setState(() => _phase = _Phase.hidden);
        return;
      }
      setState(() {
        _phase = _Phase.done;
        _found = _scan.obstacles.length;
      });
      _hideTimer?.cancel();
      _hideTimer = Timer(_doneHold, () {
        if (mounted) setState(() => _phase = _Phase.hidden);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: _phase == _Phase.hidden
          ? const SizedBox.shrink(key: ValueKey('hidden'))
          : _ScanCardBody(
              key: const ValueKey('card'),
              done: _phase == _Phase.done,
              found: _found,
            ),
    );
  }
}

class _ScanCardBody extends StatelessWidget {
  final bool done;
  final int found;

  const _ScanCardBody({super.key, required this.done, required this.found});

  static const _blue = Color(0xFF2979FF);
  static const _green = Color(0xFF00C06A);

  @override
  Widget build(BuildContext context) {
    final accent = done ? _green : _blue;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFFEBFBF3)
                        : const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    done ? Icons.check_circle_rounded : Icons.radar_rounded,
                    size: 21,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              done ? 'Route checked' : 'Scanning route',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D1B2A),
                              ),
                            ),
                          ),
                          if (!done) ...[
                            const SizedBox(width: 8),
                            const _LiveTag(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done
                            ? (found == 0
                                ? 'No hazards found ahead'
                                : '$found hazard${found == 1 ? '' : 's'} marked on your route')
                            : 'Checking for hazards ahead',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5C6B7A),
                        ),
                      ),
                      if (!done) ...[
                        const SizedBox(height: 10),
                        const Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _CategoryChip(
                                icon: Icons.car_crash_outlined,
                                label: 'Accidents'),
                            _CategoryChip(
                                icon: Icons.construction_rounded,
                                label: 'Road works'),
                            _CategoryChip(
                                icon: Icons.warning_amber_rounded,
                                label: 'Hazards'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 3,
            child: done
                ? const LinearProgressIndicator(
                    value: 1,
                    backgroundColor: Color(0xFFEBFBF3),
                    valueColor: AlwaysStoppedAnimation<Color>(_green),
                  )
                : const LinearProgressIndicator(
                    backgroundColor: Color(0xFFE8F0FE),
                    valueColor: AlwaysStoppedAnimation<Color>(_blue),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Inline pulsing dot + "LIVE" text (no box).
class _LiveTag extends StatefulWidget {
  const _LiveTag();

  @override
  State<_LiveTag> createState() => _LiveTagState();
}

class _LiveTagState extends State<_LiveTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF2979FF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2979FF),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CategoryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2979FF)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2979FF),
            ),
          ),
        ],
      ),
    );
  }
}
