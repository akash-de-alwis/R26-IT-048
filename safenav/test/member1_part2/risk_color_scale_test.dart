import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:safenav/member1_risk_prediction/part2/widgets/risk_color_scale.dart';

int _argb(Color c) => c.toARGB32();
int _red(Color c) => (c.r * 255).round();

void main() {
  test('score 0 is the blue stop, score 100 the deep red stop', () {
    expect(_argb(paletteForScore(0).top), 0xFF2979FF);
    expect(_argb(paletteForScore(100).top), 0xFFC62828);
  });

  test('scores 30 and 75 are exactly the violet and red stops', () {
    expect(_argb(paletteForScore(30).top), 0xFF7E57C2);
    expect(_argb(paletteForScore(75).top), 0xFFE53935);
  });

  test('scores outside 0..100 are clamped', () {
    expect(_argb(paletteForScore(-20).top), 0xFF2979FF);
    expect(_argb(paletteForScore(250).top), 0xFFC62828);
  });

  test('accent equals top, bottom is lighter toward white', () {
    final p = paletteForScore(0);
    expect(_argb(p.accent), _argb(p.top));
    // Close to the original sheet bottom colour 0xFF5C9AFF
    expect((_red(p.bottom) - 0x5C).abs(), lessThanOrEqualTo(12));
    expect((((p.bottom.g * 255).round()) - 0x9A).abs(), lessThanOrEqualTo(8));
  });

  test('red channel never decreases from 0 to 75 (heats up steadily)', () {
    var previous = -1;
    for (var s = 0; s <= 75; s += 5) {
      final red = _red(paletteForScore(s.toDouble()).top);
      expect(red, greaterThanOrEqualTo(previous), reason: 'score $s');
      previous = red;
    }
  });
}
