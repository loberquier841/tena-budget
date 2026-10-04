import 'package:path/path.dart';
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

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tena_budget.db');

    return openDatabase(
      path,
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
    );
  }

  Future<void> insertTransaction(model.Transaction transaction) async {
    final db = await database;

    await db.insert(
      'transactions',
      {
        'id': transaction.id,
        'amount': transaction.amount,
        'category': transaction.category,
        'description': transaction.description,
        'date': transaction.date.toIso8601String(),
        'type': transaction.type.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<model.Transaction>> getTransactions() async {
    final db = await database;

    final rows = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );

    return rows.map((row) {
      return model.Transaction(
        id: row['id'] as String,
        amount: (row['amount'] as num).toDouble(),
        category: row['category'] as String,
        description: row['description'] as String,
        date: DateTime.parse(row['date'] as String),
        type: row['type'] == 'income'
            ? model.TransactionType.income
            : model.TransactionType.expense,
      );
    }).toList();
  }
}
