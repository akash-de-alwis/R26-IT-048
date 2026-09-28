import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_source_model.dart';
import '../models/drowsiness_metrics_model.dart';
import 'camera_source_service.dart';
import 'drowsiness_preference_service.dart';
import 'drowsiness_calibration_service.dart';
import 'drowsiness_alert_service.dart';
import 'mjpeg_frame_source.dart';

/// Converts a camera stream frame into an ML Kit [InputImage].
/// Shared by the detection service and the camera source tester.
InputImage? cameraImageToInputImage(
    CameraImage img, CameraDescription camera) {
  try {
    final builder = BytesBuilder();
    for (final plane in img.planes) {
      builder.add(plane.bytes);
    }
    final imageSize = Size(img.width.toDouble(), img.height.toDouble());
    final format =
        Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;
    // The app is portrait-locked, so the sensor orientation alone gives the
    // correct rotation: built-in cameras usually report 90/270, USB 0.
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: img.planes[0].bytesPerRow,
    );
    return InputImage.fromBytes(bytes: builder.toBytes(), metadata: metadata);
  } catch (_) {
    return null;
  }
}

CameraController buildDrowsinessCameraController(
        CameraDescription camera, ResolutionPreset preset) =>
    CameraController(
      camera,
      preset,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

/// Opens [camera] at low resolution; some external cameras reject 'low',
/// so retry once at medium.
Future<CameraController> openDrowsinessCamera(CameraDescription camera,
    {Duration? timeout}) async {
  var controller = buildDrowsinessCameraController(camera, ResolutionPreset.low);
  try {
    final init = controller.initialize();
    await (timeout == null ? init : init.timeout(timeout));
  } on CameraException {
    await controller.dispose();
    controller =
        buildDrowsinessCameraController(camera, ResolutionPreset.medium);
    final init = controller.initialize();
    await (timeout == null ? init : init.timeout(timeout));
  }
  return controller;
}

class DrowsinessDetectionService extends ChangeNotifier {
  static const _netFrameName = 'drowsiness_net_frame.jpg';
  static const _maxRecoveriesPerTrip = 2;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  DrowsinessMetrics? currentMetrics;
  bool isInitialized = false;
  bool isRunning = false;
  String? errorMessage;

  // ── Camera source ─────────────────────────────────────────────────────────
  CameraSource? activeSource;
  String? cameraFallbackNotice; // shown for a few seconds by chip / preview
  Uint8List? get latestNetworkFrame => _mjpeg?.latestFrame;
  MjpegFrameSource? _mjpeg;
  Timer? _networkTimer;
  Timer? _watchdogTimer;
  Timer? _noticeTimer;
  DateTime _lastFrameAt = DateTime.now();
  DateTime? _lastProcessedNetworkAt;
  String? _netFramePath;
  bool _processingNetworkFrame = false;
  bool _recovering = false;
  int _recoveries = 0;

  // Rolling window data (last 60 seconds)
  final List<MapEntry<DateTime, bool>> _eyeClosedHistory = [];
  final List<DateTime> _yawnTimestamps = [];
  final List<DateTime> _headNodTimestamps = [];

  final DrowsinessPreferenceService preferences;
  final DrowsinessCalibrationService calibration;
  final DrowsinessAlertService alertService;

  DateTime _lastFrameTime = DateTime.now();
  Timer? _metricsTimer;

  CameraController? get cameraController => _cameraController;

  bool get isCameraReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  DrowsinessDetectionService({
    required this.preferences,
    required this.calibration,
    required this.alertService,
  });

  /// Opens the camera chosen in preferences (default: front camera).
  /// [forceFront] ignores the saved choice for this trip only.
  Future<bool> initialize({bool forceFront = false}) async {
    try {
      await _releaseSource();
      if (!forceFront) _recoveries = 0;

      final sources = await CameraSourceService()
          .discover(networkUrl: preferences.networkCameraUrl);
      final wanted = forceFront ? null : preferences.selectedCameraId;

      CameraSource? chosen;
      if (wanted != null) {
        chosen = sources.where((s) => s.id == wanted).firstOrNull;
        if (chosen == null) {
          _setNotice('Selected camera is not available. Using the front camera.');
        }
      }

      if (chosen != null && chosen.isNetwork) {
        final mjpeg = MjpegFrameSource(chosen.url!);
        try {
          await mjpeg.start(onError: _handleCameraLost);
          _mjpeg = mjpeg;
          _netFramePath =
              '${(await getTemporaryDirectory()).path}/$_netFrameName';
        } catch (e) {
          debugPrint('[drowsiness] wireless camera failed: $e');
          await mjpeg.stop();
          chosen = null;
          _setNotice(
              'Wireless camera could not be reached. Using the front camera.');
        }
      }

      chosen ??= sources.where((s) => s.isFront).firstOrNull ??
          sources.where((s) => !s.isNetwork).firstOrNull;
      if (chosen == null) throw StateError('No camera available');

      if (!chosen.isNetwork) {
        _cameraController = await openDrowsinessCamera(chosen.description!);
        _cameraController!.addListener(_onControllerChanged);
      }

      _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableContours: true,
          enableLandmarks: true,
          enableTracking: true,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      activeSource = chosen;
      isInitialized = true;
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Camera init failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> startDetection() async {
    if (isRunning) return;
    if (!isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    isRunning = true;
    _lastFrameAt = DateTime.now();

    if (activeSource!.isNetwork) {
      _startNetworkLoop();
    } else {
      // Process at ~5 FPS by skipping frames under 200ms apart
      await _cameraController!.startImageStream(_onCameraImage);
    }

    // Rolling metrics calculator every 2 seconds
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _computeRollingMetrics(),
    );

    // Lost-camera watchdog (unplugged cable, WiFi drop)
    _watchdogTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (isRunning &&
          DateTime.now().difference(_lastFrameAt).inSeconds > 6) {
        _handleCameraLost();
      }
    });

    notifyListeners();
  }

  Future<void> _onCameraImage(CameraImage img) async {
    if (!isRunning) return;

    final now = DateTime.now();
    _lastFrameAt = now;
    if (now.difference(_lastFrameTime).inMilliseconds < 200) return;
    _lastFrameTime = now;

    try {
      final inputImage =
          cameraImageToInputImage(img, activeSource!.description!);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);
      await _handleFacesResult(faces);
    } catch (e) {
      debugPrint('[drowsiness] frame error: $e');
    }
  }

  void _startNetworkLoop() {
    _lastProcessedNetworkAt = null;
    _networkTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!isRunning || _processingNetworkFrame) return;
      final frame = _mjpeg?.latestFrame;
      final at = _mjpeg?.latestAt;
      final path = _netFramePath;
      if (frame == null || at == null || path == null) return;
      if (at == _lastProcessedNetworkAt) return;
      _lastProcessedNetworkAt = at;
      _lastFrameAt = DateTime.now();

      _processingNetworkFrame = true;
      try {
        // Single file, overwritten each frame, deleted when the trip ends
        await File(path).writeAsBytes(frame, flush: false);
        final faces =
            await _faceDetector!.processImage(InputImage.fromFilePath(path));
        await _handleFacesResult(faces);
      } catch (e) {
        debugPrint('[drowsiness] network frame error: $e');
      } finally {
        _processingNetworkFrame = false;
      }
      if (isRunning) notifyListeners(); // lets the preview repaint
    });
  }

  /// Shared by the camera stream and the network loop.
  Future<void> _handleFacesResult(List<Face> faces) async {
    if (faces.isEmpty) return;
    await _processFace(faces.first);
  }

  void _onControllerChanged() {
    if (isRunning && _cameraController?.value.hasError == true) {
      _handleCameraLost();
    }
  }

  /// Falls back to the built-in front camera for the rest of the trip.
  /// The user's saved choice is kept for the next trip.
  Future<void> _handleCameraLost() async {
    if (_recovering || !isRunning) return;
    _recovering = true;
    try {
      await stopDetection();
      if (_recoveries >= _maxRecoveriesPerTrip) {
        errorMessage = 'Camera keeps disconnecting. Drowsiness monitoring '
            'stopped for this trip.';
        return;
      }
      _recoveries++;
      final ok = await initialize(forceFront: true);
      if (!ok) {
        errorMessage = 'Camera disconnected and the front camera could not '
            'be opened. Drowsiness monitoring stopped.';
        return;
      }
      _setNotice('Camera disconnected. Switched to the front camera.');
      await startDetection();
    } catch (e) {
      errorMessage = 'Camera recovery failed: $e';
      debugPrint('[drowsiness] $errorMessage');
    } finally {
      _recovering = false;
      notifyListeners();
    }
  }

  void _setNotice(String msg) {
    cameraFallbackNotice = msg;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 8), () {
      cameraFallbackNotice = null;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _processFace(Face face) async {
    final leftProb = face.leftEyeOpenProbability ?? 1.0;
    final rightProb = face.rightEyeOpenProbability ?? 1.0;
    final avgEyeOpen = (leftProb + rightProb) / 2;

    // Feed into calibration if active — do not record metrics yet
    if (calibration.isCalibrating) {
      calibration.addSample(avgEyeOpen);
      return;
    }

    final baseline = preferences.baseline;
    if (baseline == null) return;

    final isEyeClosed =
        avgEyeOpen < (baseline.baselineEar * preferences.earClosedRatio);
    _eyeClosedHistory.add(MapEntry(DateTime.now(), isEyeClosed));

    // Yawn detection via lip contour gap
    final upperLip = face.contours[FaceContourType.upperLipBottom];
    final lowerLip = face.contours[FaceContourType.lowerLipTop];
    if (upperLip != null &&
        lowerLip != null &&
        upperLip.points.isNotEmpty &&
        lowerLip.points.isNotEmpty) {
      final upperY = upperLip.points
              .map((p) => p.y)
              .reduce((a, b) => a + b) /
          upperLip.points.length;
      final lowerY = lowerLip.points
              .map((p) => p.y)
              .reduce((a, b) => a + b) /
          lowerLip.points.length;
      // Threshold tuned for low-res 320x240 camera
      if ((lowerY - upperY).abs() > 25) {
        _yawnTimestamps.add(DateTime.now());
      }
    }

    // Head nod detection via Euler pitch
    final pitch = face.headEulerAngleX ?? 0;
    if (pitch < -15) {
      _headNodTimestamps.add(DateTime.now());
    }
  }

  void _computeRollingMetrics() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    _eyeClosedHistory.removeWhere((e) => e.key.isBefore(cutoff));
    _yawnTimestamps.removeWhere((t) => t.isBefore(cutoff));
    _headNodTimestamps.removeWhere((t) => t.isBefore(cutoff));

    if (_eyeClosedHistory.isEmpty) return;

    final closedCount = _eyeClosedHistory.where((e) => e.value).length;
    final perclos = (closedCount / _eyeClosedHistory.length) * 100;

    final perclosComp = (perclos / preferences.perclosThreshold) * 50;
    final yawnComp = (_yawnTimestamps.length / 3.0) * 25;
    final nodComp = (_headNodTimestamps.length / 4.0) * 25;
    final score = (perclosComp + yawnComp + nodComp).clamp(0.0, 100.0);

    DrowsinessLevel level;
    if (score >= 70) {
      level = DrowsinessLevel.critical;
    } else if (score >= 50) {
      level = DrowsinessLevel.warning;
    } else if (score >= 30) {
      level = DrowsinessLevel.caution;
    } else {
      level = DrowsinessLevel.alert;
    }

    final avgEar = _eyeClosedHistory
            .map((e) => e.value ? 0.2 : 0.7)
            .reduce((a, b) => a + b) /
        _eyeClosedHistory.length;

    currentMetrics = DrowsinessMetrics(
      currentEar: avgEar,
      perclosPct: perclos,
      yawnCount60s: _yawnTimestamps.length,
      headNods60s: _headNodTimestamps.length,
      drowsinessScore: score,
      level: level,
      timestamp: DateTime.now(),
    );

    notifyListeners();

    if (level == DrowsinessLevel.warning ||
        level == DrowsinessLevel.critical) {
      alertService.triggerAlert(currentMetrics!);
    }
  }

  Future<void> stopDetection() async {
    isRunning = false;
    _metricsTimer?.cancel();
    _metricsTimer = null;
    _networkTimer?.cancel();
    _networkTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    // Release the camera so the next trip opens the currently selected source
    await _releaseSource();
    notifyListeners();
  }

  /// Closes the camera controller / network stream and deletes the temp frame.
  Future<void> _releaseSource() async {
    isInitialized = false;
    activeSource = null;

    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      // Let the preview rebuild without the controller before disposing it
      notifyListeners();
      try {
        await SchedulerBinding.instance.endOfFrame
            .timeout(const Duration(milliseconds: 300));
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }

    final mjpeg = _mjpeg;
    _mjpeg = null;
    await mjpeg?.stop();

    final path = _netFramePath;
    _netFramePath = null;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    isRunning = false;
    _metricsTimer?.cancel();
    _networkTimer?.cancel();
    _watchdogTimer?.cancel();
    _noticeTimer?.cancel();
    _cameraController?.removeListener(_onControllerChanged);
    _cameraController?.dispose();
    _mjpeg?.stop();
    final path = _netFramePath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _faceDetector?.close();
    super.dispose();
  }
}
