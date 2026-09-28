import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safenav/features/member6_road_awareness/services/beep_engine.dart';

void main() {
  test('buildToneWav(1000, 100) is a valid 100 ms mono 16-bit WAV', () {
    final wav = buildToneWav(1000, 100);

    // 22050 Hz * 0.1 s = 2205 samples, 2 bytes each, plus the 44-byte header
    expect(wav.length, 44 + 2 * 2205);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');

    final samples = ByteData.sublistView(wav, 44);
    var nonZero = false;
    for (var i = 0; i < samples.lengthInBytes; i += 2) {
      if (samples.getInt16(i, Endian.little) != 0) {
        nonZero = true;
        break;
      }
    }
    expect(nonZero, isTrue);
  });
}
