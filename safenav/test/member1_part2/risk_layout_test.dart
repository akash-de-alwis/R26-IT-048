import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safenav/member1_risk_prediction/part2/widgets/risk_trend_sparkline.dart';

void main() {
  // Regression: a stretch Row inside the sparkline threw "BoxConstraints
  // forces an infinite height" in the scrolling trip sheet, which froze it.
  testWidgets('sparkline lays out inside a scroll view', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Column(children: const [
              RiskTrendSparkline(points: [20, 30, 25, 40], accent: Colors.blue),
            ]),
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Risk over the last few minutes'), findsOneWidget);
  });
}
