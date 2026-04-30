import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class HotspotMarkerPainter {
  // Mapbox treats PointAnnotation image bytes as physical pixels.
  // We scale the canvas by devicePixelRatio so the marker renders at the
  // correct logical size on every screen density.
  static double get _dpr =>
      ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 3.0;

  /// Radar-pulse dot: solid core + semi-transparent halo rings.
  /// HIGH → 2 rings, MEDIUM → 1 ring, LOW → core only.
  static Future<Uint8List> createHotspotMarker(String riskLevel) async {
    final level = riskLevel.toUpperCase();
    final scale = _dpr;

    final color = level == 'HIGH'
        ? const Color(0xFFFF3B5C)
        : level == 'MEDIUM'
            ? const Color(0xFFFFB300)
            : const Color(0xFF00C06A);

    // Canvas logical dimensions — largest ring needs room for HIGH
    const logicalD = 60.0; // same canvas size for all, rings differ
    final physSize = (logicalD * scale).toInt();
    const cx = logicalD / 2;
    const cy = logicalD / 2;

    // Ring radii (logical px)
    const coreR = 9.0;
    const ring1R = 18.0;
    const ring2R = 27.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);

    // ── Outer ring (HIGH only) ──────────────────────────────────────────────
    if (level == 'HIGH') {
      canvas.drawCircle(
        const Offset(cx, cy),
        ring2R,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        const Offset(cx, cy),
        ring2R,
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // ── Middle ring (HIGH + MEDIUM) ─────────────────────────────────────────
    if (level != 'LOW') {
      canvas.drawCircle(
        const Offset(cx, cy),
        ring1R,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        const Offset(cx, cy),
        ring1R,
        Paint()
          ..color = color.withValues(alpha: 0.50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ── Core dot shadow ─────────────────────────────────────────────────────
    canvas.drawCircle(
      const Offset(cx, cy + 1.5),
      coreR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Core dot ────────────────────────────────────────────────────────────
    canvas.drawCircle(const Offset(cx, cy), coreR, Paint()..color = color);

    // ── White ring around core ───────────────────────────────────────────────
    canvas.drawCircle(
      const Offset(cx, cy),
      coreR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── Bright inner highlight ───────────────────────────────────────────────
    canvas.drawCircle(
      const Offset(cx - 2.5, cy - 2.5),
      3.0,
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(physSize, physSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Blue destination pin: pulsing blue dot with crosshair.
  static Future<Uint8List> createDestinationMarker() async {
    final scale = _dpr;
    const color = Color(0xFF2979FF);
    const logicalD = 64.0;

    final physSize = (logicalD * scale).toInt();
    const cx = logicalD / 2;
    const cy = logicalD / 2;
    const coreR = 12.0;
    const ring1R = 22.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale, scale);

    // Outer halo
    canvas.drawCircle(
      const Offset(cx, cy),
      ring1R,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      const Offset(cx, cy),
      ring1R,
      Paint()
        ..color = color.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Shadow
    canvas.drawCircle(
      const Offset(cx, cy + 1.5),
      coreR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Core
    canvas.drawCircle(const Offset(cx, cy), coreR, Paint()..color = color);

    // White ring
    canvas.drawCircle(
      const Offset(cx, cy),
      coreR,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Crosshair
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(cx - 7, cy), const Offset(cx + 7, cy), linePaint);
    canvas.drawLine(
        const Offset(cx, cy - 7), const Offset(cx, cy + 7), linePaint);

    // Center dot
    canvas.drawCircle(
        const Offset(cx, cy), 2.0, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final img = await picture.toImage(physSize, physSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
