import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/object_profiles.dart';
import '../models/sensed_object_model.dart';
import 'distance_calibration_service.dart';

/// On-device object detection from the rear camera with the COCO SSD
/// MobileNet v1 (quantised) model, plus a simple tracker that smooths
/// distance and estimates time to collision.
class ObjectDetectorService extends ChangeNotifier {
  static const _modelAsset = 'assets/models/coco_ssd_mobilenet_v1_quant.tflite';
  static const _labelsAsset = 'assets/models/coco_labelmap.txt';

  static const _inputSize = 300;
  static const _minScore = 0.5;
  static const _minFrameInterval = Duration(milliseconds: 200); // <= 5 FPS

  // Class-index offset. The model outputs 0-based class ids where 0 is
  // 'person', but coco_labelmap.txt starts with a '???' background line, so
  // 'person' is line 1: label = labels[classId + 1]. (Same offset as the
  // official TFLite SSD MobileNet example.) New tracks are logged below as
  // "class N -> label" so this can be confirmed on a device.
  static const _labelOffset = 1;

  // Path and generic obstacle rules
  static const _pathMinX = 0.2;
  static const _pathMaxX = 0.8;
  static const _genericMinArea = 0.15;

  // Tracker
  static const _matchMaxCentreDist = 0.15;
  static const _distanceAlpha = 0.4;
  static const _ttcWindow = Duration(milliseconds: 1000);
  static const _ttcMinSpan = Duration(milliseconds: 500);
  static const _minClosingSpeed = 0.3; // m/s
  static const _trackTimeout = Duration(milliseconds: 1500);

  final DistanceCalibrationService distance;
  ObjectDetectorService({required this.distance});

  CameraController? controller; // exposed for the preview widget
  bool isRunning = false;
  String? errorMessage;
  List<SensedObject> latestObjects = [];
  int frameW = 240, frameH = 320; // analysed portrait frame size

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String>? _labels;
  int _sensorOrientation = 90;
  void Function(List<SensedObject>)? _onFrame;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  final List<_Track> _tracks = [];
  int _nextTrackId = 1;

  /// Loads the model and starts the rear camera. Returns false (with
  /// [errorMessage] set) on failure; never throws.
  Future<bool> start(
      {required void Function(List<SensedObject>) onFrame}) async {
    if (isRunning) return true;
    errorMessage = null;

    try {
      _labels ??= (await rootBundle.loadString(_labelsAsset))
          .split('\n')
          .map((l) => l.trim())
          .toList();
      _interpreter ??= await Interpreter.fromAsset(_modelAsset);
      // Inference runs in a background isolate so the UI does not stutter
      _isolateInterpreter ??=
          await IsolateInterpreter.create(address: _interpreter!.address);
    } catch (e) {
      errorMessage = 'Could not load the object detection model: $e';
      debugPrint('[ObjectDetector] $errorMessage');
      notifyListeners();
      return false;
    }

    try {
      final cams = await availableCameras();
      final back = cams
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .firstOrNull;
      if (back == null) throw StateError('No rear camera found');
      _sensorOrientation = back.sensorOrientation;

      final c = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      controller = c;
      await c.initialize();

      _onFrame = onFrame;
      _tracks.clear();
      isRunning = true;
      await c.startImageStream(_onImage);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not start the rear camera: $e';
      debugPrint('[ObjectDetector] $errorMessage');
      isRunning = false;
      await _releaseCamera();
      notifyListeners();
      return false;
    }
  }

  Future<void> stop() async {
    isRunning = false;
    _onFrame = null;
    _tracks.clear();
    latestObjects = [];
    try {
      await controller?.stopImageStream();
    } catch (_) {}
    await _releaseCamera();
    notifyListeners();
  }

  Future<void> _releaseCamera() async {
    final c = controller;
    controller = null;
    if (c == null) return;
    notifyListeners(); // let the preview drop the controller first
    try {
      await c.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    isRunning = false;
    _onFrame = null;
    final c = controller;
    controller = null;
    c?.stopImageStream().catchError((_) {}).whenComplete(c.dispose);
    _isolateInterpreter?.close();
    _interpreter?.close();
    super.dispose();
  }

  // ── Frame pipeline ────────────────────────────────────────────────────────

  Future<void> _onImage(CameraImage image) async {
    if (!isRunning || _busy) return; // skip while the previous frame runs
    final now = DateTime.now();
    if (now.difference(_lastRun) < _minFrameInterval) return;
    _lastRun = now;
    _busy = true;

    try {
      final frame = _FrameInput.fromCameraImage(image, _sensorOrientation);
      final prepared = await _prepareInIsolate(frame);
      if (!isRunning) return;
      frameW = prepared.uprightW;
      frameH = prepared.uprightH;

      final detections = await _infer(prepared.rgb);
      if (!isRunning) return;

      final objects = _track(detections, DateTime.now());
      latestObjects = objects;
      _onFrame?.call(objects);
      notifyListeners();
    } catch (e) {
      debugPrint('[ObjectDetector] frame error: $e');
    } finally {
      _busy = false;
    }
  }

  Future<List<_Detection>> _infer(Uint8List rgb) async {
    final interp = _interpreter!;
    final boxesShape = interp.getOutputTensor(0).shape; // [1, N, 4]
    final n = boxesShape.length > 1 ? boxesShape[1] : 10;

    final boxes = [List.generate(n, (_) => List<double>.filled(4, 0))];
    final classes = [List<double>.filled(n, 0)];
    final scores = [List<double>.filled(n, 0)];
    final count = List<double>.filled(1, 0);

    // uint8 [1, 300, 300, 3]; a flat Uint8List is passed through as-is
    await _isolateInterpreter!.runForMultipleInputs(
      [rgb],
      {0: boxes, 1: classes, 2: scores, 3: count},
    );

    final labels = _labels!;
    final total = math.min(n, count[0].round());
    final out = <_Detection>[];
    for (var i = 0; i < total; i++) {
      final score = scores[0][i];
      if (score < _minScore) continue;
      final classId = classes[0][i].round();
      final labelIdx = classId + _labelOffset;
      if (labelIdx < 0 || labelIdx >= labels.length) continue;
      final label = labels[labelIdx];
      if (label.isEmpty || label == '???') continue;

      final b = boxes[0][i]; // [ymin, xmin, ymax, xmax], 0..1
      final box = Rect.fromLTRB(
        b[1].clamp(0.0, 1.0),
        b[0].clamp(0.0, 1.0),
        b[3].clamp(0.0, 1.0),
        b[2].clamp(0.0, 1.0),
      );
      if (box.width <= 0 || box.height <= 0) continue;
      final det = _Detection(classId, label, score, box);
      if (_keep(det)) out.add(det);
    }
    return out;
  }

  /// Vehicles only count in the path; vulnerable road users in or beside
  /// it; anything else only as a large obstacle in the path.
  bool _keep(_Detection d) {
    if (vehicleLabels.contains(d.label)) return d.inPath;
    if (objectProfiles[d.label]?.vulnerable ?? false) return true;
    return d.inPath && d.areaFraction >= _genericMinArea;
  }

  // ── Tracker ───────────────────────────────────────────────────────────────

  List<SensedObject> _track(List<_Detection> detections, DateTime now) {
    final matched = <_Track>{};
    detections.sort((a, b) => b.score.compareTo(a.score));

    for (final d in detections) {
      _Track? best;
      var bestDist = _matchMaxCentreDist;
      for (final t in _tracks) {
        if (matched.contains(t) || t.label != d.label) continue;
        final dist = (t.centre - d.box.center).distance;
        if (dist < bestDist) {
          bestDist = dist;
          best = t;
        }
      }

      final raw = distance.estimate(d.label, d.box, frameW, frameH);
      if (best == null) {
        best = _Track(_nextTrackId++, d.label);
        _tracks.add(best);
        debugPrint('[ObjectDetector] new track #${best.id}: class '
            '${d.classId} -> ${d.label} (${d.score.toStringAsFixed(2)})');
      }
      best.update(d, raw, now);
      matched.add(best);
    }

    _tracks.removeWhere((t) => now.difference(t.lastSeen) > _trackTimeout);

    return [
      for (final t in matched)
        SensedObject(
          trackId: t.id,
          label: t.label,
          group: objectProfiles[t.label]?.group ?? genericObstacleGroup,
          score: t.score,
          boxNorm: t.box,
          distanceM: t.smoothedDistance,
          ttcSeconds: t.ttcSeconds(now),
          inPath: _isInPath(t.box),
          vulnerable: objectProfiles[t.label]?.vulnerable ?? false,
        ),
    ];
  }

  static bool _isInPath(Rect box) =>
      box.center.dx >= _pathMinX && box.center.dx <= _pathMaxX;
}

class _Detection {
  final int classId;
  final String label;
  final double score;
  final Rect box;
  _Detection(this.classId, this.label, this.score, this.box);

  bool get inPath => ObjectDetectorService._isInPath(box);
  double get areaFraction => box.width * box.height;
}

class _Track {
  final int id;
  final String label;
  Rect box = Rect.zero;
  double score = 0;
  double? smoothedDistance;
  DateTime lastSeen = DateTime.now();
  final List<(DateTime, double)> _history = [];

  _Track(this.id, this.label);

  Offset get centre => box.center;

  void update(_Detection d, double? rawDistance, DateTime now) {
    box = d.box;
    score = d.score;
    lastSeen = now;
    if (rawDistance != null) {
      final prev = smoothedDistance;
      smoothedDistance = prev == null
          ? rawDistance
          : ObjectDetectorService._distanceAlpha * rawDistance +
              (1 - ObjectDetectorService._distanceAlpha) * prev;
      _history.add((now, smoothedDistance!));
      final cutoff = now.subtract(ObjectDetectorService._ttcWindow);
      _history.removeWhere((e) => e.$1.isBefore(cutoff));
    }
  }

  /// Time to collision from the smoothed distance change over the last
  /// second, when the object is closing faster than the minimum speed.
  double? ttcSeconds(DateTime now) {
    final current = smoothedDistance;
    if (current == null || _history.length < 2) return null;
    final (t0, d0) = _history.first;
    final span = now.difference(t0);
    if (span < ObjectDetectorService._ttcMinSpan) return null;
    final closingSpeed = (d0 - current) / (span.inMilliseconds / 1000);
    if (closingSpeed <= ObjectDetectorService._minClosingSpeed) return null;
    return current / closingSpeed;
  }
}

// ── Frame preparation (runs in a background isolate) ────────────────────────

class _FrameInput {
  final int width, height, rotation;
  final Uint8List y, u, v;
  final int yRowStride, uvRowStride, uvPixelStride;
  final int vOffset; // 1 when U and V share an interleaved plane (iOS NV12)

  _FrameInput({
    required this.width,
    required this.height,
    required this.rotation,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.vOffset,
  });

  factory _FrameInput.fromCameraImage(CameraImage image, int rotation) {
    final p = image.planes;
    final twoPlane = p.length == 2;
    return _FrameInput(
      width: image.width,
      height: image.height,
      rotation: rotation,
      y: p[0].bytes,
      u: p[1].bytes,
      v: twoPlane ? p[1].bytes : p[2].bytes,
      yRowStride: p[0].bytesPerRow,
      uvRowStride: p[1].bytesPerRow,
      uvPixelStride: p[1].bytesPerPixel ?? (twoPlane ? 2 : 1),
      vOffset: twoPlane ? 1 : 0,
    );
  }
}

class _PreparedFrame {
  final Uint8List rgb; // 300 x 300 x 3
  final int uprightW, uprightH;
  _PreparedFrame(this.rgb, this.uprightW, this.uprightH);
}

// Top-level so the isolate closure captures only the frame data
Future<_PreparedFrame> _prepareInIsolate(_FrameInput f) =>
    Isolate.run(() => _prepareFrame(f));

/// YUV420 -> RGB, rotate upright by the sensor orientation, resize to the
/// model input size.
_PreparedFrame _prepareFrame(_FrameInput f) {
  final rgbImage = img.Image(width: f.width, height: f.height);
  for (var y = 0; y < f.height; y++) {
    final yRow = y * f.yRowStride;
    final uvRow = (y >> 1) * f.uvRowStride;
    for (var x = 0; x < f.width; x++) {
      final yIdx = yRow + x;
      final uvIdx = uvRow + (x >> 1) * f.uvPixelStride;
      if (yIdx >= f.y.length || uvIdx >= f.u.length) continue;
      final vIdx = uvIdx + f.vOffset;
      final yp = f.y[yIdx];
      final up = f.u[uvIdx] - 128;
      final vp = (vIdx < f.v.length ? f.v[vIdx] : 128) - 128;
      final r = (yp + 1.402 * vp).round().clamp(0, 255);
      final g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
      final b = (yp + 1.772 * up).round().clamp(0, 255);
      rgbImage.setPixelRgb(x, y, r, g, b);
    }
  }
  // copyRotate turns clockwise, matching Android's sensorOrientation
  final upright = f.rotation % 360 == 0
      ? rgbImage
      : img.copyRotate(rgbImage, angle: f.rotation);
  final resized = img.copyResize(upright,
      width: ObjectDetectorService._inputSize,
      height: ObjectDetectorService._inputSize);
  return _PreparedFrame(
    resized.getBytes(order: img.ChannelOrder.rgb),
    upright.width,
    upright.height,
  );
}
