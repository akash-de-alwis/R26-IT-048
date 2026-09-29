import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../member3_alert_system/part2/services/obstacle_scan_service.dart';
import 'island_pill.dart';

enum _ScanPhase { hidden, scanning, found, collapsed, clear, error }

/// Route hazard scan status as an island pill, driven by the existing
/// [ObstacleScanService] (isLoading / errorMessage / obstacles only).
///
/// scanning -> "N hazards on route" (4 s, then a small count chip that
/// re-expands on tap) | "Route clear" (fades after 3 s) | "Scan
/// unavailable" (fades after 3 s).
class RouteScanPill extends StatefulWidget {
  const RouteScanPill({super.key});

  @override
  State<RouteScanPill> createState() => _RouteScanPillState();
}

class _RouteScanPillState extends State<RouteScanPill> {
  static const _blue = Color(0xFF2979FF);
  static const _amber = Color(0xFFFFB300);
  static const _green = Color(0xFF00C06A);
  static const _grey = Color(0xFF5C6B7A);
  static const _foundHold = Duration(seconds: 4);
  static const _fadeAfter = Duration(seconds: 3);

  late final ObstacleScanService _scan;
  _ScanPhase _phase = _ScanPhase.hidden;
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scan = context.read<ObstacleScanService>();
    _scan.addListener(_onScanChanged);
    if (_scan.isLoading) _phase = _ScanPhase.scanning;
  }

  @override
  void dispose() {
    _scan.removeListener(_onScanChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onScanChanged() {
    if (!mounted) return;
    if (_scan.isLoading) {
      _timer?.cancel();
      if (_phase != _ScanPhase.scanning) {
        setState(() => _phase = _ScanPhase.scanning);
      }
      return;
    }
    if (_phase == _ScanPhase.scanning) {
      if (_scan.errorMessage != null) {
        _show(_ScanPhase.error, then: _ScanPhase.hidden, after: _fadeAfter);
      } else if (_scan.obstacles.isEmpty) {
        _show(_ScanPhase.clear, then: _ScanPhase.hidden, after: _fadeAfter);
      } else {
        _count = _scan.obstacles.length;
        _show(_ScanPhase.found, then: _ScanPhase.collapsed, after: _foundHold);
      }
    } else if ((_phase == _ScanPhase.found ||
            _phase == _ScanPhase.collapsed) &&
        _scan.obstacles.isEmpty) {
      // Results cleared (trip ended)
      _timer?.cancel();
      setState(() => _phase = _ScanPhase.hidden);
    }
  }

  void _show(_ScanPhase phase,
      {required _ScanPhase then, required Duration after}) {
    _timer?.cancel();
    setState(() => _phase = phase);
    _timer = Timer(after, () {
      if (mounted && _phase == phase) setState(() => _phase = then);
    });
  }

  void _expandFound() =>
      _show(_ScanPhase.found, then: _ScanPhase.collapsed, after: _foundHold);

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_phase) {
      _ScanPhase.hidden => const SizedBox.shrink(key: ValueKey('hidden')),
      _ScanPhase.scanning => const IslandPill(
          key: ValueKey('scanning'),
          accent: _blue,
          leading: _RotatingRadar(),
          title: 'Scanning route',
          subtitle: 'Accidents · Road works · Hazards',
          trailing: _LiveTag(),
          bottom: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0x992979FF)),
            ),
          ),
        ),
      _ScanPhase.found => IslandPill(
          key: const ValueKey('found'),
          accent: _amber,
          leading: const Icon(Icons.warning_amber_rounded),
          title: '$_count hazard${_count == 1 ? '' : 's'} on route',
          trailing: IslandPillValue(value: '$_count', accent: _amber),
        ),
      _ScanPhase.collapsed => Align(
          key: const ValueKey('collapsed'),
          alignment: Alignment.centerLeft,
          child: _CountChip(count: _count, color: _amber, onTap: _expandFound),
        ),
      _ScanPhase.clear => const IslandPill(
          key: ValueKey('clear'),
          accent: _green,
          leading: Icon(Icons.verified_rounded),
          title: 'Route clear',
        ),
      _ScanPhase.error => const IslandPill(
          key: ValueKey('error'),
          accent: _grey,
          leading: Icon(Icons.cloud_off_rounded),
          title: 'Scan unavailable',
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Radar icon doing one full turn every 2 s.
class _RotatingRadar extends StatefulWidget {
  const _RotatingRadar();

  @override
  State<_RotatingRadar> createState() => _RotatingRadarState();
}

class _RotatingRadarState extends State<_RotatingRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: const Icon(Icons.radar_rounded),
    );
  }
}

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
    const blue = Color(0xFF2979FF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
          child: Container(
            width: 6,
            height: 6,
            decoration:
                const BoxDecoration(color: blue, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: blue,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// Collapsed "found" state: small circle with the hazard count.
class _CountChip extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CountChip({
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
