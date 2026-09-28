import 'package:flutter_test/flutter_test.dart';
import 'package:safenav/features/member6_road_awareness/models/proximity_tier.dart';
import 'package:safenav/features/member6_road_awareness/services/proximity_classifier.dart';

void main() {
  ProximityTier at(double d, double kmh,
          {double rule = 3, bool inPath = true, double? ttc}) =>
      classifyProximity(
        distanceM: d,
        speedKmh: kmh,
        followingTimeS: rule,
        inPath: inPath,
        ttcSeconds: ttc,
      );

  group('driving: 40 km/h, 3 s rule (safe gap 33.3 m)', () {
    test('10 m is critical', () => expect(at(10, 40), ProximityTier.critical));
    test('22 m is very close',
        () => expect(at(22, 40), ProximityTier.veryClose));
    test('38 m is closer', () => expect(at(38, 40), ProximityTier.closer));
    test('55 m is far', () => expect(at(55, 40), ProximityTier.far));
    test('80 m is none', () => expect(at(80, 40), ProximityTier.none));
  });

  group('crawling: 5 km/h uses absolute distances', () {
    test('1 m is critical', () => expect(at(1, 5), ProximityTier.critical));
    test('2 m is very close', () => expect(at(2, 5), ProximityTier.veryClose));
    test('4 m is closer', () => expect(at(4, 5), ProximityTier.closer));
    test('7 m is far', () => expect(at(7, 5), ProximityTier.far));
    test('12 m is none', () => expect(at(12, 5), ProximityTier.none));
  });

  group('time to collision', () {
    test('ttc 1.5 s is always critical', () {
      expect(at(80, 40, ttc: 1.5), ProximityTier.critical);
      expect(at(12, 5, ttc: 1.5), ProximityTier.critical);
    });
    test('ttc 3 s raises none to very close',
        () => expect(at(80, 40, ttc: 3), ProximityTier.veryClose));
    test('ttc 3 s does not lower critical',
        () => expect(at(10, 40, ttc: 3), ProximityTier.critical));
  });

  group('beside the path', () {
    test('critical becomes very close',
        () => expect(at(10, 40, inPath: false), ProximityTier.veryClose));
    test('far becomes none',
        () => expect(at(55, 40, inPath: false), ProximityTier.none));
  });

  group('generic obstacle', () {
    test('large in path is critical',
        () => expect(classifyGenericObstacle(0.35, true), ProximityTier.critical));
    test('medium in path is very close',
        () => expect(classifyGenericObstacle(0.2, true), ProximityTier.veryClose));
    test('small in path is none',
        () => expect(classifyGenericObstacle(0.1, true), ProximityTier.none));
    test('beside the path is none',
        () => expect(classifyGenericObstacle(0.5, false), ProximityTier.none));
  });
}
