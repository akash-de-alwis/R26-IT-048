import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ObstacleMarkerPainter {
  static double get _dpr =>
      ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 3.0;

  /// Small diamond-shaped marker with severity color.
  static Future<Uint8List> createMarker(Color color) async {
    final scale = _dpr;
    const logicalD = 44.0;
    final physSize = (logicalD * scale).toInt();
    const cx = logicalD / 2;
    const cy = logicalD / 2;
    const r = 12.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);

    // Halo
    canvas.drawCircle(
      const Offset(cx, cy),
      r + 5,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );

    // Drop shadow
    canvas.drawCircle(
      const Offset(cx, cy + 1.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Core circle
    canvas.drawCircle(const Offset(cx, cy), r, Paint()..color = color);

    // White border
    canvas.drawCircle(
      const Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Inner white exclamation stem
    canvas.drawLine(
      const Offset(cx, cy - 4.5),
      const Offset(cx, cy + 1.5),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Dot
    canvas.drawCircle(
      const Offset(cx, cy + 5),
      1.5,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(physSize, physSize);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
