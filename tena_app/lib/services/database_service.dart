import 'dart:io';

import 'package:csv/csv.dart';
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
/// Montants stockés en centimes (entiers) pour éviter les erreurs de précision floating-point.
class GoalEntry {
  final String id;
  final String name;
  final int targetCents;
  final int savedCents;
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
  static const int _schemaVersion = 6;

  /// Version stockée dans la base de données (lue au premier accès).
  /// Si cette version est inférieure à _schemaVersion, des migrations sont
  /// nécessaires. On indique la version courante pour que les utilisateurs
  /// sachent quand une mise à jour de schéma est en cours.
  static int _storedSchemaVersion = 0;

  /// Message d'information affiché au premier démarrage si des données en
  /// clair sont détectées et en cours de migration vers le chiffrement.
  static String? _migrationMessage;

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

        if (oldVersion < 6) {
          await _migrateToV6(db);
        }

        // Mise à jour de la version stockée après toutes les migrations
        _storedSchemaVersion = newVersion;
        // Vérifier s'il y a eu migration de données en clair
        _checkAndSetMigrationMessage(oldVersion, newVersion);
      },

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
        is_deleted INTEGER NOT NULL DEFAULT 0,
        userId TEXT NOT NULL DEFAULT 'primary'
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
        updated_at TEXT NOT NULL,
        userId TEXT NOT NULL DEFAULT 'primary'
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
        updated_at TEXT NOT NULL,
        userId TEXT NOT NULL DEFAULT 'primary'
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

    /// Migration v5 -> v6 : ajoute l'isolateur `userId` pour séparation multi-utilisateurs.
  /// Toutes les nouvelles lignes reçoivent `userId = 'primary'` par défaut,
  /// assurant la compatibilité avec les données existantes.
  Future<void> _migrateToV6(Database db) async {
    await db.execute(
      'ALTER TABLE transactions ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"',
    );
    await db.execute(
      'ALTER TABLE budgets ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"',
    );
    await db.execute(
      'ALTER TABLE goals ADD COLUMN userId TEXT NOT NULL DEFAULT "primary"',
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
      'category': await CryptoService.encrypt(transaction.category),
      'description': await CryptoService.encrypt(transaction.description),
      'date': await CryptoService.encrypt(transaction.date.toIso8601String()),
      'type': await CryptoService.encrypt(transaction.type.name),
      'notes': await CryptoService.encrypt(transaction.notes),
      'is_deleted': transaction.isDeleted ? 1 : 0,
      'userId': 'primary',
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
      category: await CryptoService.decrypt(row['category'] as String) as String,
      description: await CryptoService.decrypt(
        (row['description'] as String?) ?? '',
      ),
      notes: await CryptoService.decrypt((row['notes'] as String?) ?? ''),
      date: DateTime.parse(await CryptoService.decrypt(row['date'] as String)),
      type: model.TransactionType.values.byName(
          await CryptoService.decrypt(row['type'] as String)
        ),
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  /// Enregistre le JSON versionné du profil sous forme chiffrée AES-GCM.
  Future<void> saveUserProfilePayload(String jsonPayload) async {
    await db.insert('user_profile', {
      'id': 'primary',
      'payload': await CryptoService.encrypt(jsonPayload),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getUserProfilePayload() async {
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

    await db.update(
      'transactions',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restaure une transaction supprimée logiquement.
  Future<void> restoreTransaction(String id) async {

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

    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Les transactions supprimées sont exclues par défaut afin qu'elles ne
  /// remontent ni dans les totaux, ni dans le graphique.
  Future<List<model.Transaction>> getTransactions({
    bool includeDeleted = false,
    String userId = 'primary',
  }) async {

    final rows = await db.query(
      'transactions',
      where: includeDeleted ? 'userId = ?' : 'userId = ? AND is_deleted = 0',
      whereArgs: [userId],
      // orderBy retiré : SQLite ne peut pas trier chronologiquement des dates
      // chiffrées par AES-GCM. Le tri sera appliqué après déchiffrement.
    )

    // `_toTransaction` déchiffre chaque ligne : le déchiffrement est asynchrone,
    // la liste est donc construite champ par champ.
    final transactions = <model.Transaction>[];

    for (final row in rows) {
      transactions.add(await _toTransaction(row));
    }

    // ✅ Tri après déchiffrement : garanti chronologique décroissant
    // Puisque le tri SQL ne peut pas agir sur des valeurs chiffrées,
    // nous trions ici par DateTime pour assurer l'ordre attendu par l'application.
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions;
  }

  /// Convertit un [BudgetEntry] en ligne SQLite, en chiffrant le montant.
  Future<Map<String, Object?>> _budgetToRow(BudgetEntry budget) async {
    return {
      'id': budget.id,
      'category': budget.category != null ? await CryptoService.encrypt(budget.category!) : null,
      'amount_cents': await CryptoService.encryptNumber(budget.amountCents),
      'is_deleted': budget.isDeleted ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
      'userId': 'primary',
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
      category: await CryptoService.decrypt(row['category'] as String) as String?,
      amountCents: amountCents,
      isDeleted: ((row['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  /// Convertit un [GoalEntry] en ligne SQLite, en chiffrant les champs sensibles.
  Future<Map<String, Object?>> _goalToRow(GoalEntry goal) async {
    return {
      'id': goal.id,
      'name': await CryptoService.encrypt(goal.name),
      'target_cents': await CryptoService.encryptNumber(goal.targetCents.toDouble()),
      'saved_cents': await CryptoService.encryptNumber(goal.savedCents.toDouble()),
      'is_deleted': goal.isDeleted ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
      'userId': 'primary',
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

    int targetCents;
    try {
      targetCents = (await CryptoService.decryptNumber('${row['target_cents']}')).round();
    } on CryptoException catch (_) {
      // Échec du déchiffrement de la cible -> erreur explicite, pas de zéro silencieux
      throw CryptoException('DECRYPT_GOAL_TARGET',
          'Impossible de déchiffrer la cible du objectif ${row['id']}');
    }

    int savedCents;
    try {
      savedCents = (await CryptoService.decryptNumber('${row['saved_cents']}')).round();
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

    await db.insert(
      'budgets',
      await _budgetToRow(budget),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBudget(BudgetEntry budget) async {

    await db.update(
      'budgets',
      await _budgetToRow(budget),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  /// Suppression logique d'un budget.
  Future<void> deleteBudget(String id) async {

    await db.update(
      'budgets',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Suppression définitive d'un budget (RGPD).
  Future<void> purgeBudget(String id) async {

    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  /// Liste des budgets non supprimés.
  Future<List<BudgetEntry>> getBudgets({bool includeDeleted = false, String userId = 'primary'}) async {

    final rows = await db.query(
      'budgets',
      where: includeDeleted ? 'userId = ?' : 'userId = ? AND is_deleted = 0',
      whereArgs: [userId],
      // orderBy retiré : la colonne category est chiffrée par AES-GCM.
      // SQLite ne peut pas trier alphabétiquement sur des valeurs chiffrées.
      // Le tri sera appliqué après déchiffrement ci-dessous.
    )

    final budgets = <BudgetEntry>[];
    for (final row in rows) {
      budgets.add(await _budgetFromRow(row));
    }

    // ✅ Tri après déchiffrement : les catégories non chiffrées ne peuvent
    // pas être triées par SQLite. On trie ici par catégorie déchiffrée.
    // Note : le tri par catégorie chiffrée n'est pas garanti d'être
    // identique au tri SQL sur texte clair, mais assure une ordre
    // déterministe après déchiffrement.
    budgets.sort((a, b) {
      final catA = a.category;
      final catB = b.category;
      // Les budgets sans catégorie (global) viennent en premier
      if (catA == null && catB == null) return 0;
      if (catA == null) return -1;
      if (catB == null) return 1;
      return catA.compareTo(catB);
    });

    return budgets;
  }

  /// Budget global (clé `id = 'global'`).
  Future<double> getGlobalBudget() async {

    final rows = await db.query(
      'budgets',
      where: 'id = ? AND is_deleted = 0 AND userId = ?',
      whereArgs: ['primary', 'primary'],
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

    final rows = await db.query(
      'budgets',
      where: 'category = ? AND is_deleted = 0 AND userId = ?',
      whereArgs: [category, 'primary'],
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

    await db.insert(
      'goals',
      await _goalToRow(goal),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGoal(GoalEntry goal) async {

    await db.update(
      'goals',
      await _goalToRow(goal),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Suppression logique d'un objectif.
  Future<void> deleteGoal(String id) async {

    await db.update(
      'goals',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Suppression définitive d'un objectif (RGPD).
  Future<void> purgeGoal(String id) async {

    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  /// Liste des objectifs non supprimés.
  Future<List<GoalEntry>> getGoals({bool includeDeleted = false, String userId = 'primary'}) async {

    final rows = await db.query(
      'goals',
      where: includeDeleted ? 'userId = ?' : 'userId = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    )

    final goals = <GoalEntry>[];
    for (final row in rows) {
      goals.add(await _goalFromRow(row));
    }
    return goals;
  }

  /// Exporte toutes les transactions vers une chaîne CSV.
  ///
  /// Colonnes : id, amount, category, description, date, type, isDeleted, notes
  /// Format date : yyyy-MM-dd (ISO 8601 date only)
  /// Les montants sont exportés avec 2 décimales (format européen : virgule)
  Future<String> exportTransactionsToCsv({bool includeDeleted = false}) async {
    final transactions = await getTransactions(includeDeleted: includeDeleted);

    // En-têtes CSV
    final rows = <List<String>>[];
    rows.add(['id', 'amount', 'category', 'description', 'date', 'type', 'isDeleted', 'notes']);

    for (final tx in transactions) {
      rows.add([
        tx.id,
        tx.amount.toStringAsFixed(2).replaceAll('.', ','),
        tx.category,
        tx.description,
        '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}',
        tx.type.name,
        tx.isDeleted ? '1' : '0',
        tx.notes,
      ]);
    }

    return const CsvConverter().convert(rows);
  }

  /// Importe des transactions depuis une chaîne CSV.
  ///
  /// Format attendu : id, amount, category, description, date, type, isDeleted, notes
  /// Gestion des doublons : INSERT OR REPLACE (UPDATE si ID existe, INSERT sinon)
  /// Retourne le nombre de lignes importées/mises à jour.
  Future<int> importTransactionsFromCsv(String csvData) async {
    final result = const CsvConverter().convert(csvData);
    if (result.isEmpty || result.length < 2) return 0;

    final headers = result.first.map((e) => e.toString().toLowerCase().trim()).toList();
    int imported = 0;

    final db = await database;

    for (int i = 1; i < result.length; i++) {
      final row = result[i];
      if (row.length < 7) continue; // Ligne invalide

      try {
        final id = row[0]?.toString() ?? '';
        final amountStr = row[1]?.toString().replaceAll(',', '.') ?? '0';
        final amount = double.tryParse(amountStr) ?? 0;
        final category = row[2]?.toString() ?? '';
        final description = row[3]?.toString() ?? '';
        final dateStr = row[4]?.toString() ?? '';
        final typeStr = row[5]?.toString().toLowerCase() ?? 'expense';
        final isDeletedStr = row[6]?.toString() ?? '0';
        final notes = row.length > 7 ? row[7]?.toString() ?? '' : '';

        // Validation date
        final dateParts = dateStr.split('-');
        if (dateParts.length != 3) continue;
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        // Validation type
        TransactionType type;
        switch (typeStr) {
          case 'income':
            type = model.TransactionType.income;
            break;
          case 'expense':
            type = model.TransactionType.expense;
            break;
          case 'transfer':
            type = model.TransactionType.transfer;
            break;
          default:
            continue; // Type invaligne -> ignorer
        }

        final isDeleted = isDeletedStr == '1';

        // INSERT OR REPLACE
        await db.insert(
          'transactions',
          {
            'id': id,
            'amount': amount,
            'category': category,
            'description': description,
            'date': date.toIso8601String(),
            'type': type.name,
            'notes': notes,
            'is_deleted': isDeleted ? 1 : 0,
            'userId': 'primary',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        imported++;
      } catch (e) {
        // Ligne invalide -> ignorer, continuer
        continue;
      }
    }

    return imported;
  }

  /// Vérifie si des données en clair ont été détectées et définit un message
  /// de migration à afficher à l'utilisateur.
  static void _checkAndSetMigrationMessage(int oldVersion, int newVersion) {
    // Si on passe de v1/v2 (données en clair) vers v3+ (chiffré), on note
    // qu'une migration a eu lieu. L'utilisateur sera informé au prochain démarrage.
    if (oldVersion < 3 && newVersion >= 3) {
      _migrationMessage = 'Vos données ont été migrées vers le chiffrement renforcé au démarrage précédent.';
    } else if (oldVersion < 5 && newVersion >= 5) {
      _migrationMessage = 'Vos budgets et objectifs ont été chiffrés pour une sécurité renforcée.';
    } else {
      _migrationMessage = null;
    }
  }

  /// Message de migration affiché au premier démarrage après avoir migré
  /// des données en clair vers le chiffrement.
  /// À appeler après l'initialisation de la base de données.
  static String? get migrationMessage => _migrationMessage;

  /// Version de schéma stockée dans la base de données après les migrations.
  static int get storedSchemaVersion => _storedSchemaVersion;
}
