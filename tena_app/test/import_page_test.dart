import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/pages/import_transactions_page.dart';

void main() {
  testWidgets('ImportTransactionsPage displays file picker', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ImportTransactionsPage(),
    ));
    expect(find.text('Sélectionner un fichier CSV ou Excel'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('ImportTransactionsPage builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ImportTransactionsPage(),
    ));
    expect(find.byType(ImportTransactionsPage), findsOneWidget);
  });
}
