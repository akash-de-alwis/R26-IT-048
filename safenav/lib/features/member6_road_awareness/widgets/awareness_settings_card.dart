import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../member3_alert_system/part2/services/obstacle_preference_service.dart';
import '../models/proximity_tier.dart';
import '../services/awareness_preference_service.dart';
import '../services/beep_engine.dart';
import 'distance_calibration_sheet.dart';

/// Profile card for Road Awareness: route hazard alerts and camera
/// proximity alerts behind one master switch.
class AwarenessSettingsCard extends StatelessWidget {
  const AwarenessSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AwarenessPreferenceService>(
      builder: (ctx, prefs, _) => _Body(prefs: prefs),
    );
  }
}

class _Body extends StatelessWidget {
  static const _blue = Color(0xFF2979FF);
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF5C6B7A);
  static const _divider = Divider(height: 1, color: Color(0xFFEEF1F5));

  final AwarenessPreferenceService prefs;
  const _Body({required this.prefs});

  /// Keeps the Member 3 route scan in step: it skips when this is off.
  void _syncRouteScan(BuildContext context) {
    context
        .read<ObstaclePreferenceService>()
        .setDetectionEnabled(prefs.masterEnabled && prefs.routeAlertsEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEF1F5), width: 0.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Master ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.radar_rounded,
                        color: _blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Road Awareness',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _ink)),
                        Text('Assistance only. Always watch the road.',
                            style: TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: prefs.masterEnabled,
                    activeThumbColor: _blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) async {
                      await prefs.setMasterEnabled(v);
                      if (context.mounted) _syncRouteScan(context);
                    },
                  ),
                ],
              ),
            ),

            if (prefs.masterEnabled) ...[
              _divider,

              // ── Route hazards ─────────────────────────────────────────
              _switchRow(
                icon: Icons.alt_route_rounded,
                title: 'Route hazard alerts',
                subtitle: 'Bends, slopes, crossings, bumps',
                value: prefs.routeAlertsEnabled,
                onChanged: (v) async {
                  await prefs.setRouteAlertsEnabled(v);
                  if (context.mounted) _syncRouteScan(context);
                },
              ),
              if (prefs.routeAlertsEnabled)
                _section(
                  'Route alert level',
                  _chips(
                    const [
                      ('CAUTION', 'All'),
                      ('WARNING', 'Warnings+'),
                      ('CRITICAL', 'Critical only'),
                    ],
                    prefs.routeThreshold,
                    prefs.setRouteThreshold,
                  ),
                ),
              _divider,

              // ── Camera proximity ──────────────────────────────────────
              _switchRow(
                icon: Icons.sensors_rounded,
                title: 'Camera proximity alerts',
                subtitle: 'Vehicles, pedestrians, objects',
                value: prefs.cameraProximityEnabled,
                onChanged: prefs.setCameraProximityEnabled,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(46, 0, 16, 10),
                child: Text(
                  'Uses the rear camera. Analysed on this phone, nothing is '
                  'recorded or uploaded.',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF9AA5B1)),
                ),
              ),
              if (prefs.cameraProximityEnabled) ...[
                _section(
                  'Following distance',
                  _chips(
                    const [
                      ('NEW_LEARNER', 'New learner (3 s)'),
                      ('STANDARD', 'Standard (2 s)'),
                      ('CAUTIOUS', 'Extra cautious (4 s)'),
                    ],
                    prefs.followingRule,
                    prefs.setFollowingRule,
                  ),
                ),
                _switchRow(
                  icon: Icons.camera_alt_outlined,
                  title: 'Show camera preview',
                  subtitle: 'Small live view with detected objects',
                  value: prefs.showCameraPreview,
                  onChanged: prefs.setShowCameraPreview,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    onPressed: () => DistanceCalibrationSheet.show(context),
                    icon: const Icon(Icons.straighten_rounded, size: 16),
                    label: Text(prefs.focalLengthPx == null
                        ? 'Calibrate distance'
                        : 'Calibrate distance (calibrated)'),
                    style: _outlined(),
                  ),
                ),
              ],
              _divider,

              // ── Beeps ─────────────────────────────────────────────────
              _switchRow(
                icon: Icons.volume_up_outlined,
                title: 'Beep sounds',
                subtitle: 'Faster beeps as objects get closer',
                value: prefs.beepsEnabled,
                onChanged: (v) async {
                  await prefs.setBeepsEnabled(v);
                  if (context.mounted) _syncRouteScan(context);
                },
              ),
              if (prefs.beepsEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 38),
                      const Icon(Icons.volume_down_rounded,
                          size: 16, color: _muted),
                      Expanded(
                        child: Slider(
                          value: prefs.beepVolume,
                          onChanged: prefs.setBeepVolume,
                          activeColor: _blue,
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded,
                          size: 16, color: _muted),
                    ],
                  ),
                ),
              _divider,

              // ── Voice ─────────────────────────────────────────────────
              _switchRow(
                icon: Icons.record_voice_over_outlined,
                title: 'Voice alerts',
                subtitle: 'Spoken warnings for hazards and close objects',
                value: prefs.voiceEnabled,
                onChanged: prefs.setVoiceEnabled,
              ),
              if (prefs.voiceEnabled)
                _section(
                  'Language',
                  _chips(
                    const [('en', 'English'), ('si', 'Sinhala')],
                    prefs.voiceLanguage,
                    prefs.setVoiceLanguage,
                  ),
                ),
              _divider,

              // ── Sound test ────────────────────────────────────────────
              _section(
                'Test beep patterns',
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _testButton(context, ProximityTier.far, 'Test far'),
                    _testButton(context, ProximityTier.closer, 'Test closer'),
                    _testButton(
                        context, ProximityTier.veryClose, 'Test very close'),
                    _testButton(
                        context, ProximityTier.critical, 'Test critical'),
                  ],
                ),
              ),
              _divider,

              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFF9AA5B1)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Camera proximity and drowsiness detection may not '
                        'both run on every phone.',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF9AA5B1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13, color: _ink)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 10.5, color: _muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: _blue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _chips(List<(String, String)> options, String current,
      Future<void> Function(String) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = current == opt.$1;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? _blue : const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _muted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _testButton(BuildContext context, ProximityTier tier, String label) {
    return OutlinedButton(
      onPressed: () {
        final beeps = context.read<BeepEngine>();
        beeps.setMasterVolume(prefs.beepVolume);
        beeps.playPatternOnce(tier);
      },
      style: _outlined(color: tier.color).copyWith(
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  ButtonStyle _outlined({Color color = _blue}) => OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
