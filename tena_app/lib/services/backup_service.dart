/// Sauvegarde et restauration locale TENΛ Budget — 100% offline, local-first.
library;

///
/// Modes (deux, sans serveur) :
/// 1. `local_key` : chiffre avec la clé maître locale ([CryptoService]/keystore).
///    Pratique pour sauvegarde locale automatique/manuelle sur le même appareil.
/// 2. `portable_passphrase` : export chiffré par phrase de passe (dérivation
///    Argon2id via `package:cryptography`, fallback PBKDF2-HMAC-SHA256). Sel +
///    paramètres KDF stockés dans le fichier ; chiffrement authentifié AES-GCM.
///    Aucune clé maître ni phrase de passe dans le fichier. Importable sur un
///    autre appareil SANS l'ancienne clé locale, SI la phrase est connue.
///    Si la phrase est perdue, le déchiffrement est impossible (limite assumée).
///
/// Sécurité/restauration : validation intégrale + SHA-256 avant toute écriture ;
/// prévisualisation ; vérification version/schéma ; sauvegarde de secours locale
/// avant restauration ; aucune suppression/fusion arbitraire ; rapport détaillé.
/// Couverture réelle déclarée (pas d'élément prétendu sauvegardé s'il n'est pas
/// intégré). L'utilisateur choisit la destination (chemin) — appareil/USB/disque.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import '../models/backup_models.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import 'budget_service.dart';
import 'category_service.dart';
import 'crypto_service.dart';
import 'database_service.dart';
import 'goal_service.dart';
import 'document_service.dart';
import 'app_scope.dart';
import 'user_profile_service.dart';

class BackupService {
  BackupService._();

  static const String _defaultFileName = 'tena_budget_backup';
  static const String _portablePrefix = 'tena2p:'; // blob portable authentifié

  // KDF portables (sel/params publics dans le fichier, jamais le secret)
  static const int _saltLen = 16;
  static const int _kdfLen = 32;
  static const int _pbkdf2Iterations = 210000; // robuste pour usage interactif
  // Argon2id : paramètres modérés compatibles desktop/mobile (tunable)
  static const int _argonMemoryKiB = 65536; // 64 MiB
  static const int _argonIterations = 3;
  static const int _argonParallelism = 2;

  /// Répertoire par défaut (suggestion locale). L'utilisateur peut choisir ailleurs.
  static Future<String> get defaultDirectory async {
    if (Platform.isIOS || Platform.isAndroid) {
      return getDatabasesPath();
    }
    return Directory.current.path;
  }

  // ── Collecte (données réelles uniquement) ─────────────────────────────

  static Future<BackupData> collectData(
      {String userId = AppScope.activeUserId}) async {
    final profile = await _collectProfile(userId: userId);
    final transactions = await _collectTransactions(userId: userId);
    final budgets = await _collectBudgets(userId: userId);
    final goals = await _collectGoals(userId: userId);
    final categories = await _collectCategories(userId: userId);
    final preferences = await _collectPreferences();
    final documents = await DocumentService.exportForBackup(userId: userId);

    final txIds = transactions.map((t) => t['id']).whereType<String>().toList();
    final metadata = <String, dynamic>{
      'relations': {
        'transactionIds': txIds,
        'goalIds': goals.map((g) => g['id']).whereType<String>().toList(),
        'budgetCategories': (budgets['categories'] as Map? ?? {}).keys.toList(),
        'documentIds': documents.map((d) => d['id']).whereType<String>().toList(),
      },
    };
    final coverage = <String, dynamic>{
      'profile': profile != null,
      'transactions': true,
      'budgets': true,
      'goals': true,
      'categories': categories.isNotEmpty,
      'preferences': preferences.isNotEmpty,
      'documents': true,
      'attachments': true,
      'documentsCount': documents.length,
      'accounts': false,
      'declaredAt': DateTime.now().toUtc().toIso8601String(),
    };

    return BackupData(
      profile: profile,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      categories: categories,
      preferences: preferences,
      metadata: metadata,
      coverage: coverage,
      documents: documents,
    );
  }

  static Future<Map<String, dynamic>?> _collectProfile({String userId = AppScope.activeUserId}) async {
    try {
      final profile = await UserProfileService.getProfile(userId: userId);
      return profile?.toJson();
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _collectTransactions({String userId = AppScope.activeUserId}) async {
    final transactions = await DatabaseService.instance.getTransactions(userId: userId);
    return transactions.map(_transactionToJson).toList();
  }

  static Map<String, dynamic> _transactionToJson(Transaction t) => {
        'id': t.id,
        'amount': t.amount,
        'category': t.category,
        'description': t.description,
        'date': t.date.toIso8601String(),
        'type': t.type.name,
        'notes': t.notes,
        'isDeleted': t.isDeleted,
      };

  static Future<Map<String, dynamic>> _collectBudgets({String userId = AppScope.activeUserId}) async {
    final global = await BudgetService.getGlobalBudget(userId: userId);
    final entries = await DatabaseService.instance.getBudgets(userId: userId);
    final categories = <String, dynamic>{};
    for (final b in entries) {
      if (b.isDeleted) continue;
      if (b.category != null && b.category!.isNotEmpty) {
        // amountCents stocké en centimes (BudgetEntry) — on exporte la valeur numérique telle quelle.
        categories[b.category!] = b.amountCents;
      }
    }
    return {'global': global, 'categories': categories, 'unit': 'cents'};
  }

  static Future<List<Map<String, dynamic>>> _collectGoals({String userId = AppScope.activeUserId}) async {
    final goals = await GoalService.getGoals(userId: userId);
    return goals.map((g) => g.toJson()).toList();
  }

  static Future<List<String>> _collectCategories({String userId = AppScope.activeUserId}) async {
    try {
      return await CategoryService.getCategories(userId: userId);
    } catch (_) {
      return const [];
    }
  }

  /// Préférences locales sûres (liste blanche de clés techniques connues).
  /// N'inclut jamais de secrets/jetons.
  static Future<Map<String, dynamic>> _collectPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    const allowed = <String>{
      'tena_budget_categories',
      'tena_locale',
      'tena_theme',
      'tena_currency',
      'tena_onboarding_done',
      'tena_backup_auto_enabled',
    };
    final out = <String, dynamic>{};
    for (final k in allowed) {
      if (!prefs.containsKey(k)) continue;
      final v = prefs.get(k);
      if (v is String || v is bool || v is int || v is double) {
        out[k] = v;
      } else if (v is List<String>) {
        out[k] = v;
      }
    }
    return out;
  }

  // ── Chiffrement portable (phrase de passe) ────────────────────────────

  static final _rng = Random.secure();
  static List<int> _randomBytes(int n) => List<int>.generate(n, (_) => _rng.nextInt(256));

  /// Bornes sûres pour KDF issus d'un fichier importé (anti DoS / paramètres aberrants).
  static const int _pbkdf2IterMin = 10000;
  static const int _pbkdf2IterMax = 2000000;
  static const int _argonMemMinKiB = 8192; // 8 MiB
  static const int _argonMemMaxKiB = 262144; // 256 MiB
  static const int _argonIterMin = 1;
  static const int _argonIterMax = 10;
  static const int _argonParMin = 1;
  static const int _argonParMax = 8;
  static const int _saltMinLen = 8;
  static const int _saltMaxLen = 64;

  static int _clampInt(num? v, int min, int max, int fallback) {
    if (v == null) return fallback;
    final i = v.toInt();
    if (i < min || i > max) {
      throw const BackupException(
        'BACKUP_KDF_PARAMS_UNSAFE',
        'Paramètres de dérivation hors limites sûres.',
      );
    }
    return i;
  }

  static void _validateKdf(Map<String, dynamic> params, List<int> salt) {
    if (salt.length < _saltMinLen || salt.length > _saltMaxLen) {
      throw const BackupException('BACKUP_KDF_PARAMS_UNSAFE', 'Sel KDF invalide.');
    }
    final algo = params['algorithm'] as String? ?? 'argon2id';
    if (algo == 'pbkdf2_hmac_sha256') {
      _clampInt(params['iterations'] as num?, _pbkdf2IterMin, _pbkdf2IterMax, _pbkdf2Iterations);
      final bits = (params['bits'] as num?)?.toInt() ?? 256;
      if (bits != 128 && bits != 192 && bits != 256) {
        throw const BackupException('BACKUP_KDF_PARAMS_UNSAFE', 'Taille de clé PBKDF2 invalide.');
      }
      return;
    }
    if (algo != 'argon2id' && algo != 'argon2i') {
      throw const BackupException('BACKUP_KDF_PARAMS_UNSAFE', 'Algorithme KDF non supporté.');
    }
    _clampInt(params['memoryKiB'] as num?, _argonMemMinKiB, _argonMemMaxKiB, _argonMemoryKiB);
    _clampInt(params['iterations'] as num?, _argonIterMin, _argonIterMax, _argonIterations);
    _clampInt(params['parallelism'] as num?, _argonParMin, _argonParMax, _argonParallelism);
    final hl = (params['hashLength'] as num?)?.toInt() ?? _kdfLen;
    if (hl != 16 && hl != 32) {
      throw const BackupException('BACKUP_KDF_PARAMS_UNSAFE', 'Longueur de dérivation invalide.');
    }
  }

  static Future<SecretKey> _deriveSecretKey(
      String passphrase, String saltB64, Map<String, dynamic> params) async {
    List<int> salt;
    try {
      salt = base64Decode(saltB64);
    } catch (_) {
      throw const BackupException('BACKUP_KDF_MISSING', 'Sel de dérivation invalide.');
    }
    _validateKdf(params, salt);
    final algo = params['algorithm'] as String? ?? 'argon2id';
    if (algo == 'pbkdf2_hmac_sha256') {
      final iterations = _clampInt(params['iterations'] as num?, _pbkdf2IterMin, _pbkdf2IterMax, _pbkdf2Iterations);
      final bits = (params['bits'] as num?)?.toInt() ?? 256;
      final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: bits);
      return pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    }
    final a = Argon2id(
      parallelism: _clampInt(params['parallelism'] as num?, _argonParMin, _argonParMax, _argonParallelism),
      memory: _clampInt(params['memoryKiB'] as num?, _argonMemMinKiB, _argonMemMaxKiB, _argonMemoryKiB),
      iterations: _clampInt(params['iterations'] as num?, _argonIterMin, _argonIterMax, _argonIterations),
      hashLength: (params['hashLength'] as num?)?.toInt() ?? _kdfLen,
    );
    return a.deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  }

  static Map<String, dynamic> _defaultKdfParams({bool preferArgon2 = true}) {
    if (preferArgon2) {
      return {
        'algorithm': 'argon2id',
        'salt': base64Encode(_randomBytes(_saltLen)),
        'memoryKiB': _argonMemoryKiB,
        'iterations': _argonIterations,
        'parallelism': _argonParallelism,
        'hashLength': _kdfLen,
      };
    }
    return {
      'algorithm': 'pbkdf2_hmac_sha256',
      'salt': base64Encode(_randomBytes(_saltLen)),
      'iterations': _pbkdf2Iterations,
      'bits': 256,
      'mac': 'HMAC-SHA256',
    };
  }

  static Future<String> _encryptPortable(String clearJson, String passphrase,
      {Map<String, dynamic>? kdf}) async {
    if (passphrase.isEmpty) {
      throw const BackupException(
          'PASSPHRASE_REQUIRED', 'Une phrase de passe est requise pour l\'export portable.');
    }
    final params = kdf ?? _defaultKdfParams(preferArgon2: true);
    final saltB64 = params['salt'] as String;
    final secretKey = await _deriveSecretKey(passphrase, saltB64, params);
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      utf8.encode(clearJson),
      secretKey: secretKey,
    );
    final payload = <String, dynamic>{
      'cipher': 'AES-256-GCM',
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return _portablePrefix + base64Encode(utf8.encode(jsonEncode(payload)));
  }

  static Future<String> _decryptPortable(
      String blob, String passphrase, Map<String, dynamic>? kdf) async {
    if (passphrase.isEmpty) {
      throw const BackupException(
          'PASSPHRASE_REQUIRED', 'La phrase de passe est requise pour cette sauvegarde portable.');
    }
    if (kdf == null) {
      throw const BackupException('BACKUP_KDF_MISSING', 'Paramètres de dérivation absents.');
    }
    final b64 = blob.startsWith(_portablePrefix) ? blob.substring(_portablePrefix.length) : blob;
    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(base64Decode(b64))) as Map);
    } catch (_) {
      throw const BackupException('BACKUP_ENCRYPTED_DATA_INVALID', 'Données chiffrées portables invalides.');
    }
    final saltB64 = kdf['salt'] as String?;
    if (saltB64 == null) {
      throw const BackupException('BACKUP_KDF_MISSING', 'Sel de dérivation absent.');
    }
    final secretKey = await _deriveSecretKey(passphrase, saltB64, kdf);
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      base64Decode(payload['cipherText'] as String),
      nonce: base64Decode(payload['nonce'] as String),
      mac: Mac(base64Decode(payload['mac'] as String)),
    );
    try {
      final clear = await algorithm.decrypt(secretBox, secretKey: secretKey);
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupException(
          'BACKUP_PASSPHRASE_INVALID', 'Phrase de passe incorrecte ou fichier altéré.');
    } catch (_) {
      throw const BackupException(
          'BACKUP_DECRYPTION_FAILED', 'Déchiffrement impossible (phrase incorrecte, fichier altéré ou incompatible).');
    }
  }

  // ── Sérialisation / création ──────────────────────────────────────────

  static String _computeChecksum(String content) =>
      crypto_hash.sha256.convert(utf8.encode(content)).toString();

  /// Empreinte canonique des données seules (rétrocompat v1/v2 existants).
  static String _legacyChecksum(String dataJson) => _computeChecksum(dataJson);

  /// Empreinte des métadonnées + données (nouvelles sauvegardes) : lie
  /// format/version/schéma/mode/chiffrement/KDF publics aux données.
  static String _envelopeChecksum({
    required String format,
    required int version,
    required int schemaVersion,
    required String appVersion,
    required bool encrypted,
    String? encryptionMode,
    Map<String, dynamic>? kdf,
    required String dataJson,
  }) {
    final envelope = <String, dynamic>{
      'format': format,
      'version': version,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'encrypted': encrypted,
      'encryptionMode': ?encryptionMode,
      'kdf': ?kdf,
      'data': jsonDecode(dataJson),
    };
    return _computeChecksum(jsonEncode(envelope));
  }

  /// Crée un JSON de sauvegarde.
  ///
  /// [encrypt] : active le chiffrement. [encryptionMode] :
  /// - `local_key` (défaut quand encrypt=true sans passphrase) : keystore existant.
  /// - `portable_passphrase` : requiert [passphrase] (export autre appareil).
  static Future<String> createBackupJson({
    bool encrypt = false,
    String encryptionMode = BackupEncryptionMode.localKey,
    String? passphrase,
    String userId = AppScope.activeUserId,
  }) async {
    final data = await collectData(userId: userId);
    final now = DateTime.now().toUtc();
    final dataJson = jsonEncode(data.toJson());

    final bool doEncrypt = encrypt;
    String? mode;
    Map<String, dynamic>? kdf;
    dynamic payloadData = data.toJson();

    if (doEncrypt) {
      if (encryptionMode == BackupEncryptionMode.portablePassphrase) {
        mode = BackupEncryptionMode.portablePassphrase;
        kdf = _defaultKdfParams(preferArgon2: true);
        payloadData = await _encryptPortable(dataJson, passphrase ?? '', kdf: kdf);
      } else {
        mode = BackupEncryptionMode.localKey;
        payloadData = await CryptoService.encrypt(dataJson);
      }
    }

    final checksum = _envelopeChecksum(
      format: backupFormatMarker,
      version: backupFormatVersion,
      schemaVersion: backupSchemaVersion,
      appVersion: '1.0.0+1',
      encrypted: doEncrypt,
      encryptionMode: mode,
      kdf: kdf,
      dataJson: dataJson,
    );

    final file = BackupFile(
      format: backupFormatMarker,
      version: backupFormatVersion,
      createdAt: now,
      appVersion: '1.0.0+1',
      schemaVersion: backupSchemaVersion,
      encrypted: doEncrypt,
      encryptionMode: mode,
      kdf: kdf,
      checksum: checksum,
      data: payloadData,
    );
    // Indentation stable pour lisibilité; le checksum porte sur l'enveloppe canonique.
    return const JsonEncoder.withIndent('  ').convert(file.toJson());
  }

  // ── Validation / prévisualisation ─────────────────────────────────────

  static Future<BackupValidationResult> validateBackupJson(
    String jsonContent, {
    String? passphrase,
  }) async {
    Map<String, dynamic> raw;
    try {
      raw = jsonDecode(jsonContent) as Map<String, dynamic>;
    } on FormatException {
      return BackupValidationResult.invalid('BACKUP_JSON_INVALID');
    } catch (_) {
      return BackupValidationResult.invalid('BACKUP_JSON_INVALID');
    }

    if (raw['format'] != backupFormatMarker) {
      return BackupValidationResult.invalid('BACKUP_FORMAT_UNKNOWN');
    }
    final version = (raw['version'] as num?)?.toInt();
    if (version == null || !supportedBackupFormatVersions.contains(version)) {
      return BackupValidationResult.invalid('BACKUP_VERSION_UNSUPPORTED');
    }
    final schemaVersion = (raw['schemaVersion'] as num?)?.toInt();
    final warnings = <String>[];
    if (schemaVersion == null) {
      return BackupValidationResult.invalid('BACKUP_SCHEMA_MISMATCH');
    }
    if (schemaVersion != backupSchemaVersion) {
      warnings.add(
          'Schéma de sauvegarde $schemaVersion (app $backupSchemaVersion) : restauration best-effort, champs inconnus ignorés.');
    }

    final encrypted = raw['encrypted'] as bool? ?? false;
    final checksum = raw['checksum'] as String?;
    final rawData = raw['data'];
    if (checksum == null || checksum.isEmpty) {
      return BackupValidationResult.invalid('BACKUP_CHECKSUM_MISSING');
    }
    final mode = raw['encryptionMode'] as String? ??
        (encrypted ? BackupEncryptionMode.localKey : null);
    final kdf = raw['kdf'] == null ? null : Map<String, dynamic>.from(raw['kdf'] as Map);

    dynamic dataContent;
    if (encrypted) {
      if (rawData is! String) {
        return BackupValidationResult.invalid('BACKUP_ENCRYPTED_DATA_INVALID');
      }
      try {
        if (mode == BackupEncryptionMode.portablePassphrase) {
          final decrypted = await _decryptPortable(rawData, passphrase ?? '', kdf);
          dataContent = jsonDecode(decrypted) as Map<String, dynamic>;
        } else {
          final decrypted = await CryptoService.decrypt(rawData);
          dataContent = jsonDecode(decrypted) as Map<String, dynamic>;
        }
      } on BackupException catch (e) {
        return BackupValidationResult.invalid(e.code);
      } catch (_) {
        return BackupValidationResult.invalid('BACKUP_DECRYPTION_FAILED');
      }
    } else {
      if (rawData is! Map) return BackupValidationResult.invalid('BACKUP_DATA_INVALID');
      dataContent = rawData;
    }

    final dataJson = jsonEncode(dataContent);
    final expectedEnvelope = _envelopeChecksum(
      format: raw['format'] as String? ?? backupFormatMarker,
      version: version,
      schemaVersion: schemaVersion,
      appVersion: raw['appVersion'] as String? ?? 'inconnu',
      encrypted: encrypted,
      encryptionMode: mode,
      kdf: kdf,
      dataJson: dataJson,
    );
    final expectedLegacy = _legacyChecksum(dataJson);
    if (checksum != expectedEnvelope && checksum != expectedLegacy) {
      return BackupValidationResult.invalid('BACKUP_CHECKSUM_MISMATCH');
    }

    BackupData backupData;
    try {
      backupData = BackupData.fromJson(Map<String, dynamic>.from(dataContent as Map));
    } catch (_) {
      return BackupValidationResult.invalid('BACKUP_DATA_STRUCTURE_INVALID');
    }

    // Couverture déclarée vs réelle (intégrité sémantique prudente)
    final cov = backupData.coverage;
    if (cov['documents'] == true || cov['accounts'] == true) {
      warnings.add('Le fichier déclare des éléments non pris en charge par ce socle.');
    }

    final summary = BackupSummary(
      formatVersion: version,
      schemaVersion: schemaVersion,
      createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? nowUtc(),
      appVersion: raw['appVersion'] as String? ?? 'inconnu',
      encrypted: encrypted,
      encryptionMode: mode,
      kdf: kdf,
      data: backupData,
      warnings: warnings,
    );
    return BackupValidationResult.valid(summary);
  }

  static DateTime nowUtc() => DateTime.now().toUtc();
  static String _ts() => DateTime.now().toUtc().microsecondsSinceEpoch.toString();

  /// Vérifie qu'une phrase de passe portable est correcte (sans restaurer).
  static Future<BackupValidationResult> verifyPassphrase(
      String jsonContent, String passphrase) async {
    return await validateBackupJson(jsonContent, passphrase: passphrase);
  }

  static Future<BackupValidationResult> validateBackupFile(File file,
      {String? passphrase}) async {
    if (!await file.exists()) {
      return BackupValidationResult.invalid('BACKUP_FILE_NOT_FOUND');
    }
    try {
      final content = await file.readAsString();
      return await validateBackupJson(content, passphrase: passphrase);
    } catch (_) {
      return BackupValidationResult.invalid('BACKUP_JSON_INVALID');
    }
  }

  // ── Création de fichier (aucun écrasement silencieux) ────────────────

  static Future<File> createBackupFile({
    bool encrypt = false,
    String encryptionMode = BackupEncryptionMode.localKey,
    String? passphrase,
    String? directory,
    String? fileName,
    String userId = AppScope.activeUserId,
  }) async {
    final jsonContent = await createBackupJson(
      encrypt: encrypt,
      encryptionMode: encryptionMode,
      passphrase: passphrase,
      userId: userId,
    );
    final dir = directory ?? await defaultDirectory;
    final name = fileName ?? _defaultFileName;
    final basePath = path.join(dir, '$name$backupFileExtension');
    final file = await _nonOverwritingFile(basePath, dir, name);
    return file.writeAsString(jsonContent);
  }

  static Future<File> _nonOverwritingFile(
      String basePath, String dir, String name) async {
    var candidate = File(basePath);
    if (!await candidate.exists()) return candidate;
    for (var i = 0; i < 1000; i++) {
      candidate = File(path.join(dir, '${name}_${_ts()}$backupFileExtension'));
      if (!await candidate.exists()) return candidate;
    }
    return candidate;
  }

  // ── Restauration sûre ─────────────────────────────────────────────────

  /// API compat (v1) : restaure ou lève [BackupException] si invalide/échec.
  static Future<void> restoreFromFile(File file,
      {String? passphrase, String userId = 'primary'}) async {
    final res = await restoreFromFileDetailed(file,
        passphrase: passphrase, userId: userId);
    if (!res.success) {
      throw BackupException(
        res.errorCode ?? 'RESTORE_FAILED',
        res.errorMessage ?? 'Restauration annulée.',
      );
    }
  }

  /// Restauration détaillée : validation intégrale, sauvegarde de secours
  /// locale AVANT toute écriture, rapport (aucun écrasement silencieux).
  /// [passphrase] requis si sauvegarde portable. Retourne toujours un résultat.
  static Future<BackupRestoreResult> restoreFromFileDetailed(File file,
      {String? passphrase, String userId = 'primary'}) async {
    final result = await validateBackupFile(file, passphrase: passphrase);
    if (!result.isValid || result.summary == null) {
      return BackupRestoreResult.failure(
          result.reason ?? 'BACKUP_VALIDATION_FAILED',
          'Restauration annulée : fichier invalide/non déchiffrable.');
    }
    final summary = result.summary!;
    if (summary.encrypted &&
        summary.encryptionMode == BackupEncryptionMode.portablePassphrase &&
        (passphrase == null || passphrase.isEmpty)) {
      return BackupRestoreResult.failure(
          'PASSPHRASE_REQUIRED', 'Phrase de passe requise pour cette sauvegarde portable.');
    }

    String? safetyPath;
    try {
      safetyPath = await _createPreRestoreSafetyBackup();
    } catch (_) {
      // Best-effort : on continue mais on le signale (pas d'écrasement silencieux).
    }

    final data = summary.data;
    var txN = 0, budN = 0, goalN = 0, catN = 0, prefN = 0, docN = 0;
    var profOk = false;
    final warnings = <String>[...summary.warnings];
    final skipped = <String>[];

    if (safetyPath == null) {
      warnings.add('Sauvegarde de secours pré-restauration non créée (chemin indisponible).');
    } else {
      warnings.add('Sauvegarde de secours créée avant restauration : $safetyPath');
    }

    try {
      // Transactions : upsert par ID via mécanisme existant.
      for (final txJson in data.transactions) {
        try {
          await _restoreTransaction(txJson, userId: userId);
          txN++;
        } catch (e) {
          skipped.add('transaction ${txJson['id']}: $e');
        }
      }
      // Budgets
      try {
        await _restoreBudgets(data.budgets, userId: userId);
        budN = (data.budgets['categories'] as Map? ?? {}).length +
            (data.budgets['global'] != null ? 1 : 0);
      } catch (e) {
        skipped.add('budgets: $e');
      }
      // Objectifs
      try {
        await _restoreGoals(data.goals, userId: userId);
        goalN = data.goals.length;
      } catch (e) {
        skipped.add('goals: $e');
      }
      // Catégories (fusion non destructive : ajout des absentes)
      if (data.categories.isNotEmpty) {
        try {
          final existing = await CategoryService.getCategories();
          final lower = existing.map((c) => c.toLowerCase()).toSet();
          for (final c in data.categories) {
            if (c.trim().isEmpty) continue;
            if (!lower.contains(c.toLowerCase())) {
              await CategoryService.addCategory(c);
              lower.add(c.toLowerCase());
              catN++;
            }
          }
        } catch (e) {
          skipped.add('categories: $e');
        }
      }
      // Préférences sûres (liste blanche) — ne restaure que les clés connues.
      if (data.preferences.isNotEmpty) {
        prefN = await _restorePreferences(data.preferences, skipped);
      }
      // Profil
      if (data.profile != null) {
        try {
          await _restoreProfile(data.profile!, userId: userId);
          profOk = true;
        } catch (e) {
          skipped.add('profile: $e');
        }
      }
      // Documents/justificatifs (restauration relations + fichiers quand présents)
      if (data.documents.isNotEmpty) {
        try {
          docN = await DocumentService.importFromBackup(data.documents, userId: userId);
          final missing = data.documents.where((d) => d['contentBase64'] == null).length;
          if (missing > 0) {
            warnings.add('$missing document(s) sans contenu (fichier manquant/corrompu dans la sauvegarde) : métadonnées restaurées.');
          }
        } catch (e) {
          skipped.add('documents: $e');
        }
      }
    } catch (e) {
      return BackupRestoreResult.failure('RESTORE_FAILED', 'Restauration interrompue: $e',
          preRestoreBackupPath: safetyPath, warnings: warnings);
    }

    if (skipped.isNotEmpty) {
      warnings.add('Éléments ignorés (détails): ${skipped.length} — voir rapport.');
    }

    return BackupRestoreResult(
      success: skipped.isEmpty,
      errorCode: skipped.isEmpty ? null : 'RESTORE_PARTIAL',
      errorMessage: skipped.isEmpty ? null : 'Restauration partielle: certains éléments ignorés.',
      preRestoreBackupPath: safetyPath,
      transactionsRestored: txN,
      budgetsRestored: budN,
      goalsRestored: goalN,
      categoriesRestored: catN,
      profileRestored: profOk,
      preferencesRestored: prefN,
      documentsRestored: docN,
      warnings: warnings,
      skipped: skipped,
    );
  }

  /// Répertoire optionnel pour artefacts de test (sauvegarde de secours).
  @visibleForTesting
  static String? testBackupDirectory;

  static Future<String?> _createPreRestoreSafetyBackup() async {
    final dir = testBackupDirectory ?? await defaultDirectory;
    final json = await createBackupJson(encrypt: true, encryptionMode: BackupEncryptionMode.localKey, userId: AppScope.activeUserId);
    final file = await _nonOverwritingFile(
        path.join(dir, '${_defaultFileName}_pre_restore$backupFileExtension'),
        dir,
        '${_defaultFileName}_pre_restore');
    await file.writeAsString(json);
    return file.path;
  }

  static Future<int> _restorePreferences(
      Map<String, dynamic> prefsIn, List<String> skipped) async {
    const allowed = <String>{
      'tena_locale',
      'tena_theme',
      'tena_currency',
      'tena_onboarding_done',
      'tena_backup_auto_enabled',
      // 'tena_budget_categories' gérée via CategoryService (fusion sûre)
    };
    final prefs = await SharedPreferences.getInstance();
    var n = 0;
    for (final e in prefsIn.entries) {
      if (!allowed.contains(e.key)) continue;
      try {
        final v = e.value;
        if (v is bool) {
          await prefs.setBool(e.key, v);
        } else if (v is int) {
          await prefs.setInt(e.key, v);
        } else if (v is double) {
          await prefs.setDouble(e.key, v);
        } else if (v is String) {
          await prefs.setString(e.key, v);
        } else {
          continue;
        }
        n++;
      } catch (err) {
        skipped.add('pref ${e.key}: $err');
      }
    }
    return n;
  }

  static Future<void> _restoreTransaction(Map<String, dynamic> json,
      {String userId = 'primary'}) async {
    final transaction = Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: (json['category'] ?? 'Autre') as String,
      description: (json['description'] ?? '') as String,
      date: DateTime.parse(json['date'] as String),
      type: json['type'] == 'income'
          ? TransactionType.income
          : json['type'] == 'transfer'
              ? TransactionType.transfer
              : TransactionType.expense,
      notes: json['notes'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
    await DatabaseService.instance.insertTransaction(transaction, userId: userId);
  }

  static Future<void> _restoreBudgets(Map<String, dynamic> json,
      {String userId = 'primary'}) async {
    final global = (json['global'] as num?)?.toDouble();
    if (global != null && global > 0) {
      await BudgetService.setGlobalBudget(global, userId: userId);
    }
    final categories = json['categories'] as Map? ?? {};
    // Compat: ancien format (prefs) = montant devise; format DB exporté (v8+) =
    // centimes avec unit:'cents' via BudgetEntry.amountCents. BudgetService
    // attend un montant (API existante) — conversion défensive.
    final unit = json['unit'] as String?;
    for (final entry in categories.entries) {
      final raw = (entry.value as num?)?.toDouble() ?? 0;
      if (raw <= 0) continue;
      final amount = unit == 'cents' ? raw / 100.0 : raw;
      await BudgetService.setCategoryBudget(entry.key.toString(), amount,
          userId: userId);
    }
  }

  static Future<void> _restoreGoals(List<Map<String, dynamic>> json,
      {String userId = 'primary'}) async {
    final goals = json.map((e) {
      final targetCents = e['targetCents'] != null
          ? (e['targetCents'] as num).toInt()
          : (((e['target'] as num?) ?? 0.0) * 100).round();
      final savedCents = e['savedCents'] != null
          ? (e['savedCents'] as num).toInt()
          : (((e['saved'] as num?) ?? 0.0) * 100).round();
      return Goal(
        id: e['id'] as String,
        name: e['name'] as String,
        targetCents: targetCents,
        savedCents: savedCents,
        createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(e['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
    await GoalService.saveGoals(goals, userId: userId);
  }

  static Future<void> _restoreProfile(Map<String, dynamic> json,
      {String userId = AppScope.activeUserId}) async {
    await UserProfileService.saveProfile(UserProfile.fromJson(json),
        userId: userId);
  }

  // ── Utilitaires fichiers (locaux, choix utilisateur) ──────────────────

  static Future<List<File>> listBackupFiles({String? directory}) async {
    final dir = directory ?? await defaultDirectory;
    final directoryObj = Directory(dir);
    if (!await directoryObj.exists()) return [];
    return directoryObj
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(backupFileExtension))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  static Future<void> deleteBackupFile(File file) async {
    if (await file.exists()) await file.delete();
  }
}
