import 'package:flutter_test/flutter_test.dart';

import 'package:rainy_day_example/main.dart';

void main() {
  testWidgets('RainApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RainApp());
    // App should render without errors.
    expect(tester.takeException(), isNull);
  });
}
