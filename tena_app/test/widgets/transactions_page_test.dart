import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/pages/transactions_page.dart';
import 'package:flutter/material.dart';

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
    sqfliteFfiInit();
    CryptoService.useKeyStore(keyStore);
  });

  setUp(() async {
    final db = await database.database;
    await db.delete('transactions');
    await db.delete('user_profile');
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
}