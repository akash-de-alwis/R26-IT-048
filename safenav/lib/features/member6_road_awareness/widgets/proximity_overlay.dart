import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/proximity_tier.dart';
import '../models/sensed_object_model.dart';
import '../services/awareness_orchestrator.dart';
import '../services/awareness_preference_service.dart';
import '../services/object_detector_service.dart';

/// Small rear-camera preview with each sensed object's box in its tier
/// colour. Not mirrored (rear camera). Shown only when the preview
/// preference is on and the camera is running.
class ProximityOverlay extends StatelessWidget {
  static const width = 110.0;
  static const height = 150.0;

  const ProximityOverlay({super.key});

  /// Whether the preview is on screen, so neighbouring widgets can make
  /// room for it. Rebuilds the caller only when this changes.
  static bool isShown(BuildContext context) {
    // Both selects run every build (provider requires unconditional calls)
    final previewOn = context.select<AwarenessPreferenceService, bool>(
        (p) => p.showCameraPreview);
    final running =
        context.select<ObjectDetectorService, bool>((d) => d.isRunning);
    return previewOn && running;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AwarenessPreferenceService>();
    final detector = context.watch<ObjectDetectorService>();
    final orch = context.watch<AwarenessOrchestrator>();
    final controller = detector.controller;

    if (!prefs.showCameraPreview ||
        !detector.isRunning ||
        controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: orch.cameraTier == ProximityTier.none
              ? Colors.white
              : orch.cameraTier.color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fill the box without distortion; boxes use the same mapping
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: detector.frameW.toDouble(),
              height: detector.frameH.toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  CustomPaint(
                    painter: _BoxesPainter(
                      orch.objects,
                      // FittedBox.cover scale: frame units -> screen px
                      displayScale: [
                        width / detector.frameW,
                        height / detector.frameH,
                      ].reduce((a, b) => a > b ? a : b),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxesPainter extends CustomPainter {
  final List<SensedObject> objects;

  /// Screen pixels per frame unit, so strokes and labels are sized for
  /// the small preview rather than the full camera frame.
  final double displayScale;

  _BoxesPainter(this.objects, {required this.displayScale});

  @override
  void paint(Canvas canvas, Size size) {
    final px = 1 / displayScale; // one screen pixel in frame units
    for (final o in objects) {
      final color = o.tier == ProximityTier.none
          ? Colors.white70
          : o.tier.color;
      final r = Rect.fromLTRB(
        o.boxNorm.left * size.width,
        o.boxNorm.top * size.height,
        o.boxNorm.right * size.width,
        o.boxNorm.bottom * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(3 * px)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * px,
      );

      // Rounded label chip above the box (inside it when at the top edge)
      final d = o.distanceM;
      final label = d != null ? '${o.label} ${d.toStringAsFixed(1)}m' : o.label;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 8.5 * px,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width);
      final padH = 4 * px;
      final padV = 1.5 * px;
      final chipW = tp.width + padH * 2;
      final chipH = tp.height + padV * 2;
      final gap = 2 * px;
      var chipTop = r.top - chipH - gap;
      if (chipTop < 0) chipTop = r.top + gap;
      final chipLeft = r.left.clamp(0.0, size.width - chipW);
      final chip = RRect.fromRectAndRadius(
        Rect.fromLTWH(chipLeft, chipTop, chipW, chipH),
        Radius.circular(chipH / 2),
      );
      canvas.drawRRect(chip, Paint()..color = Colors.black.withValues(alpha: 0.55));
      canvas.drawRRect(
        chip,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * px,
      );
      tp.paint(canvas, Offset(chipLeft + padH, chipTop + padV));
    }
  }

  @override
  bool shouldRepaint(_BoxesPainter old) =>
      !identical(old.objects, objects) || old.displayScale != displayScale;
}
