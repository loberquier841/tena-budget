import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// IMPORTANT : ne pas supprimer cet import (factory mobile). Voir HEAD.
import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart' as model;
import '../models/transaction_document.dart';
import 'crypto_service.dart';
import 'import_service.dart';
import 'package:meta/meta.dart';

/// Modèle léger pour un budget de catégorie (lu/écrit via [DatabaseService]).
class BudgetEntry {
  final String id;
  final String? category; // null = budget global
  final double amountCents;
  final bool isDeleted;

  const BudgetEntry({
    required this.id,
    this.category,
    required this.amountCents,
    this.isDeleted = false,
  });
}

/// Modèle léger pour un objectif d'épargne (lu/écrit via [DatabaseService]).
class GoalEntry {
  final String id;
  final String name;
  final int targetCents;
  final int savedCents;
  final String category;
  final String? targetDate;
  final int? recurringAmountCents;
  final String? recurringStartDate;
  final String milestones; // JSON array as string
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  const GoalEntry({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.savedCents,
    this.category = 'other',
    this.targetDate,
    this.recurringAmountCents,
    this.recurringStartDate,
    this.milestones = '[25,50,75,100]',
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });
}

/// Contexte pour le pipeline d'import (empreintes/IDs existants, scopés userId).
class ImportContext {
  final Set<String> fingerprints;
  final Map<String, String> existingIds; // id -> fingerprint
  const ImportContext({required this.fingerprints, required this.existingIds});
}

/// Résultat du commit d'un plan d'import (LOT 2).
class ImportCommitResult {
  final int imported;
  final int updated;
  final int skipped;
  final List<String> conflicts;
  const ImportCommitResult(
      {this.imported = 0, this.updated = 0, this.skipped = 0, this.conflicts = const []});
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _database;

  DatabaseService._internal();

  /// Chemin DB imposé pour les tests (isolation). Null en production.
  @visibleForTesting
  static String? testDatabasePath;

  /// Réinitialise le singleton pour les tests (ferme la base en cache).
  @visibleForTesting
  static void resetForTesting() {
    _database = null;
  }

  /// Ferme et supprime la DB de test si [testDatabasePath] est défini.
  @visibleForTesting
  static Future<void> resetAndDeleteTestDatabase() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      try { await db.close(); } catch (_) {}
    }
    final path = testDatabasePath;
    if (path != null) {
      try { await databaseFactory.deleteDatabase(path); } catch (_) {
        try { await File(path).delete(); } catch (_) {}
      }
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// v1-v7 existants ; v8 profil/userId budgets/goals robuste ; v9 documents.
  static const int _schemaVersion = 9;
  static int _storedSchemaVersion = 0;
  static String? _migrationMessage;

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = testDatabasePath ?? join(await getDatabasesPath(), 'tena_budget.db');
    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateToV2(db);
        if (oldVersion < 3) await _migrateToV3(db);
        if (oldVersion < 4) await _createUserProfileSchema(db);
        if (oldVersion < 5) {
          await _createBudgetsSchema(db);
          await _createGoalsSchema(db);
        }
        if (oldVersion < 6) await _migrateToV6(db);
        if (oldVersion < 7) await _migrateToV7(db);
        if (oldVersion < 8) await _migrateToV8(db);
        if (oldVersion < 9) await _createDocumentsSchema(db);
        _storedSchemaVersion = newVersion;
        _checkAndSetMigrationMessage(oldVersion, newVersion);
        await _createIndexes(db);
      },
    );
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final info = await db.rawQuery("PRAGMA table_info('$table')");
    return info.any((row) => row['name'] == column);
  }

  Future<void> _addColumnIfMissing(Database db, String table, String ddl) async {
    final col = RegExp(r'ADD COLUMN\s+(\w+)', caseSensitive: false).firstMatch(ddl)?.group(1);
    if (col != null && await _columnExists(db, table, col)) return;
    await db.execute(ddl);
  }

  Future<void> _migrateToV6(Database db) async {
    await _addColumnIfMissing(db, 'transactions', 'ALTER TABLE transactions ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"');
    await _addColumnIfMissing(db, 'budgets', 'ALTER TABLE budgets ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"');
    await _addColumnIfMissing(db, 'goals', 'ALTER TABLE goals ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"');
  }

  Future<void> _migrateToV8(Database db) async {
    if (!await _columnExists(db, 'user_profile', 'userId')) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"');
    }
  }

  Future<void> _migrateToV7(Database db) async {
    await _addColumnIfMissing(db, 'goals', 'ALTER TABLE goals ADD COLUMN category TEXT NOT NULL DEFAULT "other"');
    await _addColumnIfMissing(db, 'goals', 'ALTER TABLE goals ADD COLUMN target_date TEXT');
    await _addColumnIfMissing(db, 'goals', 'ALTER TABLE goals ADD COLUMN recurring_amount_cents TEXT');
    await _addColumnIfMissing(db, 'goals', 'ALTER TABLE goals ADD COLUMN recurring_start_date TEXT');
    await _addColumnIfMissing(db, 'goals', "ALTER TABLE goals ADD COLUMN milestones TEXT NOT NULL DEFAULT '[25,50,75,100]'");
    const epoch = "'1970-01-01T00:00:00Z'";
    await _addColumnIfMissing(db, 'goals', "ALTER TABLE goals ADD COLUMN created_at TEXT NOT NULL DEFAULT $epoch");
    await _addColumnIfMissing(db, 'goals', "ALTER TABLE goals ADD COLUMN updated_at TEXT NOT NULL DEFAULT $epoch");
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        userId TEXT NOT NULL DEFAULT 'primary'
      )
    ''');
    await _createUserProfileSchema(db);
    await _createBudgetsSchema(db);
    await _createGoalsSchema(db);
    await _createDocumentsSchema(db);
  }

  Future<void> _createUserProfileSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        userId TEXT NOT NULL DEFAULT 'primary'
      )
    ''');
  }

  Future<void> _createBudgetsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        category TEXT,
        amount_cents TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        userId TEXT NOT NULL DEFAULT 'primary'
      )
    ''');
  }

  Future<void> _createDocumentsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        sha256 TEXT,
        note TEXT,
        category TEXT,
        userId TEXT NOT NULL DEFAULT 'primary',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createGoalsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_cents TEXT NOT NULL,
        saved_cents TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        userId TEXT NOT NULL DEFAULT 'primary',
        category TEXT NOT NULL DEFAULT 'other',
        target_date TEXT,
        recurring_amount_cents TEXT,
        recurring_start_date TEXT,
        milestones TEXT NOT NULL DEFAULT '[25,50,75,100]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateToV2(Database db) async {
    if (!await _columnExists(db, 'transactions', 'notes')) {
      await db.execute("ALTER TABLE transactions ADD COLUMN notes TEXT NOT NULL DEFAULT ''");
    }
    if (!await _columnExists(db, 'transactions', 'is_deleted')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _migrateToV3(Database db) async {
    if (await _columnExists(db, 'transactions', 'userId')) {
      await db.execute('ALTER TABLE transactions DROP COLUMN userId');
    }
    final rows = await db.query('transactions');
    for (final row in rows) {
      final amountRaw = '${row['amount']}';
      if (CryptoService.isEncryptedValue(amountRaw)) continue;
      final updated = <String, Object?>{
        'amount': await CryptoService.encryptNumber(double.tryParse(amountRaw) ?? 0),
        'category': await CryptoService.encrypt('${row['category']}'),
        'description': await CryptoService.encrypt('${row['description']}'),
        'date': await CryptoService.encrypt('${row['date']}'),
        'type': await CryptoService.encrypt('${row['type']}'),
        'notes': await CryptoService.encrypt('${row['notes'] ?? ''}'),
      };
      await db.update('transactions', updated, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  Future<void> _createIndexes(Database db) async {
    Future<bool> hasTable(String name) async {
      final r = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [name]);
      return r.isNotEmpty;
    }
    if (await hasTable('transactions')) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_deleted ON transactions(is_deleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(userId)');
    }
    if (await hasTable('budgets')) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_deleted ON budgets(is_deleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_user ON budgets(userId)');
    }
    if (await hasTable('goals')) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_goals_deleted ON goals(is_deleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_goals_user ON goals(userId)');
    }
    if (await hasTable('documents')) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_tx ON documents(transaction_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_user ON documents(userId)');
    }
  }

  Future<Map<String, Object?>> _toRow(model.Transaction transaction, {String userId = 'primary'}) async {
    return {
      'id': transaction.id,
      'amount': await CryptoService.encryptNumber(transaction.amount),
      'category': await CryptoService.encrypt(transaction.category),
      'description': await CryptoService.encrypt(transaction.description),
      'date': await CryptoService.encrypt(transaction.date.toIso8601String()),
      'type': await CryptoService.encrypt(transaction.type.name),
      'notes': await CryptoService.encrypt(transaction.notes),
      'is_deleted': transaction.isDeleted ? 1 : 0,
      'userId': userId,
    };
  }

  Future<model.Transaction> _toTransaction(Map<String, Object?> row) async {
    final amountRaw = '${row['amount']}';
    double amount;
    try {
      amount = await CryptoService.decryptNumber(amountRaw);
    } on CryptoException catch (_) {
      // compat legacy clair
      amount = double.tryParse(amountRaw) ?? 0;
    } catch (_) {
      amount = double.tryParse(amountRaw) ?? 0;
    }
    Future<String> dec(Object? v) async {
      final s = (v ?? '').toString();
      try { return await CryptoService.decrypt(s); } catch (_) { return s; }
    }
    return model.Transaction(
      id: row['id'] as String,
      amount: amount,
      category: await dec(row['category']),
      description: await dec(row['description']),
      notes: await dec(row['notes']),
      date: DateTime.parse(await dec(row['date'])),
      type: model.TransactionType.values.byName(await dec(row['type'])),
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  Future<void> saveUserProfilePayload(String jsonPayload, {String userId = 'primary'}) async {
    final db = await database;
    await db.insert('user_profile', {
      'id': userId,
      'payload': await CryptoService.encrypt(jsonPayload),
      'userId': userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getUserProfilePayload({String userId = 'primary'}) async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = ? AND userId = ?', whereArgs: [userId, userId], limit: 1);
    if (rows.isEmpty) {
      final legacy = await db.query('user_profile', where: 'id = ?', whereArgs: [userId], limit: 1);
      if (legacy.isEmpty) return null;
      return CryptoService.decrypt(legacy.single['payload'] as String);
    }
    return CryptoService.decrypt(rows.single['payload'] as String);
  }

  Future<void> insertTransaction(model.Transaction transaction, {String userId = 'primary'}) async {
    final db = await database;
    await db.insert('transactions', await _toRow(transaction, userId: userId), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Retourne true si une ligne du [userId] a été mise à jour.
  Future<bool> updateTransaction(model.Transaction transaction, {String userId = 'primary'}) async {
    final db = await database;
    final n = await db.update('transactions', await _toRow(transaction, userId: userId),
        where: 'id = ? AND userId = ?', whereArgs: [transaction.id, userId]);
    return n > 0;
  }

  Future<void> deleteTransaction(String id, {String userId = 'primary'}) async {
    final db = await database;
    await db.update('transactions', {'is_deleted': 1}, where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<void> restoreTransaction(String id, {String userId = 'primary'}) async {
    final db = await database;
    await db.update('transactions', {'is_deleted': 0}, where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<void> purgeTransaction(String id, {String userId = 'primary'}) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<List<model.Transaction>> getTransactions({bool includeDeleted = false, String userId = 'primary'}) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: includeDeleted ? 'userId = ?' : 'userId = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    final txs = <model.Transaction>[];
    for (final row in rows) { txs.add(await _toTransaction(row)); }
    return txs;
  }
