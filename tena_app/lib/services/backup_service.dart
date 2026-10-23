/// Sauvegarde et restauration locale des données personnelles de TENΛ Budget.
///
/// Le système collecte les données disponibles depuis les sources existantes :
/// - Profil utilisateur (SQLite, chiffré AES-GCM via [DatabaseService])
/// - Transactions (SQLite, champs sensibles chiffrés via [CryptoService])
/// - Budgets (SharedPreferences via [BudgetService])
/// - Objectifs (SharedPreferences via [GoalService])
///
/// Le format de sauvegarde est versionné, structuré et validable. Une
/// empreinte SHA-256 garantit l'intégrité. Le fichier peut être chiffré en
/// réutilisant le coffre de clés existant ([CryptoService]).
///
/// Aucune donnée n'est envoyée vers un serveur externe. Aucune donnée
/// originale n'est supprimée automatiquement. Aucun fichier n'est restauré
/// sans validation préalable.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/backup_models.dart';
import '../models/transaction.dart';
import 'budget_service.dart';
import 'crypto_service.dart';
import 'database_service.dart';
import 'goal_service.dart';
import 'user_profile_service.dart';

/// Service de sauvegarde et restauration locale.
///
/// Toutes les méthodes sont statiques pour cohérence avec les services
/// existants ([CryptoService], [BudgetService], [GoalService]).
class BackupService {
  BackupService._();

  /// Nom par défaut du fichier de sauvegarde.
  static const String _defaultFileName = 'tena_budget_backup';

  /// Extension des fichiers de sauvegarde.
  static const String _fileExtension = '.tenabackup';

  /// Répertoire par défaut pour les sauvegardes locales.
  ///
  /// Sur mobile, il s'agit du répertoire documents de l'application.
  /// Sur desktop, le répertoire courant de l'utilisateur.
  static Future<String> get _defaultDirectory async {
    if (Platform.isIOS || Platform.isAndroid) {
      final dbPath = await getDatabasesPath();
      return dbPath;
    }
    return Directory.current.path;
  }

  // ┌─────────────────────────────────────────────────────────────────────┐
  // │ 1. COLLECTE DES DONNÉES                                             │
  // └─────────────────────────────────────────────────────────────────────┘

  /// Collecte toutes les données personnelles disponibles pour la sauvegarde.
  ///
  /// Inclut uniquement les données réellement présentes :
  /// - [UserProfileService.getProfile] (profil)
  /// - [DatabaseService.instance.getTransactions] (transactions)
  /// - [BudgetService] (budgets global et par catégorie)
  /// - [GoalService.getGoals] (objectifs)
  ///
  /// Aucune donnée n'est inventée pour combler une absence.
  static Future<BackupData> collectData() async {
    final profile = await _collectProfile();
    final transactions = await _collectTransactions();
    final budgets = await _collectBudgets();
    final goals = await _collectGoals();

    return BackupData(
      profile: profile,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
    );
  }

  /// Récupère le profil utilisateur s'il existe.
  static Future<Map<String, dynamic>?> _collectProfile() async {
    try {
      final profile = await UserProfileService.getProfile();
      if (profile == null) return null;
      return profile.toJson();
    } catch (_) {
      return null;
    }
  }

  /// Récupère toutes les transactions non supprimées.
  static Future<List<Map<String, dynamic>>> _collectTransactions() async {
    final transactions = await DatabaseService.instance.getTransactions();
    return transactions
        .map((t) => _transactionToJson(t))
        .toList();
  }

  static Map<String, dynamic> _transactionToJson(Transaction t) {
    return {
      'id': t.id,
      'amount': t.amount,
      'category': t.category,
      'description': t.description,
      'date': t.date.toIso8601String(),
      'type': t.type.name,
      'notes': t.notes,
      'isDeleted': t.isDeleted,
    };
  }

  /// Récupère les budgets depuis SharedPreferences.
  static Future<Map<String, dynamic>> _collectBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final global = BudgetService.getGlobalBudget();
    final categories = <String, dynamic>{};

    final keys = prefs.getKeys().where((k) =>
        k.startsWith('tena_budget_category_'));

    for (final key in keys) {
      final categoryName = key.substring('tena_budget_category_'.length);
      final amount = prefs.getDouble(key) ?? 0;
      if (amount > 0) {
        categories[categoryName] = amount;
      }
    }

    return {
      'global': await global,
      'categories': categories,
    };
  }

  /// Récupère les objectifs depuis SharedPreferences.
  static Future<List<Map<String, dynamic>>> _collectGoals() async {
    final goals = await GoalService.getGoals();
    return goals.map((g) => g.toJson()).toList();
  }


  // ┌─────────────────────────────────────────────────────────────────────┐
  // │ 2. SÉRIALISATION / FORMAT                                           │
  // └─────────────────────────────────────────────────────────────────────┘

  /// Crée une sauvegarde sérialisée au format JSON.
  ///
  /// Si [encrypt] est vrai, la section `data` est chiffrée avec
  /// [CryptoService.encrypt] (AES-GCM via le keystore existant).
  ///
  /// Retourne le contenu JSON prêt à être écrit dans un fichier.
  static Future<String> createBackupJson({bool encrypt = false}) async {
    final data = await collectData();
    final now = DateTime.now().toUtc();

    final dataJson = jsonEncode(data.toJson());
    final checksum = sha256.convert(utf8.encode(dataJson)).toHexString();

    final file = BackupFile(
      format: _backupFormatMarker,
      version: backupFormatVersion,
      createdAt: now,
      appVersion: '1.0.0+1',
      schemaVersion: backupSchemaVersion,
      encrypted: encrypt,
      checksum: checksum,
      data: encrypt ? await CryptoService.encrypt(dataJson) : data.toJson(),
    );

    return jsonEncode(file.toJson());
  }

  /// Calcule l'empreinte SHA-256 d'une chaîne de caractères.
  static String _computeChecksum(String content) {
    return sha256.convert(utf8.encode(content)).toHexString();
  }


  // ┌─────────────────────────────────────────────────────────────────────┐
  // │ 3. VALIDATION                                                       │
  // └─────────────────────────────────────────────────────────────────────┘

  /// Valide le contenu JSON d'un fichier de sauvegarde sans le restaurer.
  ///
  /// Vérifie :
  /// - Présence et format des métadonnées
  /// - Version du format supportée
  /// - Cohérence de l'empreinte SHA-256
  /// - Déchiffrement si le fichier est chiffré
  ///
  /// Retourne un [BackupValidationResult] indiquant si le fichier est
  /// restaurable et, le cas échéant, un résumé des données.
  static Future<BackupValidationResult> validateBackupJson(
    String jsonContent,
  ) async {
    // 1. Parsing JSON
    Map<String, dynamic> raw;
    try {
      raw = jsonDecode(jsonContent) as Map<String, dynamic>;
    } on FormatException {
      return const BackupValidationResult.invalid(
        'BACKUP_JSON_INVALID',
      );
    }

    // 2. Vérification du marqueur de format
    if (raw['format'] != _backupFormatMarker) {
      return const BackupValidationResult.invalid(
        'BACKUP_FORMAT_UNKNOWN',
      );
    }

    // 3. Vérification de la version
    final version = raw['version'] as int?;
    if (version == null || version != backupFormatVersion) {
      return const BackupValidationResult.invalid(
        'BACKUP_VERSION_UNSUPPORTED',
      );
    }

    // 4. Vérification du schéma
    final schemaVersion = raw['schemaVersion'] as int?;
    if (schemaVersion == null || schemaVersion != backupSchemaVersion) {
      return const BackupValidationResult.invalid(
        'BACKUP_SCHEMA_MISMATCH',
      );
    }

    // 5. Récupération des données (déchiffrement si nécessaire)
    final encrypted = raw['encrypted'] as bool? ?? false;
    final checksum = raw['checksum'] as String?;
    final rawData = raw['data'];

    if (checksum == null || checksum.isEmpty) {
      return const BackupValidationResult.invalid(
        'BACKUP_CHECKSUM_MISSING',
      );
    }

    dynamic dataContent;
    if (encrypted) {
      // Déchiffrer la section data avant de vérifier l'empreinte
      if (rawData is! String) {
        return const BackupValidationResult.invalid(
          'BACKUP_ENCRYPTED_DATA_INVALID',
        );
      }
      try {
        final decrypted = await CryptoService.decrypt(rawData);
        dataContent = jsonDecode(decrypted) as Map<String, dynamic>;
      } catch (_) {
        return const BackupValidationResult.invalid(
          'BACKUP_DECRYPTION_FAILED',
        );
      }
    } else {
      if (rawData is! Map) {
        return const BackupValidationResult.invalid(
          'BACKUP_DATA_INVALID',
        );
      }
      dataContent = rawData;
    }

    // 6. Vérification de l'empreinte SHA-256
    final dataJson = jsonEncode(dataContent);
    final computedChecksum = _computeChecksum(dataJson);
    if (computedChecksum != checksum) {
      return const BackupValidationResult.invalid(
        'BACKUP_CHECKSUM_MISMATCH',
      );
    }

    // 7. Construction des données de sauvegarde
    BackupData backupData;
    try {
      backupData = BackupData.fromJson(
        Map<String, dynamic>.from(dataContent as Map),
      );
    } catch (_) {
      return const BackupValidationResult.invalid(
        'BACKUP_DATA_STRUCTURE_INVALID',
      );
    }

    // 8. Construction du résumé
    final createdAt = DateTime.parse(raw['createdAt'] as String);
    final appVersion = raw['appVersion'] as String? ?? 'inconnu';

    final summary = BackupSummary(
      formatVersion: version,
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      appVersion: appVersion,
      encrypted: encrypted,
      data: backupData,
    );

    return BackupValidationResult.valid(summary);
  }

  /// Valide un fichier de sauvegarde sur le disque.
  static Future<BackupValidationResult> validateBackupFile(File file) async {
    if (!await file.exists()) {
      return const BackupValidationResult.invalid(
        'BACKUP_FILE_NOT_FOUND',
      );
    }

    final content = await file.readAsString();
    return validateBackupJson(content);
  }


  // ┌─────────────────────────────────────────────────────────────────────┐
  // │ 4. CRÉATION DE FICHIER                                              │
  // └─────────────────────────────────────────────────────────────────────┘

  /// Crée un fichier de sauvegarde et l'écrit sur le disque.
  ///
  /// Retourne le chemin du fichier créé. Le fichier n'est jamais écrasé
  /// sans confirmation : si un fichier du même nom existe, un suffixe
  /// horodaté est ajouté.
  static Future<File> createBackupFile({
    bool encrypt = false,
    String? directory,
    String? fileName,
  }) async {
    final jsonContent = await createBackupJson(encrypt: encrypt);
    final dir = directory ?? await _defaultDirectory;
    final name = fileName ?? _defaultFileName;
    final timestamp = DateTime.now().toUtc().toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '');

    final filePath = path.join(dir, '$name$_fileExtension');
    final file = File(filePath);

    // Ne jamais écr’écraser silencieusement un fichier existant
    if (await file.exists()) {
      final numberedPath = path.join(
        dir,
        '$name_$timestamp$_fileExtension',
      );
      return File(numberedPath).writeAsString(jsonContent);
    }

    return file.writeAsString(jsonContent);
  }

  // ┌─────────────────────────────────────────────────────────────────────┐
  // │ 5. RESTAURATION                                                     │
  // └─────────────────────────────────────────────────────────────────────┘

  /// Detects IDs that would overwrite existing data during a restore.
  ///
  /// Exposed for focused regression tests; restore uses this check before its
  /// first write. Duplicate identifiers inside the backup are conflicts too.
  static List<String> findRestoreConflicts(
    BackupData data, {
    required Set<String> transactionIds,
    required Set<String> budgetIds,
    required Set<String> goalIds,
    required bool hasProfile,
  }) {
    final conflicts = <String>{};
    final seenTransactionIds = <String>{};
    for (final transaction in data.transactions) {
      final id = transaction['id'] as String?;
      if (id == null || id.isEmpty) continue;
      if (transactionIds.contains(id) || !seenTransactionIds.add(id)) {
        conflicts.add('transaction:' + id);
      }
    }

    final budgetData = data.budgets;
    if (budgetData['global'] != null && budgetIds.contains('global')) {
      conflicts.add('budget:global');
    }
    final categories = budgetData['categories'] as Map? ?? const {};
    for (final category in categories.keys) {
      final id = category.toString();
      if (budgetIds.contains(id)) conflicts.add('budget:' + id);
    }

    final seenGoalIds = <String>{};
    for (final goal in data.goals) {
      final id = goal['id'] as String?;
      if (id == null || id.isEmpty) continue;
      if (goalIds.contains(id) || !seenGoalIds.add(id)) {
        conflicts.add('goal:' + id);
      }
    }

    if (data.profile != null && hasProfile) conflicts.add('profile');
    return conflicts.toList()..sort();
  }

  /// Restaure les données depuis un fichier de sauvegarde validé.
  ///
  /// Le fichier est d'abord validé ([validateBackupFile]). Si la validation
  /// échoue, aucune donnée n'est modifiée et une [BackupException] est
  /// levée.
  ///
  /// Les données existantes ne sont jamais supprimées avant validation.
  /// Par défaut, aucun élément existant n'est remplacé : les conflits sont
  /// détectés avant la première écriture. Le remplacement doit être demandé
  /// explicitement avec [replaceExisting]. Les écritures sur plusieurs
  /// stockages ne sont pas atomiques ; une panne inattendue peut donc laisser
  /// les écritures précédentes appliquées.
  static Future<void> restoreFromFile(
    File file, {
    bool replaceExisting = false,
  }) async {
    // Validation avant toute modification
    final result = await validateBackupFile(file);
    if (!result.isValid || result.summary == null) {
      throw BackupException(
        result.reason ?? 'BACKUP_VALIDATION_FAILED',
        'Restauration annulée : ${result.reason ?? 'motif inconnu'}',
      );
    }

    final summary = result.summary!;
    final data = summary.data;

    // Même un remplacement explicite ne permet pas des doublons ambigus dans
    // le fichier de sauvegarde lui-même.
    final duplicateIds = findRestoreConflicts(
      data,
      transactionIds: const {},
      budgetIds: const {},
      goalIds: const {},
      hasProfile: false,
    );
    if (duplicateIds.isNotEmpty) {
      throw BackupException(
        'RESTORE_CONFLICT',
        'Restauration annulée : la sauvegarde contient des identifiants '
        'en double (' + duplicateIds.join(', ') + ').',
      );
    }

    if (!replaceExisting) {
      final database = DatabaseService.instance;
      final transactions = await database.getTransactions(includeDeleted: true);
      final budgets = await database.getBudgets(includeDeleted: true);
      final goals = await database.getGoals(includeDeleted: true);
      final hasProfile = await database.getUserProfilePayload() != null;

      final conflicts = findRestoreConflicts(
        data,
        transactionIds: transactions.map((entry) => entry.id).toSet(),
        budgetIds: budgets.map((entry) => entry.id).toSet(),
        goalIds: goals.map((entry) => entry.id).toSet(),
        hasProfile: hasProfile,
      );
      if (conflicts.isNotEmpty) {
        throw BackupException(
          'RESTORE_CONFLICT',
          'Restauration annulée : certains éléments existent déjà '
          '(' + conflicts.join(', ') + '). Aucune donnée n’a été modifiée. '
          'Confirmez explicitement le remplacement avant de réessayer.',
        );
      }
    }

    // Restauration des transactions
    for (final txJson in data.transactions) {
      await _restoreTransaction(txJson);
    }

    // Restauration des budgets
    await _restoreBudgets(data.budgets);

    // Restauration des objectifs
    await _restoreGoals(data.goals);

    // Restauration du profil (si présent)
    if (data.profile != null) {
      await _restoreProfile(data.profile!);
    }
  }

  static Future<void> _restoreTransaction(Map<String, dynamic> json) async {
    final transaction = Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      type: switch (json['type']) {
        'income' => TransactionType.income,
        'expense' => TransactionType.expense,
        'transfer' => TransactionType.transfer,
        final unknown => throw FormatException(
            'Type de transaction inconnu dans la sauvegarde : "$unknown"'),
      },
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

    await DatabaseService.instance.insertTransaction(transaction);
  }

  static Future<void> _restoreBudgets(Map<String, dynamic> json) async {
    final global = json['global'] as double?;
    if (global != null && global > 0) {
      await BudgetService.setGlobalBudget(global);
    }

    final categories = json['categories'] as Map? ?? {};
    for (final entry in categories.entries) {
      final amount = (entry.value as num).toDouble();
      if (amount > 0) {
        await BudgetService.setCategoryBudget(entry.key, amount);
      }
    }
  }

  static Future<void> _restoreGoals(List<Map<String, dynamic>> json) async {
    final goals = json
        .map((e) => Goal(
              id: e['id'] as String,
              name: e['name'] as String,
              target: (e['target'] as num).toDouble(),
              saved: (e['saved'] as num).toDouble(),
            ))
        .toList();
    await GoalService.saveGoals(goals);
  }

  static Future<void> _restoreProfile(Map<String, dynamic> json) async {
    await UserProfileService.saveProfile(
      UserProfile.fromJson(json),
    );
  }


  // ┌─────────────────────────────────────────────────────────────────────┐
  // │ 6. AIDE À LA SÉLECTION DE FICHIER                                   │
  // └─────────────────────────────────────────────────────────────────────┘

  /// Liste les fichiers de sauvegarde disponibles dans le répertoire donné.
  static Future<List<File>> listBackupFiles({String? directory}) async {
    final dir = directory ?? await _defaultDirectory;
    final directoryObj = Directory(dir);

    if (!await directoryObj.exists()) return [];

    return directoryObj
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(_fileExtension))
        .toList()
      ..sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
  }

  /// Supprime un fichier de sauvegarde (l'utilisateur doit confirmer).
  /// Cette opération ne touche jamais aux données de l'application.
  static Future<void> deleteBackupFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
