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
                    painter: _BoxesPainter(orch.objects),
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
  _BoxesPainter(this.objects);

  @override
  void paint(Canvas canvas, Size size) {
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
      canvas.drawRect(
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width / 80,
      );

      final d = o.distanceM;
      final label = d != null ? '${o.label} ${d.toStringAsFixed(1)} m' : o.label;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size.width / 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final labelTop = (r.top - tp.height - 2).clamp(0.0, size.height);
      canvas.drawRect(
        Rect.fromLTWH(r.left, labelTop, tp.width + 6, tp.height + 2),
        Paint()..color = color.withValues(alpha: 0.85),
      );
      tp.paint(canvas, Offset(r.left + 3, labelTop + 1));
    }
  }

  @override
  bool shouldRepaint(_BoxesPainter old) => !identical(old.objects, objects);
}
