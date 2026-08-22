import 'package:flutter_test/flutter_test.dart';
import 'package:smart_accountant/main.dart';

void main() {
  testWidgets('Smart Accountant smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartAccountantApp());

    // Verify that the title or app bar text is present.
    expect(find.text('عاقل المحاسبة الخارق v2.4.0'), findsOneWidget);
  });
}
