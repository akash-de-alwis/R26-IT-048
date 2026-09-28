import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/sensed_object_model.dart';
import '../services/awareness_preference_service.dart';
import '../services/distance_calibration_service.dart';
import '../services/object_detector_service.dart';

/// Calibrates the camera focal length from an object of known size at a
/// known distance. Starts the detector for the sheet if it is not already
/// running (e.g. during a trip) and stops it again on close.
class DistanceCalibrationSheet extends StatefulWidget {
  const DistanceCalibrationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DistanceCalibrationSheet(),
    );
  }

  @override
  State<DistanceCalibrationSheet> createState() =>
      _DistanceCalibrationSheetState();
}

class _DistanceCalibrationSheetState extends State<DistanceCalibrationSheet> {
  static const _blue = Color(0xFF2979FF);
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF5C6B7A);
  static const _framesToAverage = 10;
  static const _captureLimit = Duration(seconds: 10);

  late final ObjectDetectorService _detector;
  late final DistanceCalibrationService _calibration;
  final _distanceCtrl = TextEditingController(text: '5');

  String _label = 'person'; // 'person' or 'car'
  bool _startedHere = false;
  bool _starting = true;
  String? _error;
  bool _capturing = false;
  final List<Rect> _samples = [];
  List<SensedObject>? _lastSeenList;
  Timer? _timeoutTimer;
  String? _result;

  @override
  void initState() {
    super.initState();
    _detector = context.read<ObjectDetectorService>();
    _calibration = context.read<DistanceCalibrationService>();
    _detector.addListener(_onDetectorUpdate);
    _startDetector();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _detector.removeListener(_onDetectorUpdate);
    if (_startedHere) _detector.stop();
    _distanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _startDetector() async {
    if (_detector.isRunning) {
      setState(() => _starting = false);
      return;
    }
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _starting = false;
        _error = 'Camera permission is needed to calibrate.';
      });
      return;
    }
    final ok = await _detector.start(onFrame: (_) {});
    if (!mounted) {
      if (ok) _detector.stop();
      return;
    }
    setState(() {
      _startedHere = ok;
      _starting = false;
      _error = ok ? null : 'The rear camera could not start.';
    });
  }

  SensedObject? _largestMatch(List<SensedObject> objs) {
    SensedObject? best;
    for (final o in objs) {
      if (o.label != _label) continue;
      if (best == null || o.areaFraction > best.areaFraction) best = o;
    }
    return best;
  }

  void _onDetectorUpdate() {
    if (!mounted) return;
    final objs = _detector.latestObjects;
    if (_capturing && !identical(objs, _lastSeenList)) {
      _lastSeenList = objs;
      final match = _largestMatch(objs);
      if (match != null) {
        _samples.add(match.boxNorm);
        if (_samples.length >= _framesToAverage) _finishCapture();
      }
    }
    setState(() {}); // refresh the live reading
  }

  void _capture() {
    final d = double.tryParse(_distanceCtrl.text.replaceAll(',', '.'));
    if (d == null || d <= 0 || d > 50) {
      setState(() => _error = 'Enter a distance between 0 and 50 m.');
      return;
    }
    setState(() {
      _error = null;
      _result = null;
      _samples.clear();
      _capturing = true;
    });
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_captureLimit, () {
      if (!mounted || !_capturing) return;
      setState(() {
        _capturing = false;
        _error = _label == 'person'
            ? 'No person was found. Stand fully in view and try again.'
            : 'No car was found. Point the camera at the back of the car.';
      });
    });
  }

  Future<void> _finishCapture() async {
    _timeoutTimer?.cancel();
    _capturing = false;
    final n = _samples.length;
    var l = 0.0, t = 0.0, r = 0.0, b = 0.0;
    for (final s in _samples) {
      l += s.left;
      t += s.top;
      r += s.right;
      b += s.bottom;
    }
    final avg = Rect.fromLTRB(l / n, t / n, r / n, b / n);
    final distance = double.parse(_distanceCtrl.text.replaceAll(',', '.'));
    try {
      await _calibration.calibrate(
        label: _label,
        knownDistanceM: distance,
        boxNorm: avg,
        frameW: _detector.frameW,
        frameH: _detector.frameH,
      );
      if (mounted) setState(() => _result = 'Calibrated. Focal length saved.');
    } catch (e) {
      if (mounted) setState(() => _error = 'Calibration failed: $e');
    }
  }

  Future<void> _reset() async {
    await context.read<AwarenessPreferenceService>().setFocalLength(null, null);
    if (mounted) {
      setState(() {
        _result = 'Reset to the default focal length.';
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AwarenessPreferenceService>();
    final live = _largestMatch(_detector.latestObjects);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const Row(
              children: [
                Icon(Icons.straighten_rounded, color: _blue, size: 22),
                SizedBox(width: 10),
                Text('Calibrate distance',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Place a reference at a known distance behind the phone\'s rear '
              'camera, then tap Capture.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 14),

            // 1. Reference
            const Text('1. Reference',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _choice('person', 'Person standing',
                    Icons.directions_walk_rounded),
                _choice('car', 'Car seen from behind',
                    Icons.directions_car_rounded),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Distance
            const Text('2. Real distance (metres)',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 6),
            TextField(
              controller: _distanceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Live reading
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 16, color: _muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _starting
                          ? 'Starting the camera...'
                          : !_detector.isRunning
                              ? 'Camera is not running.'
                              : live == null
                                  ? 'No ${_label == 'person' ? 'person' : 'car'} in view yet.'
                                  : 'Now reads: ${live.distanceM?.toStringAsFixed(1) ?? '-'} m',
                      style: const TextStyle(fontSize: 12, color: _ink),
                    ),
                  ),
                  Text(
                    prefs.focalLengthPx == null ? 'Default' : 'Calibrated',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null) _strip(_error!, const Color(0xFFFF3B5C),
                Icons.error_outline_rounded),
            if (_result != null) _strip(_result!, const Color(0xFF00C06A),
                Icons.check_circle_outline_rounded),

            // 3. Capture
            ElevatedButton.icon(
              onPressed: (!_detector.isRunning || _capturing) ? null : _capture,
              icon: _capturing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.center_focus_strong_rounded, size: 18),
              label: Text(_capturing
                  ? 'Capturing ${_samples.length}/$_framesToAverage...'
                  : 'Capture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: prefs.focalLengthPx == null ? null : _reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset to default'),
              style: TextButton.styleFrom(foregroundColor: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(String value, String label, IconData icon) {
    final selected = _label == value;
    return ChoiceChip(
      selected: selected,
      onSelected: _capturing ? null : (_) => setState(() => _label = value),
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : _muted),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : _muted,
      ),
      selectedColor: _blue,
      backgroundColor: const Color(0xFFF4F6F9),
      showCheckmark: false,
      side: BorderSide.none,
    );
  }

  Widget _strip(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: _ink)),
          ),
        ],
      ),
    );
  }
}
