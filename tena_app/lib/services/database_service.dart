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
  static const int _schemaVersion = 2;

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

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_deleted '
      'ON transactions(is_deleted)',
    );
  }

  Map<String, Object?> _toRow(model.Transaction transaction) {
    return {
      'id': transaction.id,
      'amount': transaction.amount,
      'category': transaction.category,
      'description': transaction.description,
      'date': transaction.date.toIso8601String(),
      'type': transaction.type.name,
      'notes': transaction.notes,
      'is_deleted': transaction.isDeleted ? 1 : 0,
    };
  }

  model.Transaction _toTransaction(Map<String, Object?> row) {
    return model.Transaction(
      id: row['id'] as String,
      amount: (row['amount'] as num).toDouble(),
      category: row['category'] as String,
      description: row['description'] as String,
      date: DateTime.parse(row['date'] as String),
      type: row['type'] == 'income'
          ? model.TransactionType.income
          : model.TransactionType.expense,
      notes: (row['notes'] as String?) ?? '',
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  Future<void> insertTransaction(model.Transaction transaction) async {
    final db = await database;

    await db.insert(
      'transactions',
      _toRow(transaction),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    final db = await database;

    await db.update(
      'transactions',
      _toRow(transaction),
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

    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Les transactions supprimées sont exclues par défaut afin qu'elles ne
  /// remontent ni dans les totaux, ni dans le graphique.
  Future<List<model.Transaction>> getTransactions({
    bool includeDeleted = false,
  }) async {
    final db = await database;

    final rows = await db.query(
      'transactions',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'date DESC',
    );

    return rows.map(_toTransaction).toList();
  }
}
