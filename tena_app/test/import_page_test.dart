import 'package:flutter_test/flutter_test.dart';
import 'package:tena_app/pages/import_page.dart';

void main() {
  testWidgets('ImportPage displays file picker', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ImportPage(),
    ));
    expect(find.text('Sélectionner un fichier CSV ou Excel'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('ImportPage builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ImportPage(),
    ));
    expect(find.byType(ImportPage), findsOneWidget);
  });
}
