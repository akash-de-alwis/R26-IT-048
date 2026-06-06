import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/baseline_calibration_model.dart';

class DrowsinessCalibrationService extends ChangeNotifier {
  final List<double> _samples = [];
  bool isCalibrating = false;
  int secondsRemaining = 15;
  Timer? _countdown;

  /// Feed each frame's averaged eye-open probability during the 15s window.
  void addSample(double avgEyeOpenProb) {
    if (!isCalibrating) return;
    if (avgEyeOpenProb > 0.5) {
      _samples.add(avgEyeOpenProb);
    }
  }

  Future<BaselineCalibration?> start({
    required void Function(int) onTick,
  }) async {
    isCalibrating = true;
    secondsRemaining = 15;
    _samples.clear();
    notifyListeners();

    final completer = Completer<BaselineCalibration?>();

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsRemaining--;
      onTick(secondsRemaining);

      if (secondsRemaining <= 0) {
        timer.cancel();
        isCalibrating = false;
        notifyListeners();

        if (_samples.length < 20) {
          completer.complete(null);
        } else {
          final sorted = List<double>.from(_samples)..sort();
          final median = sorted[sorted.length ~/ 2];
          completer.complete(BaselineCalibration(
            baselineEar: median,
            calibratedAt: DateTime.now(),
          ));
        }
      }
    });

    return completer.future;
  }

  void cancel() {
    _countdown?.cancel();
    _countdown = null;
    isCalibrating = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }
}
