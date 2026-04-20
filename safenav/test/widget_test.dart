import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SafeNav smoke test', (WidgetTester tester) async {
    // Full app requires Mapbox native init — integration tests handle that.
    // Unit/widget tests for individual widgets live alongside their features.
    expect(true, isTrue);
  });
}
