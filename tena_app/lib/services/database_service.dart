import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// IMPORTANT : ne pas supprimer cet import.
// Sur Android/iOS, `package:sqflite` installe la factory par défaut basée sur
// le plugin natif. Sans lui, `databaseFactory` resterait la factory FFI et le
// build mobile échouerait à l'exécution. L'analyseur le signale comme
// redondant car sqflite_common_ffi ré-exporte les mêmes symboles.
// ignore: unnecessary_import
import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart' as model;
import 'crypto_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// Version du schéma SQLite.
  ///
  /// v1 : id, amount, category, description, date, type
  /// v2 : notes, is_deleted (suppression logique) et index sur la date
  /// v3 : chiffrement AES-GCM des transactions existantes.
  /// v4 : profil/questionnaire local chiffré; migration additive.
  static const int _schemaVersion = 4;

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tena_budget.db');

    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Chaque migration porte sur une seule version : elles s'enchaînent
        // dans l'ordre et permettent d'évoluer à long terme.
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }

        if (oldVersion < 3) {
          await _migrateToV3(db);
        }

        if (oldVersion < 4) {
          await _createUserProfileSchema(db);
        }

        await _createIndexes(db);
      },
    );
  }

  /// Schéma appliqué lors de la création d'une base.
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
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createIndexes(db);
    await _createUserProfileSchema(db);
  }

  Future<void> _createUserProfileSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL
      )
    ''');
  }

  /// Migration v1 -> v2 : note libre, suppression logique, index sur la date.
  ///
  /// Les données existantes sont conservées telles quelles : les nouvelles
  /// colonnes prennent une valeur par défaut neutre.
  Future<void> _migrateToV2(Database db) async {
    await db.execute(
      "ALTER TABLE transactions ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'ALTER TABLE transactions ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// Migration v2 -> v3 : chiffre les données déjà présentes.
  ///
  /// Les lignes existantes sont relues puis réécrites chiffrées. Le préfixe
  /// `tena1:` permet de distinguer une valeur chiffrée d'une valeur en clair :
  /// une transaction qui l'est déjà n'est donc jamais chiffrée deux fois.
  Future<void> _migrateToV3(Database db) async {
    final rows = await db.query('transactions');

    for (final row in rows) {
      final transaction = await _toTransaction(row);

      await db.update(
        'transactions',
        await _toRow(transaction),
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_deleted '
      'ON transactions(is_deleted)',
    );
  }

  /// Convertit un modèle en ligne SQLite, en chiffrant les champs sensibles.
  Future<Map<String, Object?>> _toRow(model.Transaction transaction) async {
    return {
      'id': transaction.id,
      'amount': await CryptoService.encryptNumber(transaction.amount),
      'category': transaction.category,
      'description': await CryptoService.encrypt(transaction.description),
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.name,
      'notes': await CryptoService.encrypt(transaction.notes),
      'is_deleted': transaction.isDeleted ? 1 : 0,
    };
  }

  /// Convertit une ligne SQLite en modèle, en déchiffrant les champs sensibles.
  Future<model.Transaction> _toTransaction(Map<String, Object?> row) async {
    return model.Transaction(
      id: row['id'] as String,
      amount: await CryptoService.decryptNumber('${row['amount']}'),
      category: row['category'] as String,
      description: await CryptoService.decrypt(
        (row['description'] as String?) ?? '',
      ),
      date: DateTime.parse(row['date'] as String),
      type: row['type'] == 'income'
          ? model.TransactionType.income
          : model.TransactionType.expense,
      notes: await CryptoService.decrypt((row['notes'] as String?) ?? ''),
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  Future<void> insertTransaction(model.Transaction transaction) async {
    final db = await database;

    await db.insert(
      'transactions',
      await _toRow(transaction),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Enregistre le JSON versionné du profil sous forme chiffrée AES-GCM.
  Future<void> saveUserProfilePayload(String jsonPayload) async {
    final db = await database;
    await db.insert('user_profile', {
      'id': 'primary',
      'payload': await CryptoService.encrypt(jsonPayload),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getUserProfilePayload() async {
    final db = await database;
    final rows = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: ['primary'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CryptoService.decrypt(rows.single['payload'] as String);
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    final db = await database;

    await db.update(
      'transactions',
      await _toRow(transaction),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Suppression logique : aucune donnée financière n'est réellement effacée,
  /// la transaction peut être restaurée via [restoreTransaction].
  Future<void> deleteTransaction(String id) async {
    final db = await database;

    await db.update(
      'transactions',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restaure une transaction supprimée logiquement.
  Future<void> restoreTransaction(String id) async {
    final db = await database;

    await db.update(
      'transactions',
      {'is_deleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Suppression définitive, réservée à l'effacement explicite demandé par
  /// l'utilisateur (RGPD). Elle n'est jamais appelée par l'écran Transactions.
  Future<void> purgeTransaction(String id) async {
    final db = await database;

    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Les transactions supprimées sont exclues par défaut afin qu'elles ne
  /// remontent ni dans les totaux, ni dans le graphique.
  Future<List<model.Transaction>> getTransactions({
    bool includeDeleted = false,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? categories,
    List<model.TransactionType>? types,
  }) async {
    final db = await database;
    final whereBuffer = StringBuffer();
    final whereArgs = <Object?>[];

    if (!includeDeleted) {
      whereBuffer.write('is_deleted = 0');
    }

    void _addWhere() {
      if (whereBuffer.isNotEmpty) {
        whereBuffer.write(' AND ');
      }
    }

    if (startDate != null) {
      _addWhere();
      whereBuffer.write('date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      _addWhere();
      whereBuffer.write('date < ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (categories != null && categories.isNotEmpty) {
      _addWhere();
      whereBuffer.write('category IN (' +
          List.filled(categories.length, '?').join(', ') + ')');
      whereArgs.addAll(categories);
    }
    if (types != null && types.isNotEmpty) {
      _addWhere();
      whereBuffer.write('type IN (' +
          List.filled(types.length, '?').join(', ') + ')');
      whereArgs.addAll(types.map((e) => e.name));
    }

    final whereClause = whereBuffer.toString();
    final rows = await db.query(
      'transactions',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    final transactions = <model.Transaction>[];
    for (final row in rows) {
      transactions.add(await _toTransaction(row));
    }
    return transactions;
  }
}
