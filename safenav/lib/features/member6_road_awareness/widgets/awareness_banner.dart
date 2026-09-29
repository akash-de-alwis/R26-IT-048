import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/map/widgets/island_pill.dart';
import '../../../member3_alert_system/part2/widgets/obstacle_report_sheet.dart';
import '../models/awareness_alert_model.dart';
import '../models/proximity_tier.dart';
import '../services/awareness_orchestrator.dart';

/// The single road-awareness alert (camera proximity or route hazard) as a
/// compact island pill. Which alert shows is decided by
/// [AwarenessOrchestrator]; this widget only renders it. Tap to expand a
/// short tip with Dismiss (hides this alert until a different one) and,
/// for route hazards, Report. Shows the orchestrator's notice otherwise.
class AwarenessBanner extends StatefulWidget {
  const AwarenessBanner({super.key});

  @override
  State<AwarenessBanner> createState() => _AwarenessBannerState();
}

class _AwarenessBannerState extends State<AwarenessBanner> {
  String? _dismissedKey;
  String? _expandedKey;

  @override
  Widget build(BuildContext context) {
    final alert = context.select<AwarenessOrchestrator, AwarenessAlert?>(
        (o) => o.activeAlert);
    final notice =
        context.select<AwarenessOrchestrator, String?>((o) => o.notice);
    final showAlert = alert != null && alert.key != _dismissedKey;

    final Widget child;
    if (showAlert) {
      // Keyed by the object: a tier change on the same alert only tweens
      // the colour, a different object slides in fresh
      child = _AlertPill(
        key: ValueKey(alert.key),
        alert: alert,
        expanded: _expandedKey == alert.key,
        onTap: () => setState(() =>
            _expandedKey = _expandedKey == alert.key ? null : alert.key),
        onDismiss: () => setState(() => _dismissedKey = alert.key),
      );
    } else if (alert == null && notice != null) {
      child = IslandPill(
        key: const ValueKey('notice'),
        accent: const Color(0xFFFFB300),
        leading: const Icon(Icons.info_outline_rounded),
        title: notice,
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('none'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _AlertPill extends StatelessWidget {
  final AwarenessAlert alert;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _AlertPill({
    super.key,
    required this.alert,
    required this.expanded,
    required this.onTap,
    required this.onDismiss,
  });

  static final _leadingNumber = RegExp(r'^(\d+(?:\.\d+)?)\s*m\b');

  bool get _isRoute => alert.source == AlertSource.route;

  /// Distance from the orchestrator's subtitle ("2.2 m ...", "320 m ahead").
  String? get _distance => alert.subtitle == null
      ? null
      : _leadingNumber.firstMatch(alert.subtitle!)?.group(1);

  String get _subtitle {
    if (_isRoute) {
      final d = _distance;
      return d != null ? 'in $d m' : (alert.subtitle ?? '');
    }
    final tier = alert.tier.label;
    final beside = alert.subtitle?.contains('beside the path') ?? false;
    return beside ? '$tier · beside the path' : tier;
  }

  String get _tip => switch (alert.tier) {
        ProximityTier.critical => 'Brake now and keep your distance',
        ProximityTier.veryClose => 'Slow down and keep distance',
        _ when _isRoute => 'Reduce speed and watch the road ahead',
        _ => 'Stay alert and keep a safe gap',
      };

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ObstacleReportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = alert.tier == ProximityTier.none
        ? const Color(0xFF00C06A)
        : alert.tier.color;
    final distance = _distance;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 300),
      builder: (context, color, _) {
        final accent = color ?? target;
        return IslandPill(
          accent: accent,
          pulsing: alert.tier == ProximityTier.critical,
          onTap: onTap,
          leading: Icon(alert.icon),
          title: alert.title,
          subtitle: _subtitle,
          trailing: distance == null
              ? null
              : IslandPillValue(value: distance, unit: 'm', accent: accent),
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tip,
                          style: const TextStyle(
                            fontSize: 12,
                            color: IslandPill.textSecondary,
                          ),
                        ),
                      ),
                      if (_isRoute)
                        _action('Report', accent,
                            () => _openReportSheet(context)),
                      _action('Dismiss', accent, onDismiss),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _action(String label, Color color, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
