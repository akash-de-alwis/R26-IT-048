import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Rasterises map marker images (PNG bytes) for Mapbox point annotations.
class MarkerIconGenerator {
  MarkerIconGenerator._();

  static const Color destinationColor = Color(0xFFFF3B5C);
  static const Color originColor = Color(0xFF2979FF);
  static const double defaultSize = 72;

  static final Map<String, Uint8List> _pinCache = {};

  static Future<Uint8List> destinationPin({double size = defaultSize}) =>
      buildTeardropPin(fillColor: destinationColor, size: size);

  static Future<Uint8List> originPin({double size = defaultSize}) =>
      buildTeardropPin(fillColor: originColor, size: size);

  // Pin proportions, all relative to the image width (= size).
  static const double _headRadiusRatio = 0.38;
  static const double _topMarginRatio = 0.08;
  static const double _tipDistanceRatio = 2.1; // centre→tip, in head radii
  static const double _shadowRyRatio = 0.05;

  static double _headCenterY(double size) =>
      size * _topMarginRatio + size * _headRadiusRatio;
  static double _tipY(double size) =>
      _headCenterY(size) + size * _headRadiusRatio * _tipDistanceRatio;

  /// Height of the pin image produced for [size].
  static double pinHeight(double size) =>
      (_tipY(size) + size * _shadowRyRatio).ceilToDouble();

  /// Distance from the image bottom up to the pin tip. Use as a positive
  /// y `iconOffset` (in image px) with `IconAnchor.BOTTOM` so the tip, not
  /// the shadow's edge, sits on the coordinate.
  static double tipInset(double size) => pinHeight(size) - _tipY(size);

  static Future<Uint8List> buildTeardropPin({
    required Color fillColor,
    double size = defaultSize,
  }) async {
    final key = '${fillColor.toARGB32()}_$size';
    final cached = _pinCache[key];
    if (cached != null) return cached;

    final w = size;
    final h = pinHeight(size);
    final r = size * _headRadiusRatio;
    final center = Offset(w / 2, _headCenterY(size));
    final tip = Offset(w / 2, _tipY(size));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Soft ground shadow under the tip
    canvas.drawOval(
      Rect.fromCenter(
          center: tip, width: r * 1.1, height: size * _shadowRyRatio * 2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.025),
    );

    // Teardrop: head circle joined to the tip by its two tangent lines
    final alpha = math.acos(r / (tip.dy - center.dy));
    final start = math.pi / 2 + alpha;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(center.dx + r * math.cos(start), center.dy + r * math.sin(start))
      ..arcTo(Rect.fromCircle(center: center, radius: r), start,
          2 * math.pi - 2 * alpha, false)
      ..close();

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(fillColor, Colors.black, 0.25)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.025
        ..strokeJoin = StrokeJoin.round,
    );

    // White centre dot so the pin reads at small sizes
    canvas.drawCircle(center, r * 0.45, Paint()..color = Colors.white);

    final bytes = await _toPng(recorder, w, h);
    _pinCache[key] = bytes;
    return bytes;
  }

  /// Small white pill with dark text, for a label shown above a pin.
  static Future<Uint8List> buildLabelPill(String text,
      {double fontSize = 13, double maxWidth = 180}) async {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF0D1B2A),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    const padH = 10.0, padV = 5.0, shadowPad = 4.0;
    final pillW = tp.width + padH * 2;
    final pillH = tp.height + padV * 2;
    final w = pillW + shadowPad * 2;
    final h = pillH + shadowPad * 2;
    final rect = Rect.fromLTWH(shadowPad, shadowPad, pillW, pillH);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(pillH / 2));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    tp.paint(canvas, Offset(shadowPad + padH, shadowPad + padV));

    return _toPng(recorder, w, h);
  }

  static Future<Uint8List> _toPng(
      ui.PictureRecorder recorder, double w, double h) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.ceil(), h.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }
}
