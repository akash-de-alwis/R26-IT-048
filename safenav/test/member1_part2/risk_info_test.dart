import 'package:flutter_test/flutter_test.dart';
import 'package:safenav/member1_risk_prediction/part2/widgets/risk_factor_row.dart';
import 'package:safenav/member1_risk_prediction/part2/widgets/risk_gauge.dart';
import 'package:safenav/member1_risk_prediction/part2/widgets/risk_tips_card.dart';

void main() {
  group('multiplierColor', () {
    test('0.85 lowers risk: green', () {
      expect(multiplierColor(0.85), kFactorGreen);
    });
    test('1.0 is neutral', () {
      expect(multiplierColor(1.0), kFactorNeutral);
    });
    test('1.2 is amber', () {
      expect(multiplierColor(1.2), kFactorAmber);
    });
    test('1.4 is orange', () {
      expect(multiplierColor(1.4), kFactorOrange);
    });
  });

  group('riskTrend', () {
    final t0 = DateTime(2026, 9, 28, 10);
    List<(DateTime, double)> h(List<double> scores, {int stepSeconds = 15}) => [
          for (var i = 0; i < scores.length; i++)
            (t0.add(Duration(seconds: i * stepSeconds)), scores[i]),
        ];

    test('rising when the latest is more than 3 above the average', () {
      expect(riskTrend(h([30, 32, 31, 40])), RiskTrend.rising);
    });
    test('steady within 3 points', () {
      expect(riskTrend(h([30, 32, 31, 33])), RiskTrend.steady);
    });
    test('falling when more than 3 below', () {
      expect(riskTrend(h([50, 48, 49, 40])), RiskTrend.falling);
    });
    test('null with fewer than 3 points', () {
      expect(riskTrend(h([])), isNull);
      expect(riskTrend(h([30, 60])), isNull);
    });
    test('only the previous 60 seconds count', () {
      // 10 and 12 are over a minute old; the recent average is 40
      final history = [
        (t0, 10.0),
        (t0.add(const Duration(seconds: 10)), 12.0),
        (t0.add(const Duration(seconds: 100)), 40.0),
        (t0.add(const Duration(seconds: 115)), 41.0),
      ];
      expect(riskTrend(history), RiskTrend.steady);
    });
  });

  group('drivingBarFraction', () {
    test('1.00 gives 0 and 1.35 gives 1', () {
      expect(drivingBarFraction(1.0), 0.0);
      expect(drivingBarFraction(1.35), closeTo(1.0, 1e-9));
    });
    test('clamped outside the range', () {
      expect(drivingBarFraction(0.9), 0.0);
      expect(drivingBarFraction(2.0), 1.0);
    });
    test('scales linearly in between', () {
      expect(drivingBarFraction(1.175), closeTo(0.5, 1e-9));
    });
  });

  group('buildTips', () {
    final allGood = kRiskTipText['all_good']!;

    test('a wet road returns the wet-road tip', () {
      final tips = buildTips(roadCondition: 'wet', roadMultiplier: 1.2);
      expect(tips, contains(kRiskTipText['wet_road']));
    });

    test('never more than 3 tips, strongest factor first', () {
      final tips = buildTips(
        hotspotMultiplier: 1.3,
        weatherCondition: 'thunderstorm',
        weatherMultiplier: 1.85,
        roadCondition: 'slippery',
        roadMultiplier: 1.5,
        speedMultiplier: 2.2,
        vehicleType: 'Motorcycle',
        vehicleMultiplier: 1.4,
        harshBrakesPerMin: 4,
        volatilityMultiplier: 1.16,
      );
      expect(tips.length, 3);
      expect(tips.first, kRiskTipText['speed']);
    });

    test('"Conditions look good" only when no other rule matched', () {
      expect(buildTips(), [allGood]);
      expect(buildTips(roadCondition: 'wet'), isNot(contains(allGood)));
      expect(buildTips(vehicleType: 'Three Wheeler'), isNot(contains(allGood)));
      // Hard brakes only count while the stream is connected (non-null)
      expect(buildTips(harshBrakesPerMin: null), [allGood]);
      expect(buildTips(harshBrakesPerMin: 3),
          [kRiskTipText['hard_brakes']]);
    });
  });
}
