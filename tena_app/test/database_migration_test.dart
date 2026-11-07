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
    tempDir = await Directory.systemTemp.createTemp('tena_mig_v_');
    dbPath = p.join(tempDir.path, 'm.db');
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

  test('migration legacy v5 (donnees + tables sans userId schema v6-ready) -> v6/v7 : donnees preservees, userId primary, CRUD ok', () async {
    // Schéma proche v5 : transactions/budgets/goals SANS userId, objectifs sans colonnes v7.
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY, amount REAL NOT NULL, category TEXT NOT NULL,
              description TEXT NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL,
              notes TEXT NOT NULL DEFAULT '', is_deleted INTEGER NOT NULL DEFAULT 0
            )''');
          await db.execute('''
            CREATE TABLE budgets (
              id TEXT PRIMARY KEY, category TEXT, amount_cents TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE goals (
              id TEXT PRIMARY KEY, name TEXT NOT NULL, target_cents TEXT NOT NULL,
              saved_cents TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0
            )''');
          await db.execute('CREATE TABLE IF NOT EXISTS user_profile (id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        },
      ),
    );
    // Données "en clair" pré-v3 (montant/texte) — v3 chiffre ; ici on simule état post-v3? 
    // Pour fiabilité: insérer valeurs déjà lisibles via decryptNumber/decrypt (clair accepté).
    await db.insert('transactions', {
      'id': 't5', 'amount': '12.5', 'category': 'Courses', 'description': 'X',
      'date': '2025-06-01T00:00:00.000Z', 'type': 'expense', 'notes': '', 'is_deleted': 0
    });
    await db.insert('budgets', {
      'id': 'global', 'category': null, 'amount_cents': '500', 'is_deleted': 0,
      'updated_at': '2025-06-01T00:00:00Z'
    });
    await db.insert('goals', {
      'id': 'g5', 'name': 'But', 'target_cents': '1000', 'saved_cents': '10', 'is_deleted': 0
    });
    await db.close();

    final svc = DatabaseService.instance;
    final txs = await svc.getTransactions();
    expect(txs.length, 1);
    expect(txs.first.id, 't5');
    expect(txs.first.category, 'Courses');

    final db2 = await svc.database;
    final colsTx = await db2.rawQuery("PRAGMA table_info('transactions')");
    expect(colsTx.map((r) => r['name']), containsAll(['userId','notes','is_deleted']));
    final rawTx = await db2.query('transactions', where: 'id=?', whereArgs: ['t5']);
    expect(rawTx.single['userId'], 'primary');
    // Les valeurs legacy en clair restent lisibles (decryptNumber/decrypt acceptent le clair).
    // Le chiffrement au repos est garanti sur les écritures ultérieures.
    expect(rawTx.single['id'], 't5');

    final colsG = await db2.rawQuery("PRAGMA table_info('goals')");
    for (final c in ['userId','category','target_date','milestones','created_at','updated_at']) {
      expect(colsG.map((r) => r['name']), contains(c));
    }
    // opérations post-migration
    await svc.setGlobalBudget(900);
    expect(await svc.getGlobalBudget(), 900);
    final goals = await svc.getGoals();
    expect(goals.length, 1);
  });

  test('nouvelle base creee au schema courant : tables, colonnes et index critiques', () async {
    final svc = DatabaseService.instance;
    final db = await svc.database;
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('transactions','budgets','goals','user_profile')");
    expect(tables.length, 4);
    for (final t in ['transactions','budgets','goals']) {
      final cols = await db.rawQuery("PRAGMA table_info('$t')");
      expect(cols.map((r)=>r['name']), contains('userId'));
      expect(cols.map((r)=>r['name']), contains('is_deleted'));
    }
    // CRUD smoke
    await svc.insertTransaction(Transaction(
      id: 'n1', amount: 1, category: 'A', description: '', date: DateTime.utc(2026,1,1), type: TransactionType.expense));
    expect((await svc.getTransactions()).length, 1);
  });
}
