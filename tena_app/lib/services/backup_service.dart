import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:tena_budget/services/crypto_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'budget_service.dart';
import 'category_service.dart';

import 'payment_service.dart';
import '../models/transaction.dart' as model;
import 'user_profile_service.dart';

import 'database_service.dart';
import 'finance_service.dart';
import 'goal_service.dart';
import 'notification_service.dart';
const String _paymentStatusKey = 'tena_payment_status';
const String _globalBudgetKey = 'tena_budget_global';
const String _categoryBudgetKeyPrefix = 'tena_budget_category_';
const String _notificationKey = 'tena_budget_notifications';
const int _currentSchemaVersion = 4;


typedef GetDirectoryFn = Future<Directory> Function();

/// Marker that prefixes the encrypted backup blob to distinguish it from plain text.
const String _backupMarker = 'tenabackup1:';
const String _backupMarkerV2 = 'tenabackup2:';

/// Version of the backup format (increment when the structure changes).
const int _backupFormatVersion = 1;

/// Exception thrown when the target backup file already exists and the caller
/// has not confirmed overwrite.
class BackupFileExistsException implements Exception {
  final String message;
  BackupFileExistsException(this.message);
  @override
  String toString() => 'BackupFileExistsException: $message';
}

/// Exception thrown when the backup file is corrupt or tampered with.
class BackupFileCorruptException implements Exception {
  final String message;
  BackupFileCorruptException([this.message = 'Backup file is corrupt or tampered with']);
  @override
  String toString() => 'BackupFileCorruptException: $message';
}

/// Exception thrown when the backup version is newer than supported.
class BackupVersionException implements Exception {
  final String message;
  BackupVersionException(this.message);
  @override
  String toString() => 'BackupVersionException: $message';
}

/// Contains preview information about a backup.
class BackupPreview {
  final int transactionCount;
  final int goalCount;
  final int notificationCount;
  final bool hasUserProfile;
  final double globalBudget;
  final Map<String, double> categoryBudgets;
  final List<String> categories;
  final String paymentStatus;

  BackupPreview({
    required this.transactionCount,
    required this.goalCount,
    required this.notificationCount,
    required this.hasUserProfile,
    required this.globalBudget,
    required this.categoryBudgets,
    required this.categories,
    required this.paymentStatus,
  });
}

/// Result of importing a backup.
class BackupImportResult {
  final BackupPreview preview;
  final bool imported; // true if import was performed (replaceAll or merge resulted in changes)
  BackupImportResult({required this.preview, required this.imported});
}

/// Service responsible for creating an encrypted backup of all persistent data.
class BackupService {
  BackupService({
    DatabaseService? databaseService,
    UserProfileService? userProfileService,
    BudgetService? budgetService,
    CategoryService? categoryService,
    GoalService? goalService,
    PaymentService? paymentService,
    NotificationService? notificationService,
    CryptoService? cryptoService,
    GetDirectoryFn? getDirectory,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _userProfileService =
            userProfileService ?? UserProfileService(),
        _budgetService = budgetService ?? BudgetService(),
        _categoryService = categoryService ?? CategoryService(),
        _goalService = goalService ?? GoalService(),
        _paymentService = paymentService ?? PaymentService.instance,
        _notificationService =
            notificationService ?? NotificationService(),
        _cryptoService = cryptoService ?? CryptoService(),
        _getDirectory = getDirectory ?? getApplicationDocumentsDirectory;

  final DatabaseService _databaseService;
  final UserProfileService _userProfileService;
  final BudgetService _budgetService;
  final CategoryService _categoryService;
  final GoalService _goalService;
  final PaymentService _paymentService;
  final NotificationService _notificationService;
  final CryptoService _cryptoService;
  final GetDirectoryFn _getDirectory;

  /// Exports an encrypted backup to the app's documents directory.
  /// Returns the [File] of the created backup.
  /// Throws [BackupFileExistsException] if a file with the generated name
  /// already exists and overwrite is not allowed.
  Future<File> exportBackup(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Backup password must not be empty');
    }

    // 1. Gather all persistent data.
    final backupData = await _gatherBackupData();

    // 2. Serialize to JSON.
    final jsonString = jsonEncode(backupData);
    final plainBytes = utf8.encode(jsonString);

    // 3. Generate random salt and nonce.
    final rng = Random.secure();
    final salt = Uint8List.fromList(
        List.generate(16, (_) => rng.nextInt(256))); // 128-bit salt
    final nonce = Uint8List.fromList(
        List.generate(12, (_) => rng.nextInt(256))); // 96-bit nonce for AES-GCM

    // 4. Derive encryption key from password using PBKDF2-HMAC-SHA256.
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 200_000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);

    // 5. Encrypt with AES-GCM using the derived key and the generated nonce.
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );
    final cipherBytes = secretBox.concatenation(); // nonce || ciphertext || mac

    // 6. Build final output: marker + base64(salt + nonce + ciphertext + mac).
    final Uint8List encryptedBytes = Uint8List.fromList(salt);
    encryptedBytes.addAll(nonce);
    encryptedBytes.addAll(cipherBytes);
    final backupString =
        '$_backupMarkerV2${base64Encode(encryptedBytes)}';
    final backupBytes = utf8.encode(backupString);

    // 7. Determine output directory and file name.
    final docDir = await _getDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFile =
        File('${docDir.path}/tena_backup_$timestamp.enc');

    // 8. Avoid overwriting without explicit confirmation.
    if (await backupFile.exists()) {
      throw BackupFileExistsException(
          'Backup file already exists: ${backupFile.path}');
    }

    // 9. Write to a temporary file then rename for atomicity.
    final tempFile =
        File('${docDir.path}/backup_temp_${timestamp}.enc');
    await tempFile.writeAsBytes(backupBytes, flush: true);
    await tempFile.rename(backupFile.path);

    return backupFile;
  }

  /// Assembles a map containing all data that needs to be backed up.
  Future<Map<String, dynamic>> _gatherBackupData() async {
    // Transactions (including logically deleted ones)
    final transactions = await _databaseService
        .getTransactions(includeDeleted: true);
    final txList = transactions.map((tx) => {
      'id': tx.id,
      'amount': tx.amount,
      'category': tx.category,
      'description': tx.description,
      'date': tx.date.toIso8601String(),
      'type': tx.type.name, // enum name
      'notes': tx.notes,
      'isDeleted': tx.isDeleted,
    }).toList();

    // User profile payload (decrypted JSON string or null)
    final userProfilePayload =
        await _databaseService.getUserProfilePayload();

    // Budgets
    final globalBudget = await BudgetService.getGlobalBudget();
    final categories = await CategoryService.getCategories();
    final categoryBudgets = <String, double>{};
    for (final cat in categories) {
      categoryBudgets[cat] =
          await BudgetService.getCategoryBudget(cat);
    }

    // Goals
    final goals = await GoalService.getGoals();
    final goalList = goals.map((g) => {
      'id': g.id,
      'name': g.name,
      'target': g.target,
      'saved': g.saved,
    }).toList();

    // Payment status
    final prefs = await SharedPreferences.getInstance();
    final String? statusString = prefs.getString(_paymentStatusKey);
    final paymentStatus = (statusString != null
        ? _parsePaymentStatus(statusString)
        : PaymentStatus.unverified).name;

    // Notifications
    final notifications = await NotificationService.getNotifications();
    final notifList = notifications.map((n) => {
      'id': n.id,
      'title': n.title,
      'message': n.message,
      'severity': n.severity.name,
      'createdAt': n.createdAt.toIso8601String(),
      'pageIndex': n.pageIndex,
    }).toList();

    return {
      'backupFormatVersion': _backupFormatVersion,
      'schemaVersion': _currentSchemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'transactions': txList,
      'userProfilePayload': userProfilePayload,
      'globalBudget': globalBudget,
      'categoryBudgets': categoryBudgets,
      'goals': goalList,
      'categories': categories,
      'paymentStatus': paymentStatus,
      'notifications': notifList,
    };
  }

  /// Validates the backup data structure and throws [BackupFileCorruptException] if invalid.
  void _validateBackupData(Map<String, dynamic> data) {
    // Required top-level keys
    final requiredKeys = [
      'backupFormatVersion',
      'schemaVersion',
      'createdAt',
      'transactions',
      'userProfilePayload',
      'globalBudget',
      'categoryBudgets',
      'goals',
      'categories',
      'paymentStatus',
      'notifications',
    ];
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        throw BackupFileCorruptException('Missing required key: $key');
      }
    }

    // Validate types and constraints
    if (data['backupFormatVersion'] is! int ||
        data['backupFormatVersion'] < 0) {
      throw BackupFileCorruptException('Invalid backupFormatVersion');
    }
    if (data['schemaVersion'] is! int ||
        data['schemaVersion'] < 0) {
      throw BackupFileCorruptException('Invalid schemaVersion');
    }
    final createdAt = data['createdAt'];
    if (createdAt is! String ||
        DateTime.tryParse(createdAt) == null) {
      throw BackupFileCorruptException('Invalid createdAt date');
    }
    final txList = data['transactions'];
    if (txList is! List) {
      throw BackupFileCorruptException('Transactions must be a list');
    }
    for (final tx in txList) {
      if (tx is! Map ||
          !tx.containsKey('id') ||
          !(tx['id'] is String) ||
          !tx.containsKey('amount') ||
          !(tx['amount'] is num) ||
          !tx.containsKey('category') ||
          !(tx['category'] is String) ||
          !tx.containsKey('description') ||
          !(tx['description'] is String) ||
          !tx.containsKey('date') ||
          !(tx['date'] is String) ||
          DateTime.tryParse(tx['date'] as String) == null ||
          !tx.containsKey('type') ||
          !(tx['type'] is String) ||
          (tx['type'] as String) != 'income' &&
              (tx['type'] as String) != 'expense' ||
          !tx.containsKey('notes') ||
          !(tx['notes'] is String) ||
          !tx.containsKey('isDeleted') ||
          !(tx['isDeleted'] is bool)) {
      throw BackupFileCorruptException('Invalid transaction format');
        }
    }
    final userProfilePayload = data['userProfilePayload'];
    if (userProfilePayload != null && !(userProfilePayload is String)) {
      throw BackupFileCorruptException('userProfilePayload must be String or null');
    }
    if (data['globalBudget'] is! num) {
      throw BackupFileCorruptException('globalBudget must be a num');
    }
    final catBudgets = data['categoryBudgets'];
    if (catBudgets is! Map) {
      throw BackupFileCorruptException('categoryBudgets must be a map');
    }
    catBudgets.forEach((key, value) {
      if (!(key is String) || !(value is num)) {
        throw BackupFileCorruptException('categoryBudgets entry must be String->num');
      }
    });
    final goalsList = data['goals'];
    if (goalsList is! List) {
      throw BackupFileCorruptException('Goals must be a list');
    }
    for (final g in goalsList) {
      if (g is! Map ||
          !g.containsKey('id') ||
          !(g['id'] is String) ||
          !(g['name'] is String) ||
          !(g['name'] is String) ||
          !g.containsKey('target') ||
          !(g['target'] is num) ||
          !g.containsKey('saved') ||
          !(g['saved'] is num)) {
      throw BackupFileCorruptException('Invalid goal format');
        }
    }
    final categoriesList = data['categories'];
    if (categoriesList is! List) {
      throw BackupFileCorruptException('Categories must be a list');
    }
    for (final c in categoriesList) {
      if (!(c is String)) {
        throw BackupFileCorruptException('Category must be a string');
      }
    }
    final paymentStatus = data['paymentStatus'];
    if (!(paymentStatus is String) ||
        !['verified', 'pending', 'demo', 'unverified']
            .contains(paymentStatus)) {
      throw BackupFileCorruptException('Invalid paymentStatus');
    }
    final notifList = data['notifications'];
    if (notifList is! List) {
      throw BackupFileCorruptException('Notifications must be a list');
    }
    for (final n in notifList) {
      if (n is! Map ||
          !n.containsKey('id') ||
          !(n['id'] is String) ||
          !n.containsKey('title') ||
          !(n['title'] is String) ||
          !n.containsKey('message') ||
          !(n['message'] is String) ||
          !n.containsKey('severity') ||
          !(n['severity'] is String) ||
          !['info', 'warning', 'critical'].contains(n['severity']) ||
          !n.containsKey('createdAt') ||
          !(n['createdAt'] is String) ||
          DateTime.tryParse(n['createdAt'] as String) == null ||
          !n.containsKey('pageIndex') ||
          !(n['pageIndex'] is int) ||
          (n.containsKey('isRead') && !(n['isRead'] is bool)) ||
          (n.containsKey('readAt') &&
              !(n['readAt'] is String) &&
              DateTime.tryParse(n['readAt'] as String) == null)) {
      throw BackupFileCorruptException('Invalid notification format');
        }
    }
  }

  Future<BackupImportResult> importBackup(File backupFile, String password, {bool replaceAll = false}) async {
    if (password.isEmpty) {
      throw ArgumentError('Backup password must not be empty');
    }

    // 1. Read file contents
    final String contents = await backupFile.readAsString();

    // 2. Determine marker and extract base64 payload
    String b64;
    bool useV2 = false;
    if (contents.startsWith(_backupMarkerV2)) {
      useV2 = true;
      b64 = contents.substring(_backupMarkerV2.length);
    } else if (contents.startsWith(_backupMarker)) {
      b64 = contents.substring(_backupMarker.length);
    } else {
      throw BackupFileCorruptException('Invalid backup marker');
    }

    // 3. Decode base64
    final Uint8List data = base64Decode(b64);
    Uint8List salt;
    Uint8List nonceAndCipherBox;

    if (useV2) {
      if (data.length < 28) {
        throw BackupFileCorruptException('Backup data too short for V2 format');
      }
      salt = data.sublist(0, 16);
      nonceAndCipherBox = data.sublist(16); // nonce + ciphertext + mac
    } else {
      // V1 format: no salt stored; use empty salt (all zeros)
      salt = Uint8List(16); // 16-byte zero salt
      if (data.length < 12) {
        throw BackupFileCorruptException('Backup data too short for V1 format');
      }
      nonceAndCipherBox = data; // nonce + ciphertext + mac
    }

    // 4. Derive encryption key using PBKDF2
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 200_000,
      bits: 256,
    );
    final SecretKey secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt);

    // 5. Decrypt with AES-GCM
    final aesGcm = AesGcm.with256bits();
    final List<int> plainBytes;
    try {
      plainBytes = await aesGcm.decrypt(
          SecretBox.fromConcatenation(nonceAndCipherBox, nonceLength: 12, macLength: 12),
          secretKey: secretKey);
    } catch (e) {
      throw BackupFileCorruptException('Failed to decrypt backup: $e');
    }

    // 6. Parse JSON
    final String jsonString = utf8.decode(plainBytes);
    final Map<String, dynamic> backupData;
    try {
      backupData = jsonDecode(jsonString);
    } catch (e) {
      throw BackupFileCorruptException('Failed to parse backup JSON: $e');
    }
    _validateBackupData(backupData);

    // 7. Validate versions
    final int backupFormat = backupData['backupFormatVersion'] ?? 0;
    final int schemaVersion = backupData['schemaVersion'] ?? 0;
    if (backupFormat > _backupFormatVersion) {
      throw BackupVersionException(
          'Backup format version $backupFormat is newer than supported version $_backupFormatVersion');
    }
    if (schemaVersion > _currentSchemaVersion) {
      throw BackupVersionException(
          'Backup schema version $schemaVersion is newer than supported schema version $_currentSchemaVersion');
    }

    // 8. Build preview
    final List<dynamic> txList = backupData['transactions'] as List<dynamic>? ?? [];
    final int transactionCount = txList?.length ?? 0;
    final List<dynamic> goalList = backupData['goals'] as List<dynamic>? ?? [];
    final int goalCount = goalList?.length ?? 0;
    final List<dynamic> notifList = backupData['notifications'] as List<dynamic>? ?? [];
    final int notificationCount = notifList?.length ?? 0;
    final String? userProfilePayload = backupData['userProfilePayload'] as String?;
    final bool hasUserProfile = userProfilePayload != null && userProfilePayload.isNotEmpty;
    final double globalBudget = backupData['globalBudget'] as double? ?? 0.0;
    final Map<String, dynamic> catBudgetsMap =
        backupData['categoryBudgets'] as Map<String, dynamic>? ?? {};
    final Map<String, double> categoryBudgets = {};
    catBudgetsMap.forEach((key, value) {
      categoryBudgets[key] = (value as num).toDouble();
    });
    final List<dynamic> categoriesList =
        backupData['categories'] as List<dynamic>? ?? [];
    final List<String> categories = categoriesList.map((e) => e as String).toList();
    final String paymentStatus = backupData['paymentStatus'] as String? ?? 'unverified';

    final BackupPreview preview = BackupPreview(
      transactionCount: transactionCount,
      goalCount: goalCount,
      notificationCount: notificationCount,
      hasUserProfile: hasUserProfile,
      globalBudget: globalBudget,
      categoryBudgets: categoryBudgets,
      categories: categories,
      paymentStatus: paymentStatus,
    );

    // 9. Perform import (replaceAll or merge)
    bool imported = false;

    if (replaceAll) {
      // Create safety backup
      final safetyBackup = await _exportSafetyBackup(password);
      try {
        await _clearAllData();
        await _insertAllData(backupData);
        imported = true;
      } catch (e) {
        // Attempt to restore from safety backup
        try {
          await importBackup(safetyBackup, password, replaceAll: true);
        } catch (_) {
          // Restoration failed; we will rethrow the original exception after cleaning up.
        } finally {
          await safetyBackup.delete();
        }
        rethrow;
      } finally {
        // If we succeeded in importing new backup, delete safety backup.
        if (imported) {
          await safetyBackup.delete();
        }
      }
    } else {
      // Merge mode: only insert if not already present
      imported = await _mergeData(backupData);
    }

    return BackupImportResult(preview: preview, imported: imported);
  }

  Future<File> _exportSafetyBackup(String password) async {
    // Safety backup is exported to a temporary file in the app's documents directory.
    final backupData = await _gatherBackupData();
    final jsonString = jsonEncode(backupData);
    final plainBytes = utf8.encode(jsonString);

    final rng = Random.secure();
    final salt = Uint8List.fromList(
        List.generate(16, (_) => rng.nextInt(256)));
    final nonce = Uint8List.fromList(
        List.generate(12, (_) => rng.nextInt(256)));

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 200_000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);

    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );
    final cipherBytes = secretBox.concatenation();

    final Uint8List encryptedBytes = Uint8List.fromList(salt);
    encryptedBytes.addAll(nonce);
    encryptedBytes.addAll(cipherBytes);
    final backupString =
        '$_backupMarkerV2${base64Encode(encryptedBytes)}';
    final backupBytes = utf8.encode(backupString);

    final docDir = await _getDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final safetyFile =
        File('${docDir.path}/safety_backup_$timestamp.enc');

    await safetyFile.writeAsBytes(backupBytes, flush: true);
    return safetyFile;
  }

  Future<void> _clearAllData() async {
    // Clear transactions and user profile from SQLite
    final db = await _databaseService.database;
    await db.delete('transactions');
    await db.delete('user_profile');

    // Reset SharedPreferences values
    final prefs = await SharedPreferences.getInstance();
    // Global budget
    await prefs.remove(_globalBudgetKey);
    // Category budgets: remove all keys with prefix
    final Set<String> toRemove = {};
    for (final String key in prefs.getKeys()) {
      if (key.startsWith(_categoryBudgetKeyPrefix)) {
        toRemove.add(key);
      }
    }
    for (final String key in toRemove) {
      await prefs.remove(key);
    }
    // Categories: reset to default
    await CategoryService.saveCategories(List.from(CategoryService.defaultCategories));
    // Goals: clear
    await GoalService.saveGoals([]);
    // Payment status: reset to unverified
    await prefs.setString(_paymentStatusKey, _serializePaymentStatus(PaymentStatus.unverified));
    // Notifications: clear
    await prefs.remove(_notificationKey);
  }

  Future<void> _insertAllData(Map<String, dynamic> data) async {
    // Insert transactions
    final List<dynamic> txList = data['transactions'] as List<dynamic>? ?? [];
    for (final Map<String, dynamic> txMap in txList) {
      final model.Transaction tx = model.Transaction(
        id: txMap['id'] as String,
        amount: txMap['amount'] as double,
        category: txMap['category'] as String,
        description: txMap['description'] as String,
        date: DateTime.parse(txMap['date'] as String),
        type: txMap['type'] == 'income'
            ? model.TransactionType.income
            : model.TransactionType.expense,
        notes: txMap['notes'] as String? ?? '',
        isDeleted: txMap['isDeleted'] as bool? ?? false,
      );
      await _databaseService.insertTransaction(tx);
    }

    // User profile
    final String? userProfilePayload = data['userProfilePayload'] as String?;
    if (userProfilePayload != null && userProfilePayload.isNotEmpty) {
      await _databaseService.saveUserProfilePayload(userProfilePayload);
    }

    // Budgets
    final double globalBudget = data['globalBudget'] as double? ?? 0.0;
    await BudgetService.setGlobalBudget(globalBudget);
    final Map<String, dynamic> catBudgetsMap =
        data['categoryBudgets'] as Map<String, dynamic>? ?? {};
    for (final MapEntry<String, dynamic> entry in catBudgetsMap.entries) {
      await BudgetService.setCategoryBudget(entry.key, (entry.value as num).toDouble());
    }

    // Categories: merge with existing (add missing)
    final List<String> backupCategories =
        (data['categories'] as List<dynamic>? ?? []).map((e) => e as String).toList();
    final List<String> currentCategories = await CategoryService.getCategories();
    final Set<String> normalizedCurrent =
        currentCategories.map((c) => c.toLowerCase()).toSet();
    for (final String cat in backupCategories) {
      if (!normalizedCurrent.contains(cat.toLowerCase())) {
        await CategoryService.addCategory(cat);
      }
    }

    // Goals
    final List<dynamic> goalList = data['goals'] as List<dynamic>? ?? [];
    final List<Goal> goalsToSave = goalList.map((gMap) {
      return Goal(
        id: gMap['id'] as String,
        name: gMap['name'] as String,
        target: (gMap['target'] as num).toDouble(),
        saved: (gMap['saved'] as num).toDouble(),
      );
    }).toList();
    await GoalService.saveGoals(goalsToSave);

    // Payment status
    final String paymentStatus = data['paymentStatus'] as String? ?? 'unverified';
    PaymentStatus status;
    switch (paymentStatus) {
      case 'verified':
        status = PaymentStatus.verified;
        break;
      case 'pending':
        status = PaymentStatus.pendingVerification;
        break;
    case 'demo':
      status = PaymentStatus.demo;
      break;
    default:
      status = PaymentStatus.unverified;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paymentStatusKey, _serializePaymentStatus(status));

    // Notifications
    final List<dynamic> notifList = data['notifications'] as List<dynamic>? ?? [];
    final List<BudgetNotification> notifications = [];
    for (final Map<String, dynamic> nMap in notifList) {
      notifications.add(BudgetNotification(
        id: nMap['id'] as String,
        title: nMap['title'] as String,
        message: nMap['message'] as String,
        severity: NotificationSeverity.values.firstWhere(
          (s) => s.name == nMap['severity'],
          orElse: () => NotificationSeverity.info,
        ),
        createdAt: DateTime.parse(nMap['createdAt'] as String),
        pageIndex: nMap['pageIndex'] as int ?? 0,
        isRead: nMap['isRead'] as bool? ?? false,
        readAt: nMap['readAt'] != null
            ? DateTime.parse(nMap['readAt'] as String)
            : null,
      ));
    }
    // Save notifications via SharedPreferences
    final List<String> jsonStrings =
        notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_notificationKey, jsonStrings);
  }

  Future<bool> _mergeData(Map<String, dynamic> data) async {
    bool changed = false;

    // Merge transactions: insert if id not exists
    final List<dynamic> txList = data['transactions'] as List<dynamic>? ?? [];
    for (final Map<String, dynamic> txMap in txList) {
      final String txId = txMap['id'] as String;
      final bool exists = await _transactionIdExists(txId);
      if (!exists) {
        final model.Transaction tx = model.Transaction(
          id: txId,
          amount: txMap['amount'] as double,
          category: txMap['category'] as String,
          description: txMap['description'] as String,
          date: DateTime.parse(txMap['date'] as String),
          type: txMap['type'] == 'income'
              ? model.TransactionType.income
              : model.TransactionType.expense,
          notes: txMap['notes'] as String? ?? '',
          isDeleted: txMap['isDeleted'] as bool? ?? false,
        );
        await _databaseService.insertTransaction(tx);
        changed = true;
      }
    }

    // Merge user profile: replace if present
    final String? userProfilePayload =
        data['userProfilePayload'] as String?;
    if (userProfilePayload != null && userProfilePayload.isNotEmpty) {
      await _databaseService.saveUserProfilePayload(userProfilePayload);
      changed = true;
    }

    // Merge global budget: replace
    final double globalBudget = data['globalBudget'] as double? ?? 0.0;
    final double currentGlobal = await BudgetService.getGlobalBudget();
    if ((globalBudget - currentGlobal).abs() > 0.00001) {
      await BudgetService.setGlobalBudget(globalBudget);
      changed = true;
    }

    // Merge category budgets: set values from backup (override)
    final Map<String, dynamic> catBudgetsMap =
        data['categoryBudgets'] as Map<String, dynamic>? ?? {};
    for (final MapEntry<String, dynamic> entry in catBudgetsMap.entries) {
      final double val = (entry.value as num).toDouble();
      final double current = await BudgetService.getCategoryBudget(entry.key);
      if ((val - current).abs() > 0.00001) {
        await BudgetService.setCategoryBudget(entry.key, val);
        changed = true;
      }
    }

    // Merge categories: add missing
    final List<String> backupCategories =
        (data['categories'] as List<dynamic>? ?? []).map((e) => e as String).toList();
    final List<String> currentCategories = await CategoryService.getCategories();
    final Set<String> normalizedCurrent =
        currentCategories.map((c) => c.toLowerCase()).toSet();
    for (final String cat in backupCategories) {
      if (!normalizedCurrent.contains(cat.toLowerCase())) {
        await CategoryService.addCategory(cat);
        changed = true;
      }
    }

    // Merge goals: insert if id not exists
    final List<dynamic> goalList = data['goals'] as List<dynamic>? ?? [];
    for (final Map<String, dynamic> gMap in goalList) {
      final String goalId = gMap['id'] as String;
      final bool exists = await _goalIdExists(goalId);
      if (!exists) {
        final Goal goal = Goal(
          id: goalId,
          name: gMap['name'] as String,
          target: (gMap['target'] as num).toDouble(),
          saved: (gMap['saved'] as num).toDouble(),
        );
        // Use saveGoals with existing list plus new goal to preserve IDs
        final List<Goal> currentGoals = await GoalService.getGoals();
        if (!currentGoals.any((g) => g.id == goalId)) {
          currentGoals.add(goal);
          await GoalService.saveGoals(currentGoals);
          changed = true;
        }
      }
    }

    // Merge payment status: replace
    final String paymentStatus = data['paymentStatus'] as String? ?? 'unverified';
    PaymentStatus newStatus;
    switch (paymentStatus) {
      case 'verified':
        newStatus = PaymentStatus.verified;
        break;
      case 'pending':
        newStatus = PaymentStatus.pendingVerification;
        break;
      case 'demo':
        newStatus = PaymentStatus.demo;
        break;
      default:
        newStatus = PaymentStatus.unverified;
    }
    final prefs = await SharedPreferences.getInstance();
    final String? currentStatusString = prefs.getString(_paymentStatusKey);
    final PaymentStatus currentStatus = currentStatusString != null
        ? _parsePaymentStatus(currentStatusString)
        : PaymentStatus.unverified;
    if (newStatus != currentStatus) {
      await prefs.setString(_paymentStatusKey, _serializePaymentStatus(newStatus));
      changed = true;
    }

    // Merge notifications: insert if id not exists
    final List<dynamic> notifList = data['notifications'] as List<dynamic>? ?? [];
    for (final Map<String, dynamic> nMap in notifList) {
      final String notifId = nMap['id'] as String;
      final bool exists = await _notificationIdExists(notifId);
      if (!exists) {
        final BudgetNotification notif = BudgetNotification(
          id: notifId,
          title: nMap['title'] as String,
          message: nMap['message'] as String,
          severity: NotificationSeverity.values.firstWhere(
            (s) => s.name == nMap['severity'],
            orElse: () => NotificationSeverity.info,
          ),
          createdAt: DateTime.parse(nMap['createdAt'] as String),
          pageIndex: nMap['pageIndex'] as int ?? 0,
          isRead: nMap['isRead'] as bool? ?? false,
          readAt: nMap['readAt'] != null
              ? DateTime.parse(nMap['readAt'] as String)
              : null,
        );
        final List<BudgetNotification> currentNotifs =
            await NotificationService.getNotifications();
        if (!currentNotifs.any((n) => n.id == notifId)) {
          currentNotifs.add(notif);
          final List<String> jsonStrings = currentNotifs
              .map((n) => jsonEncode(n.toJson()))
              .toList();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_notificationKey, jsonStrings);
          changed = true;
        }
      }
    }

    return changed;
  }

  Future<bool> _transactionIdExists(String txId) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [txId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> _goalIdExists(String goalId) async {
    final List<Goal> goals = await GoalService.getGoals();
    return goals.any((g) => g.id == goalId);
  }

  Future<bool> _notificationIdExists(String notifId) async {
    final List<BudgetNotification> notifications =
        await NotificationService.getNotifications();
    return notifications.any((n) => n.id == notifId);
  }
  PaymentStatus _parsePaymentStatus(String statusString) {
    switch (statusString) {
      case 'verified':
        return PaymentStatus.verified;
      case 'pending':
        return PaymentStatus.pendingVerification;
      case 'demo':
        return PaymentStatus.demo;
      default:
        return PaymentStatus.unverified;
    }
  }
  String _serializePaymentStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.verified:
        return 'verified';
      case PaymentStatus.pendingVerification:
        return 'pending';
      case PaymentStatus.demo:
        return 'demo';
      case PaymentStatus.unverified:
        return 'unverified';
    }
  }

}
