import 'package:flutter_test/flutter_test.dart';

import 'package:tena_budget/main.dart';

void main() {
  testWidgets('TENΛ Budget démarre correctement', (WidgetTester tester) async {
    await tester.pumpWidget(const TenaBudgetApp());

    expect(find.text('TENΛ'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
  });
}
