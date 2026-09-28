import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_source_model.dart';
import 'drowsiness_detection_service.dart';
import 'mjpeg_frame_source.dart';

class CameraTestResult {
  final bool opened;
  final bool faceDetected;
  final String message;

  /// Set when the saved address failed but another path on the same camera
  /// worked; the picker offers to save it.
  final String? suggestedUrl;

  CameraTestResult(this.opened, this.faceDetected, this.message,
      {this.suggestedUrl});
}

/// Short "Test camera" check so the driver can verify a source before a trip.
class CameraSourceTester {
  static const _openTimeout = Duration(seconds: 6);
  static const _detectWindow = Duration(seconds: 4);

  final DrowsinessDetectionService detection;
  CameraSourceTester(this.detection);

  static CameraTestResult get _couldNotOpen =>
      CameraTestResult(false, false, 'Could not open this camera.');
  static CameraTestResult get _faceFound => CameraTestResult(
      true, true, 'Camera works and a face was detected.');
  static CameraTestResult get _noFace => CameraTestResult(true, false,
      'Camera opens, but no face was found. Check the angle and lighting.');

  Future<CameraTestResult> test(CameraSource source) async {
    if (detection.isRunning) {
      return CameraTestResult(false, false,
          'Test the camera before starting a trip. End the current trip first.');
    }

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    CameraController? controller;

    try {
      if (source.isNetwork) {
        return await _testNetworkWithFallbacks(source.url!, detector);
      }

      try {
        controller = await openDrowsinessCamera(source.description!,
            timeout: _openTimeout);
      } catch (e) {
        debugPrint('[camera test] open failed: $e');
        return _couldNotOpen;
      }
      return await _testCamera(controller, source.description!, detector);
    } finally {
      try {
        await controller?.stopImageStream();
      } catch (_) {}
      try {
        await controller?.dispose();
      } catch (_) {}
      await detector.close();
    }
  }

  Future<CameraTestResult> _testCamera(CameraController controller,
      CameraDescription camera, FaceDetector detector) async {
    final found = Completer<bool>();
    var busy = false;
    await controller.startImageStream((img) async {
      if (busy || found.isCompleted) return;
      busy = true;
      try {
        final input = cameraImageToInputImage(img, camera);
        if (input == null) return;
        final faces = await detector.processImage(input);
        if (faces.isNotEmpty && !found.isCompleted) found.complete(true);
      } catch (_) {
        // detector may be closing; ignore
      } finally {
        busy = false;
      }
    });
    final ok = await found.future.timeout(_detectWindow, onTimeout: () => false);
    return ok ? _faceFound : _noFace;
  }

  /// Tests [url]; if it fails in a way a different path could fix and it
  /// does not already end with /video, tries /video then /videofeed once each.
  Future<CameraTestResult> _testNetworkWithFallbacks(
      String url, FaceDetector detector) async {
    final first = await _testNetworkUrl(url, detector);
    if (first.opened || first.error?.pathMayBeWrong != true) {
      return first.result;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path.endsWith('/video')) return first.result;

    for (final path in const ['/video', '/videofeed']) {
      final candidate = uri.replace(path: path).toString();
      if (candidate == url) continue;
      final attempt = await _testNetworkUrl(candidate, detector);
      if (attempt.opened) {
        return CameraTestResult(
          true,
          attempt.result.faceDetected,
          '${attempt.result.message} The stream was found at $candidate.',
          suggestedUrl: candidate,
        );
      }
    }
    return first.result;
  }

  Future<({bool opened, CameraOpenException? error, CameraTestResult result})>
      _testNetworkUrl(String url, FaceDetector detector) async {
    final mjpeg = MjpegFrameSource(url);
    final tmp = File('${(await getTemporaryDirectory()).path}'
        '/drowsiness_test_frame.jpg');
    try {
      // start() has its own connect/response timeouts; an outer timeout
      // here would leave the connection opening in the background
      await mjpeg.start(onError: () {});
      await mjpeg.waitForFirstFrame(within: _detectWindow);
      final result = await _detectOnNetwork(mjpeg, tmp, detector);
      return (opened: true, error: null, result: result);
    } catch (e) {
      final err = CameraOpenException.from(e);
      debugPrint('[camera test] $url failed: $err');
      return (
        opened: false,
        error: err,
        result: CameraTestResult(false, false, err.message),
      );
    } finally {
      await mjpeg.stop();
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  Future<CameraTestResult> _detectOnNetwork(
      MjpegFrameSource mjpeg, File tmp, FaceDetector detector) async {
    final deadline = DateTime.now().add(_detectWindow);
    DateTime? lastAt;
    while (DateTime.now().isBefore(deadline)) {
      final frame = mjpeg.latestFrame;
      final at = mjpeg.latestAt;
      if (frame != null && at != lastAt) {
        lastAt = at;
        try {
          await tmp.writeAsBytes(frame, flush: false);
          final faces =
              await detector.processImage(InputImage.fromFilePath(tmp.path));
          if (faces.isNotEmpty) return _faceFound;
        } catch (e) {
          debugPrint('[camera test] frame error: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return _noFace;
  }
}
