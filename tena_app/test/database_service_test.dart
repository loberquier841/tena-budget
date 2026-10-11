import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/models/transaction.dart' as model;
import 'dart:convert';

void main() {
  late DatabaseService db;

  setUp(() {
    db = DatabaseService.instance;
    // Set a deterministic encryption key for tests
    final testKey = base64Encode(List<int>.generate(32, (i) => i));
    CryptoService.debugSetKey(testKey);
  });

  tearDown(() async {
    // Clean up encryption key
    CryptoService.debugSetKey(null);
    final database = await db.database;
    await database.delete(
      'transactions',
    );
  });

  Future<String> _insertTx({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required model.TransactionType type,
    bool isDeleted = false,
  }) async {
    final tx = model.Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      category: category,
      description: description,
      date: date,
      type: type,
      notes: '',
      isDeleted: isDeleted,
    );
    await db.insertTransaction(tx);
    return tx.id;
  }

  test('CryptoService encrypt/decrypt works with test key', () async {
    const plain = 'Hello world';
    final encrypted = await CryptoService.encrypt(plain);
    final decrypted = await CryptoService.decrypt(encrypted);
    expect(decrypted, plain);
  });

  test('getTransactions without filters returns all non-deleted', () async {
    await _insertTx(amount: 10, category: 'A', description: 'TEST_1', date: DateTime(2026,1,1), type: model.TransactionType.income);
    await _insertTx(amount: 20, category: 'B', description: 'TEST_2', date: DateTime(2026,1,2), type: model.TransactionType.expense);
    await _insertTx(amount: 30, category: 'C', description: 'TEST_3', date: DateTime(2026,1,3), type: model.TransactionType.income, isDeleted: true);
    final list = await db.getTransactions();
    expect(list.length, 2);
    expect(list.map((e) => e.amount).toList()..sort(), equals([10,20]));
  });

  test('startDate inclusive, endDate exclusive', () async {
    await _insertTx(amount: 1, category: 'X', description: 'TEST_s1', date: DateTime(2026,1,1), type: model.TransactionType.income);
    await _insertTx(amount: 2, category: 'X', description: 'TEST_s2', date: DateTime(2026,1,2), type: model.TransactionType.income);
    await _insertTx(amount: 3, category: 'X', description: 'TEST_s3', date: DateTime(2026,1,3), type: model.TransactionType.income);
    final list = await db.getTransactions(startDate: DateTime(2026,1,2), endDate: DateTime(2026,1,3));
    expect(list.length, 1);
    expect(list.first.amount, equals(2));
  });

  test('filter by category', () async {
    await _insertTx(amount: 5, category: 'Food', description: 'TEST_f1', date: DateTime(2026,1,1), type: model.TransactionType.expense);
    await _insertTx(amount: 7, category: 'Transport', description: 'TEST_f2', date: DateTime(2026,1,2), type: model.TransactionType.expense);
    await _insertTx(amount: 9, category: 'Food', description: 'TEST_f3', date: DateTime(2026,1,3), type: model.TransactionType.expense);
    final list = await db.getTransactions(categories: ['Food']);
    expect(list.length, 2);
    expect(list.every((e) => e.category == 'Food'), isTrue);
    expect(list.map((e) => e.amount).toList()..sort(), equals([5,9]));
  });

  test('filter by type', () async {
    await _insertTx(amount: 10, category: 'X', description: 'TEST_i1', date: DateTime(2026,1,1), type: model.TransactionType.income);
    await _insertTx(amount: 20, category: 'X', description: 'TEST_e1', date: DateTime(2026,1,2), type: model.TransactionType.expense);
    await _insertTx(amount: 30, category: 'X', description: 'TEST_i2', date: DateTime(2026,1,3), type: model.TransactionType.income);
    final list = await db.getTransactions(types: [model.TransactionType.income]);
    expect(list.length, 2);
    expect(list.every((e) => e.type == model.TransactionType.income), isTrue);
    expect(list.map((e) => e.amount).toList()..sort(), equals([10,30]));
  });

  test('includeDeleted flag works', () async {
    await _insertTx(amount: 11, category: 'C', description: 'TEST_n', date: DateTime(2026,1,1), type: model.TransactionType.income);
    await _insertTx(amount: 22, category: 'C', description: 'TEST_d', date: DateTime(2026,1,2), type: model.TransactionType.income, isDeleted: true);
    final normal = await db.getTransactions();
    final withDel = await db.getTransactions(includeDeleted: true);
    expect(normal.length, 1);
    expect(normal.first.amount, equals(11));
    expect(withDel.length, 2);
    final amounts = withDel.map((e) => e.amount).toList()..sort();
    expect(amounts, equals([11,22]));
  });

  test('null or empty lists no filter', () async {
    await _insertTx(amount: 5, category: 'CatX', description: 'TEST_n1', date: DateTime(2026,1,1), type: model.TransactionType.income);
    await _insertTx(amount: 10, category: 'CatY', description: 'TEST_n2', date: DateTime(2026,1,2), type: model.TransactionType.expense);
    final t1 = await db.getTransactions(categories: null, types: null);
    final t2 = await db.getTransactions(categories: [], types: []);
    final t3 = await db.getTransactions();
    expect(t1.length, 2);
    expect(t2.length, 2);
    expect(t3.length, 2);
  });

  test('combined filters (date, category, type)', () async {
    // Insert four transactions
    await _insertTx(amount: 1.0, category: 'A', description: 'TEST_c1', date: DateTime(2026,1,1), type: model.TransactionType.income);
    await _insertTx(amount: 2.0, category: 'A', description: 'TEST_c2', date: DateTime(2026,1,2), type: model.TransactionType.expense);
    await _insertTx(amount: 3.0, category: 'B', description: 'TEST_c3', date: DateTime(2026,1,3), type: model.TransactionType.income);
    await _insertTx(amount: 4.0, category: 'A', description: 'TEST_c4', date: DateTime(2026,1,4), type: model.TransactionType.expense);

    // date range 2026-01-02 to 2026-01-04 (exclusive end), category A, type income => should match none
    final list1 = await db.getTransactions(
      startDate: DateTime(2026,1,2),
      endDate: DateTime(2026,1,4),
      categories: ['A'],
      types: [model.TransactionType.income],
    );
    expect(list1.length, equals(0));

    // date range 2026-01-01 to 2026-01-03 (exclusive), category A, type income => should match only 2026-01-01 A income
    final list2 = await db.getTransactions(
      startDate: DateTime(2026,1,1),
      endDate: DateTime(2026,1,3),
      categories: ['A'],
      types: [model.TransactionType.income],
    );
    expect(list2.length, equals(1));
    expect(list2.first.amount, equals(1.0));
    expect(list2.first.date.day, equals(1));
  });

  test('calls without arguments match original behavior', () async {
    await _insertTx(amount: 100.0, category: 'C1', description: 'TEST_Orig', date: DateTime(2026,5,1), type: model.TransactionType.expense);
    await _insertTx(amount: 200.0, category: 'C2', description: 'TEST_Orig2', date: DateTime(2026,5,2), type: model.TransactionType.income, isDeleted: true);
    final originalResult = await db.getTransactions();
    final newResult = await db.getTransactions(
      startDate: null,
      endDate: null,
      categories: null,
      types: null,
    );
    expect(originalResult.length, equals(newResult.length));
    for (int i = 0; i < originalResult.length; i++) {
      expect(originalResult[i].id, equals(newResult[i].id));
      expect(originalResult[i].amount, equals(newResult[i].amount));
      expect(originalResult[i].category, equals(newResult[i].category));
      expect(originalResult[i].description, equals(newResult[i].description));
      expect(originalResult[i].date, equals(newResult[i].date));
      expect(originalResult[i].type, equals(newResult[i].type));
      expect(originalResult[i].isDeleted, equals(newResult[i].isDeleted));
    }
  });
}
