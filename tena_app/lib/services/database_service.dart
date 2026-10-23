import 'dart:io';
import 'dart:csv';

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
  final double targetCents;
  final double savedCents;
  final bool isDeleted;

  const GoalEntry({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.savedCents,
    this.isDeleted = false,
  });
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _database;

  DatabaseService._internal();

  /// Réinitialise le singleton pour les tests (ferme la base en cache).
  @visibleForTesting
  static void resetForTesting() {
    _database = null;
  }

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
  /// v5 : tables budgets et objectives chiffrées, cohérentes avec les transactions.
  static const int _schemaVersion = 5;

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

        if (oldVersion < 5) {
          await _createBudgetsSchema(db);
          await _createGoalsSchema(db);
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
    await _createBudgetsSchema(db);
    await _createGoalsSchema(db);
  }

  Future<void> _createUserProfileSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL
      )
    ''');
  }

  /// Crée la table `budgets` (montant chiffré, suppression logique).
  Future<void> _createBudgetsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        category TEXT,
        amount_cents TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Crée la table `goals` (nom, cible et épargne chiffrés, suppression logique).
  Future<void> _createGoalsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_cents TEXT NOT NULL,
        saved_cents TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_deleted ON budgets(is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_goals_deleted ON goals(is_deleted)',
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

  /// Convertit une ligne SQLite en modèle [model.Transaction], en déchiffrant
  /// les champs sensibles. Lance une erreur si le déchiffrement échoue,
  /// au lieu de transformer silencieusement la valeur en zéro.
  Future<model.Transaction> _toTransaction(Map<String, Object?> row) async {
    final amountRaw = '${row['amount']}';
    double amount;
    try {
      amount = await CryptoService.decryptNumber(amountRaw);
    } on CryptoException catch (_) {
      // Échec du déchiffrement du montant -> on ne peut pas créer la transaction
      // avec un montant douteux ; on propage l'erreur pour que l'appelant sache
      // qu'il y a un problème de données chiffrées.
      throw CryptoException('DECRYPT_TRANSACTION_AMOUNT',
          'Impossible de déchiffrer le montant de la transaction ${row['id']}');
    }
    return model.Transaction(
      id: row['id'] as String,
      amount: amount,
      category: row['category'] as String,
      description: await CryptoService.decrypt(
        (row['description'] as String?) ?? '',
      ),
      date: DateTime.parse(row['date'] as String),
      type: row['type'] == 'income'
          ? model.TransactionType.income
          : model.TransactionType.expense,
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }
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
  }) async {
    final db = await database;

    final rows = await db.query(
      'transactions',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'date DESC',
    );

    // `_toTransaction` déchiffre chaque ligne : le déchiffrement est asynchrone,
    // la liste est donc construite champ par champ.
    final transactions = <model.Transaction>[];

    for (final row in rows) {
      transactions.add(await _toTransaction(row));
    }

    return transactions;
  }

  /// Convertit un [BudgetEntry] en ligne SQLite, en chiffrant le montant.
  Future<Map<String, Object?>> _budgetToRow(BudgetEntry budget) async {
    return {
      'id': budget.id,
      'category': budget.category,
      'amount_cents': await CryptoService.encryptNumber(budget.amountCents),
      'is_deleted': budget.isDeleted ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convertit une ligne SQLite en [BudgetEntry], en déchiffrant le montant.
  /// Lance une erreur si le déchiffrement échoue, au lieu de transformer
  /// silencieusement la valeur en zéro.
  Future<BudgetEntry> _budgetFromRow(Map<String, Object?> row) async {
    final amountCentsRaw = '${row['amount_cents']}';
    double amountCents;
    try {
      amountCents = await CryptoService.decryptNumber(amountCentsRaw);
    } on CryptoException catch (_) {
      // Échec du déchiffrement du montant -> on propage l'erreur plutôt que
      // de laisser le budget avec un montant zéro invalide.
      throw CryptoException('DECRYPT_BUDGET_AMOUNT',
          'Impossible de déchiffrer le montant du budget ${row['id']}');
    }
    return BudgetEntry(
      id: row['id'] as String,
      category: row['category'] as String?,
      amountCents: amountCents,
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  /// Convertit un [GoalEntry] en ligne SQLite, en chiffrant les champs sensibles.
  Future<Map<String, Object?>> _goalToRow(GoalEntry goal) async {
    return {
      'id': goal.id,
      'name': await CryptoService.encrypt(goal.name),
      'target_cents': await CryptoService.encryptNumber(goal.targetCents),
      'saved_cents': await CryptoService.encryptNumber(goal.savedCents),
      'is_deleted': goal.isDeleted ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convertit une ligne SQLite en [GoalEntry], en déchiffrant les champs sensibles.
  /// Lance des erreurs si le déchiffrement échoue, au lieu de transformer
  /// silencieusement les valeurs en zéro.
  Future<GoalEntry> _goalFromRow(Map<String, Object?> row) async {
    String name;
    try {
      name = await CryptoService.decrypt(
        (row['name'] as String?) ?? '',
      );
    } on CryptoException catch (_) {
      // Si le nom ne peut pas être déchiffré, on utilise la chaîne brute en
      // dernier ressort pour ne pas perdre complètement l'entrée.
      name = (row['name'] as String?) ?? '';
    }

    double targetCents;
    try {
      targetCents = await CryptoService.decryptNumber('${row['target_cents']}');
    } on CryptoException catch (_) {
      // Échec du déchiffrement de la cible -> erreur explicite, pas de zéro silencieux
      throw CryptoException('DECRYPT_GOAL_TARGET',
          'Impossible de déchiffrer la cible du objectif ${row['id']}');
    }

    double savedCents;
    try {
      savedCents = await CryptoService.decryptNumber('${row['saved_cents']}');
    } on CryptoException catch (_) {
      // Échec du déchiffrement de l'épargne -> erreur explicite, pas de zéro silencieux
      throw CryptoException('DECRYPT_GOAL_SAVED',
          'Impossible de déchiffrer l'épargne du objectif ${row['id']}');
    }

    return GoalEntry(
      id: row['id'] as String,
      name: name,
      targetCents: targetCents,
      savedCents: savedCents,
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  // ── Budgets ──────────────────────────────────────────────────────────

  Future<void> insertBudget(BudgetEntry budget) async {
    final db = await database;

    await db.insert(
      'budgets',
      await _budgetToRow(budget),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBudget(BudgetEntry budget) async {
    final db = await database;

    await db.update(
      'budgets',
      await _budgetToRow(budget),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  /// Suppression logique d'un budget.
  Future<void> deleteBudget(String id) async {
    final db = await database;

    await db.update(
      'budgets',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Suppression définitive d'un budget (RGPD).
  Future<void> purgeBudget(String id) async {
    final db = await database;

    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  /// Liste des budgets non supprimés.
  Future<List<BudgetEntry>> getBudgets({bool includeDeleted = false}) async {
    final db = await database;

    final rows = await db.query(
      'budgets',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'category IS NULL, category',
    );

    final budgets = <BudgetEntry>[];
    for (final row in rows) {
      budgets.add(await _budgetFromRow(row));
    }
    return budgets;
  }

  /// Budget global (clé `id = 'global'`).
  Future<double> getGlobalBudget() async {
    final db = await database;

    final rows = await db.query(
      'budgets',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: ['global'],
      limit: 1,
    );

    if (rows.isEmpty) return 0;
    final entry = await _budgetFromRow(rows.first);
    return entry.amountCents;
  }

  /// Définit (ou met à jour) le budget global.
  Future<void> setGlobalBudget(double amount) async {
    await insertBudget(
      BudgetEntry(
        id: 'global',
        category: null,
        amountCents: amount,
      ),
    );
  }

  /// Budget d'une catégorie.
  Future<double> getCategoryBudget(String category) async {
    final db = await database;

    final rows = await db.query(
      'budgets',
      where: 'category = ? AND is_deleted = 0',
      whereArgs: [category],
      limit: 1,
    );

    if (rows.isEmpty) return 0;
    final entry = await _budgetFromRow(rows.first);
    return entry.amountCents;
  }

  /// Définit (ou met à jour) le budget d'une catégorie.
  Future<void> setCategoryBudget(String category, double amount) async {
    await insertBudget(
      BudgetEntry(
        id: category,
        category: category,
        amountCents: amount,
      ),
    );
  }

  /// Supprime le budget d'une catégorie.
  Future<void> deleteCategoryBudget(String category) async {
    await deleteBudget(category);
  }

  // ── Objectifs ────────────────────────────────────────────────────────

  Future<void> insertGoal(GoalEntry goal) async {
    final db = await database;

    await db.insert(
      'goals',
      await _goalToRow(goal),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGoal(GoalEntry goal) async {
    final db = await database;

    await db.update(
      'goals',
      await _goalToRow(goal),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Suppression logique d'un objectif.
  Future<void> deleteGoal(String id) async {
    final db = await database;

    await db.update(
      'goals',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Suppression définitive d'un objectif (RGPD).
  Future<void> purgeGoal(String id) async {
    final db = await database;

    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  

  /// Exporte toutes les transactions en format CSV.
  /// Le CSV résultant peut être copié, partagé ou sauvegardé manuellement.
  /// Format des colonnes : id, amount (avec point), category, description, date (yyyy-MM-dd), type (income/expense), isDeleted, notes
  String exportTransactionsToCsv() async {
    final db = await database;
    final rows = await db.query('transaction', orderBy: 'date ASC');
    
    final csvData = List<List<String>>();
    csvData.add(['id', 'amount', 'category', 'description', 'date', 'type', 'isDeleted', 'notes']);
    
    for final row in rows {
      csvData.add([
        row['id'],
        row['amount'].toString(),
        row['category'] ?? '',
        row['description'] ?? '',
        row['date'] ?? '',
        row['type'] ?? '',
        row['isDeleted'] ? '1' : '0',
        row['notes'] ?? '',
      ]);
    }
    
    return const ListToCsvConverter().convert(csvData);
  }

  /// Exporte toutes les transactions en format CSV vers un fichier accessible.
  /// Note: Sur mobile/web, l'utilisateur doit choisir l'emplacement de sauvegarde.
  /// Le fichier CSV contient toutes les transactions au format standard.
  Future<String> exportTransactionsToFile() async {
    final db = await database;
    final rows = await db.query('transaction', orderBy: 'date ASC');
    
    final csvData = List<List<String>>();
    csvData.add(['id', 'amount', 'category', 'description', 'date', 'type', 'isDeleted', 'notes']);
    
    for final row in rows {
      csvData.add([
        row['id'],
        row['amount'].toString(),
        row['category'] ?? '',
        row['description'] ?? '',
        row['date'] ?? '',
        row['type'] ?? '',
        row['isDeleted'] ? '1' : '0',
        row['notes'] ?? '',
      ]);
    }
    
    final csvString = const ListToCsvConverter().convert(csvData);
    return csvString;
  }

  /// Importe des transactions depuis un format CSV.
  /// Le CSV doit contenir les colonnes : id, amount, category, description, date, type, isDeleted, notes
  /// Les lignes dont l'ID existe déjà seront mises à jour (INSERT OR REPLACE logic).
  Future<int> importTransactionsFromCsv(String csvData) async {
    final List<List<dynamic>> parsed =
        const ListToCsvConverter().convert(csvData, firstRowIsHeader: true);
    
    int imported = 0;
    final db = await database;
    
    for (int i = 1; i < parsed.length; i++) { // Skip header
      final row = parsed[i];
      if (row.length < 7) continue;
      
      final dateString = row[4] as String?;
      final date = DateTime.tryParse(dateString ?? '');
      if (date == null) continue;
      
      final amount = double.tryParse(row[1] as String?) ?? 0.0;
      final category = row[2] as String?;
      final description = row[3] as String?;
      final typeString = row[5] as String?;
      final TransactionType? type =
          typeString == 'income'
              ? TransactionType.income
              : typeString == 'expense'
                  ? TransactionType.expense
                  : null;
      final isDeleted = row[6] == '1';
      final notes = row.length > 7 ? row[7] as String? : '';
      
      if (type == null) continue;
      
      final id = row[0] as String?;
      // Vérifier si l'ID existe déjà - si oui, mettre à jour; sinon, insérer
      final existing = await db.query(
        'transaction',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (existing.isNotEmpty) {
        // Mise à jour de la transaction existante
        await db.update('transaction', {
          'amount': amount,
          'category': category ?? '',
          'description': description ?? '',
          'date': date.toIso8601String(),
          'type': type == TransactionType.income ? 'income' : 'expense',
          'isDeleted': isDeleted ? 1 : 0,
          'notes': notes.isNotEmpty ? notes : '',
        }, where: 'id = ?', whereArgs: [id]);
      } else {
        // Insertion nouvelle
        await db.insertTransaction(
          Transaction(
            id: id,
            amount: amount,
            category: category ?? '',
            description: description ?? '',
            date: date,
            type: type,
            notes: notes.isNotEmpty ? notes : null,
            isDeleted: isDeleted,
          ),
        );
      }
      imported++;
    }
    
    return imported;
  }
}

