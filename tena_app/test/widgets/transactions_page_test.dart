import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/pages/transactions_page.dart';
import 'package:flutter/material.dart';

Transaction _transaction({
  required String id,
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
  String category = 'Test',
  String description = 'Description',
  String notes = '',
  bool isDeleted = false,
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    description: description,
    date: date,
    type: type,
    notes: notes,
    isDeleted: isDeleted,
  );
}

// Helper key store for testing
class _TestKeyStore implements SecretKeyStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String keyBase64) async => _value = keyBase64;
  @override
  Future<void> delete() async => _value = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final database = DatabaseService.instance;
  final keyStore = _TestKeyStore();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    CryptoService.useKeyStore(keyStore);
  });

  setUp(() async {
    final db = await database.database;
    await db.delete('transactions');
    await db.delete('user_profile');
    // Clear category preferences if needed (though transactions page doesn't use them)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('TransactionsPage can be instantiated', (WidgetTester tester) async {
    expect(TransactionsPage(), isNotNull);
  });

  testWidgets('TransactionsPage builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pump();
    // Expect that the widget is present
    expect(find.byType(TransactionsPage), findsOneWidget);
  });

  testWidgets('Shows loading indicator while loading', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Displays transactions in the list', (WidgetTester tester) async {
    await database.insertTransaction(_transaction(
      id: 't1',
      amount: 10.0,
      date: DateTime(2026, 10, 1),
      type: TransactionType.expense,
      category: 'Food',
    ));
    await database.insertTransaction(_transaction(
      id: 't2',
      amount: 20.0,
      date: DateTime(2026, 10, 2),
      type: TransactionType.income,
      category: 'Salary',
    ));

    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pumpAndSettle();

    // Expect to see two transaction tiles (or at least two items in the list)
    // We'll look for the category text or amount text.
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.textContaining('10,00 €'), findsOneWidget);
    expect(find.textContaining('20,00 €'), findsOneWidget);
  });

  testWidgets('Filters by expense type via appBar menu', (WidgetTester tester) async {
    await database.insertTransaction(_transaction(
      id: 'exp1',
      amount: 10.0,
      date: DateTime(2026, 10, 1),
      type: TransactionType.expense,
      category: 'Food',
    ));
    await database.insertTransaction(_transaction(
      id: 'inc1',
      amount: 20.0,
      date: DateTime(2026, 10, 2),
      type: TransactionType.income,
      category: 'Salary',
    ));

    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pumpAndSettle();

    // Initially, both transactions should be visible (no filter)
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    // Open the filter menu (PopupMenuButton) in the appBar
    // Find the icon button with tooltip 'Filtrer'
    await tester.tap(find.widgetWithIcon(Icons.filter_list, 'Filtrer'));
    await tester.pumpAndSettle();

    // Select the 'Dépenses' item from the popup menu
    expect(find.text('Dépenses'), findsOneWidget);
    await tester.tap(find.text('Dépenses'));
    await tester.pumpAndSettle();

    // Now only the expense transaction should be visible
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('Shows all types when filter is set to Toutes', (WidgetTester tester) async {
    await database.insertTransaction(_transaction(
      id: 'exp1',
      amount: 10.0,
      date: DateTime(2026, 10, 1),
      type: TransactionType.expense,
      category: 'Food',
    ));
    await database.insertTransaction(_transaction(
      id: 'inc1',
      amount: 20.0,
      date: DateTime(2026, 10, 2),
      type: TransactionType.income,
      category: 'Salary',
    ));

    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pumpAndSettle();

    // Open filter menu and select 'Toutes' (which is null)
    await tester.tap(find.widgetWithIcon(Icons.filter_list, 'Filtrer'));
    await tester.pumpAndSettle();
    expect(find.text('Toutes'), findsOneWidget);
    await tester.tap(find.text('Toutes'));
    await tester.pumpAndSettle();

    // Both should be visible
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('Toggles display of deleted transactions via FilterChip', (WidgetTester tester) async {
    await database.insertTransaction(_transaction(
      id: 'normal',
      amount: 10.0,
      date: DateTime(2026, 10, 1),
      type: TransactionType.expense,
      category: 'Food',
      isDeleted: false,
    ));
    await database.insertTransaction(_transaction(
      id: 'deleted',
      amount: 20.0,
      date: DateTime(2026, 10, 2),
      type: TransactionType.expense,
      category: 'Food',
      isDeleted: true,
    ));

    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pumpAndSettle();

    // Initially, _showDeleted is false, so only normal transaction should be visible
    expect(find.textContaining('10,00 €'), findsOneWidget);
    expect(find.textContaining('20,00 €'), findsNothing);

    // Tap the FilterChip labeled 'Supprimées'
    await tester.tap(find.widgetWithText(FilterChip, 'Supprimées'));
    await tester.pumpAndSettle();

    // Now both should be visible
    expect(find.textContaining('10,00 €'), findsOneWidget);
    expect(find.textContaining('20,00 €'), findsOneWidget);

    // Tap again to hide deleted
    await tester.tap(find.widgetWithText(FilterChip, 'Supprimées'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10,00 €'), findsOneWidget);
    expect(find.textContaining('20,00 €'), findsNothing);
  });

  testWidgets('Shows empty message when no transactions', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pumpAndSettle();

    // We expect to see a text indicating no transactions? Let's check the UI.
    // In the TransactionsPage, when the list is empty, it shows a Centered Text: 'Aucune transaction'.
    // Look for that text.
    expect(find.textContaining('Aucune transaction'), findsOneWidget);
  });

  testWidgets('Does not load transactions outside date range when filtering by type? Actually no date filter in TransactionsPage', (WidgetTester tester) async {
    // TransactionsPage does not filter by date, so we skip.
    // Instead, test that the list updates when we add a transaction after initial load.
    await tester.pumpWidget(MaterialApp(
      home: TransactionsPage(),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune transaction'), findsOneWidget);

    await database.insertTransaction(_transaction(
      id: 't1',
      amount: 10.0,
      date: DateTime(2026, 10, 1),
      type: TransactionType.expense,
      category: 'Food',
    ));
    // We need to trigger a reload. Since the widget doesn't automatically reload,
    // we need to simulate a user action that causes a refresh, like pulling to refresh?
    // There's no refresh indicator. However, the _loadTransactions is called only in initState and
    // when showDeleted changes or when the filter type changes (via setState that calls _loadTransactions).
    // So we can change the filter type to trigger a reload.
    // Open the filter menu and select an item (even the same) to trigger setState.
    await tester.tap(find.widgetWithIcon(Icons.filter_list, 'Filtrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toutes'));
    await tester.pumpAndSettle();

    // Now the transaction should appear.
    expect(find.text('Food'), findsOneWidget);
    expect(find.textContaining('10,00 €'), findsOneWidget);
    expect(find.textContaining('Aucune transaction'), findsNothing);
  });
}
