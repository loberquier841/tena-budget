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
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tena_mig_int_');
    dbPath = p.join(tempDir.path, 'legacy.db');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = dbPath;
    final ks = _MemoryKeyStore();
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(ks);
  });

  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  Future<void> createLegacyV1SchemaAndData(String path) async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              description TEXT NOT NULL,
              date TEXT NOT NULL,
              type TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await db.insert('transactions', {
      'id': 'tx_legacy_1',
      'amount': 12.5,
      'category': 'Courses',
      'description': 'Pain',
      'date': '2025-01-02T10:00:00.000Z',
      'type': 'expense',
    });
    await db.insert('transactions', {
      'id': 'tx_legacy_2',
      'amount': 1000.0,
      'category': 'Salaire',
      'description': 'Janvier',
      'date': '2025-01-01T08:00:00.000Z',
      'type': 'income',
    });
    await db.close();
  }

  test('migration legacy v1 -> schéma courant : données préservées, chiffrées, contraintes/colonnes présentes',
      () async {
    await createLegacyV1SchemaAndData(dbPath);

    // Ouvre via DatabaseService => onUpgrade 1->7 (v2,v3,v4,v5,v6,v7).
    final svc = DatabaseService.instance;
    final txs = await svc.getTransactions();

    expect(txs.length, 2);
    final byId = {for (final t in txs) t.id: t};
    expect(byId['tx_legacy_1']!.amount, 12.5);
    expect(byId['tx_legacy_1']!.category, 'Courses');
    expect(byId['tx_legacy_1']!.type, TransactionType.expense);
    expect(byId['tx_legacy_1']!.isDeleted, false);
    expect(byId['tx_legacy_2']!.amount, 1000.0);
    expect(byId['tx_legacy_2']!.type, TransactionType.income);

    // Au repos : chiffré (v3).
    final db = await svc.database;
    final raw = await db.query('transactions', where: 'id = ?', whereArgs: ['tx_legacy_1']);
    expect(raw.single['amount'].toString(), startsWith('tena1:'));
    expect(raw.single['category'].toString(), startsWith('tena1:'));
    expect(raw.single['userId'], 'primary');
    expect(raw.single['is_deleted'], 0);

    // Schéma tables/index présents (pas d'exception sur opérations)
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('transactions','budgets','goals','user_profile')");
    expect(tables.map((e) => e['name']).toSet(),
        containsAll(['transactions', 'budgets', 'goals', 'user_profile']));

    // Budgets/goals utilisables après migration
    await svc.setGlobalBudget(500);
    expect(await svc.getGlobalBudget(), 500);
    await svc.insertGoal(const GoalEntry(
      id: 'g',
      name: 'Test',
      targetCents: 1000,
      savedCents: 0,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    ));
    expect((await svc.getGoals()).length, 1);

    // Intégrité: clé primaire respecte unicité (replace contrôlé via insertTransaction)
    await svc.insertTransaction(Transaction(
      id: 'tx_legacy_1',
      amount: 13.0,
      category: 'Courses',
      description: 'Pain',
      date: DateTime.parse('2025-01-02T10:00:00.000Z'),
      type: TransactionType.expense,
    ));
    final reread = await svc.getTransactions();
    expect(reread.where((t) => t.id == 'tx_legacy_1').single.amount, 13.0);
  });

  test('isolation userId : transactions/budgets/goals ne fuient pas entre profils', () async {
    final svc = DatabaseService.instance;
    await svc.insertTransaction(Transaction(
      id: 'a1',
      amount: 1,
      category: 'X',
      description: 'A',
      date: DateTime.utc(2025, 1, 1),
      type: TransactionType.expense,
    ), userId: 'alice');
    await svc.insertTransaction(Transaction(
      id: 'b1',
      amount: 2,
      category: 'Y',
      description: 'B',
      date: DateTime.utc(2025, 1, 1),
      type: TransactionType.expense,
    ), userId: 'bob');

    final alice = await svc.getTransactions(userId: 'alice');
    final bob = await svc.getTransactions(userId: 'bob');
    expect(alice.map((t) => t.id), ['a1']);
    expect(bob.map((t) => t.id), ['b1']);

    await svc.insertBudget(const BudgetEntry(id: 'global', amountCents: 100), userId: 'alice');
    // budget global lu par helper existant reste 'primary' (contrat actuel) ; vérif isolation via table
    final db = await svc.database;
    final bRows = await db.query('budgets', where: 'userId=?', whereArgs: ['alice']);
    expect(bRows.length, 1);
    final bobB = await db.query('budgets', where: 'userId=?', whereArgs: ['bob']);
    expect(bobB, isEmpty);

    await svc.insertGoal(const GoalEntry(
        id: 'ga',
        name: 'A',
        targetCents: 1,
        savedCents: 0,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z'), userId: 'alice');
    expect((await svc.getGoals(userId: 'alice')).length, 1);
    expect((await svc.getGoals(userId: 'bob')).length, 0);

    // delete/restore/purge scopés
    await svc.deleteTransaction('b1', userId: 'alice'); // ne doit pas toucher bob
    expect((await svc.getTransactions(userId: 'bob')).map((t) => t.id), ['b1']);
    await svc.deleteTransaction('b1', userId: 'bob');
    expect(await svc.getTransactions(userId: 'bob'), isEmpty);
    await svc.restoreTransaction('b1', userId: 'bob');
    expect((await svc.getTransactions(userId: 'bob')).length, 1);
  });
}
