import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';

class _MemoryKeyStore implements SecretKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String keyBase64) async {
    value = keyBase64;
  }
  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tena_iso_');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'iso.db');
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(_MemoryKeyStore());
  });

  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    if (tempDir.existsSync()) {
      try { await tempDir.delete(recursive: true); } catch (_) {}
    }
  });

  test('transactions filtrees par userId (lecture, delete/restore/purge scopes)', () async {
    final svc = DatabaseService.instance;
    await svc.insertTransaction(Transaction(
      id: 'a', amount: 1, category: 'C', description: '', date: DateTime.utc(2025,1,1), type: TransactionType.expense),
      userId: 'alice');
    await svc.insertTransaction(Transaction(
      id: 'b', amount: 2, category: 'C', description: '', date: DateTime.utc(2025,1,1), type: TransactionType.expense),
      userId: 'bob');
    expect((await svc.getTransactions(userId: 'alice')).map((t)=>t.id), ['a']);
    expect((await svc.getTransactions(userId: 'bob')).map((t)=>t.id), ['b']);
    // suppression d'alice ne doit pas toucher bob
    await svc.deleteTransaction('b', userId: 'alice');
    expect((await svc.getTransactions(userId: 'bob')).length, 1);
    await svc.deleteTransaction('b', userId: 'bob');
    expect((await svc.getTransactions(userId: 'bob')), isEmpty);
    expect((await svc.getTransactions(userId: 'bob', includeDeleted: true)).length, 1);
    await svc.restoreTransaction('b', userId: 'bob');
    expect((await svc.getTransactions(userId: 'bob')).length, 1);
    await svc.purgeTransaction('a', userId: 'bob');
    expect((await svc.getTransactions(userId: 'alice')).length, 1);
  });

  test('budgets/goals isoles par userId (lecture)', () async {
    final svc = DatabaseService.instance;
    await svc.insertBudget(const BudgetEntry(id: 'global', amountCents: 100), userId: 'alice');
    await svc.insertBudget(const BudgetEntry(id: 'global_b', amountCents: 200), userId: 'bob');
    expect((await svc.getBudgets(userId: 'alice')).map((b)=>b.id), contains('global'));
    expect((await svc.getBudgets(userId: 'alice')).any((b)=>b.id=='global_b'), isFalse);
    expect((await svc.getBudgets(userId: 'bob')).map((b)=>b.id), contains('global_b'));
    await svc.insertGoal(const GoalEntry(
      id:'g1', name:'A', targetCents:1, savedCents:0, createdAt:'2026-01-01T00:00:00Z', updatedAt:'2026-01-01T00:00:00Z'), userId:'alice');
    expect((await svc.getGoals(userId: 'alice')).length, 1);
    expect((await svc.getGoals(userId: 'bob')), isEmpty);
  });

  test('deleteGoal/purgeGoal/deleteBudget scopes par userId', () async {
    final svc = DatabaseService.instance;
    await svc.insertGoal(const GoalEntry(
      id:'g', name:'X', targetCents:1, savedCents:0, createdAt:'2026-01-01T00:00:00Z', updatedAt:'2026-01-01T00:00:00Z'), userId:'bob');
    await svc.deleteGoal('g', userId:'alice');
    expect((await svc.getGoals(userId:'bob')).length, 1);
    await svc.deleteGoal('g', userId:'bob');
    expect((await svc.getGoals(userId:'bob')), isEmpty);
    await svc.insertBudget(const BudgetEntry(id:'cat', category:'cat', amountCents:5), userId:'bob');
    await svc.deleteBudget('cat', userId:'alice');
    expect((await svc.getBudgets(userId:'bob')).length, 1);
  });
}
