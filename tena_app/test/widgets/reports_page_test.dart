import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/pages/reports_page.dart';

void main() {
  testWidgets('ReportsPage renders without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      home: ReportsPage(),
    ));
    // Expect to find some placeholder text or progress indicator.
    // Since we mock no services, it will show loading or error.
    // We just verify that the widget builds.
    expect(find.byType(ReportsPage), findsOneWidget);
  });
}