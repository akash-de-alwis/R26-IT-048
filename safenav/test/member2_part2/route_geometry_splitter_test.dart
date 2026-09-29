import 'package:flutter_test/flutter_test.dart';
import 'package:safenav/member2_route_engine/part2/services/route_geometry_splitter.dart';

void main() {
  // Straight east-west line, [lng, lat]
  final line = [
    [79.900, 6.900],
    [79.901, 6.900],
    [79.902, 6.900],
    [79.903, 6.900],
    [79.904, 6.900],
  ];

  test('position at the 3rd point splits the line there', () {
    final r = splitAtNearestPoint(line, 6.900, 79.902);
    // Shared split point appears on both sides
    expect(r.travelled, [line[0], line[1], line[2]]);
    expect(r.remaining, [line[2], line[3], line[4]]);
    expect(r.progressFraction, closeTo(0.5, 1e-6));
  });

  test('position between vertices is projected onto the line', () {
    final r = splitAtNearestPoint(line, 6.9001, 79.9025);
    expect(r.travelled.length, 4);
    expect(r.travelled.last[0], closeTo(79.9025, 1e-9));
    expect(r.travelled.last[1], closeTo(6.900, 1e-9));
    expect(r.remaining.first, r.travelled.last);
    expect(r.progressFraction, closeTo(0.625, 1e-6));
  });

  test('position at the start gives an empty travelled list', () {
    final r = splitAtNearestPoint(line, 6.900, 79.900);
    expect(r.travelled, isEmpty);
    expect(r.remaining, line);
    expect(r.progressFraction, 0);
  });

  test('position past the end clamps to the full route as travelled', () {
    final r = splitAtNearestPoint(line, 6.900, 79.910);
    expect(r.travelled, line);
    expect(r.remaining, isEmpty);
    expect(r.progressFraction, 1);
  });

  test('fewer than 2 points returns geometry as remaining', () {
    final r = splitAtNearestPoint([line[0]], 6.9, 79.9);
    expect(r.travelled, isEmpty);
    expect(r.remaining, [line[0]]);
    expect(r.progressFraction, 0);
  });
}
