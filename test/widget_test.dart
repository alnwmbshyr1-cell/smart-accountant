import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_accountant/main.dart';

void main() {
  testWidgets('المحاسب الصوتي smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: SmartAccountantApp(enableNativeServices: false),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify that the title or app bar text is present.
    expect(find.text('المحاسب الصوتي'), findsOneWidget);
  });
}
