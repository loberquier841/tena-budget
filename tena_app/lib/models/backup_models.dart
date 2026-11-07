/// Modèles de données pour le format de sauvegarde TENΛ Budget.
library;

///
/// Format versionné, structuré, validable, 100% local/offline.
/// - v1 (rétrocompatibilité lecture) : profil, transactions, budgets, objectifs.
/// - v2 : + catégories, préférences, métadonnées/relations, couverture déclarée.
///   Chiffrement : mode `local_key` (keystore existant) ou `portable_passphrase`
///   (dérivation Argon2id, fallback PBKDF2-HMAC-SHA256 ; sel+params dans le
///   fichier ; chiffrement authentifié AES-GCM). Aucune clé/phrase en clair.
///
/// L'empreinte SHA-256 porte sur les données JSON canoniques AVANT chiffrement.
/// Toute altération/corruption est détectée avant restauration.

import 'package:meta/meta.dart';

/// Version actuelle du format de sauvegarde (écriture).
const int backupFormatVersion = 2;

/// Versions de format acceptées en lecture/restauration (rétrocompatibilité).
const Set<int> supportedBackupFormatVersions = {1, 2};

/// Schéma de base de données cible de cette version du format.
const int backupSchemaVersion = 5;

/// Préfixe identifiant un fichier de sauvegarde TENΛ Budget valide.
const String backupFormatMarker = 'tena_budget_backup';

/// Extension des fichiers de sauvegarde.
const String backupFileExtension = '.tenabackup';

/// Modes de chiffrement.
class BackupEncryptionMode {
  static const localKey = 'local_key';
  static const portablePassphrase = 'portable_passphrase';
  const BackupEncryptionMode._();
}

/// Données personnelles collectées pour une sauvegarde.
///
/// Seules les données effectivement présentes/intégrées sont incluses.
@immutable
class BackupData {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> budgets;
  final List<Map<String, dynamic>> goals;
  /// Catégories de dépenses/revenus (réellement persistées).
  final List<String> categories;
  /// Préférences locales sûres (clés techniques connues, valeurs non sensibles).
  final Map<String, dynamic> preferences;
  /// Métadonnées/relations déclarées (liens d'identifiants connus).
  final Map<String, dynamic> metadata;
  /// Couverture réelle déclarée (ce qui est/ n'est pas inclus).
  final Map<String, dynamic> coverage;
  /// Justificatifs (métadonnées + contenu base64 quand présent), liés aux transactions.
  final List<Map<String, dynamic>> documents;

  const BackupData({
    this.profile,
    required this.transactions,
    required this.budgets,
    required this.goals,
    this.categories = const [],
    this.preferences = const {},
    this.metadata = const {},
    this.coverage = const {},
    this.documents = const [],
  });

  int get itemCount =>
      transactions.length +
      goals.length +
      categories.length +
      preferences.length +
      documents.length +
      (budgets['categories'] as Map? ?? <String, dynamic>{}).length +
      (budgets['global'] != null ? 1 : 0) +
      (profile != null ? 1 : 0);

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'transactions': transactions,
        'budgets': budgets,
        'goals': goals,
        'categories': categories,
        'preferences': preferences,
        'metadata': metadata,
        'coverage': coverage,
        'documents': documents,
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      profile: json['profile'] as Map<String, dynamic>?,
      transactions: (json['transactions'] as List? ?? <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      budgets: Map<String, dynamic>.from(json['budgets'] as Map? ?? {}),
      goals: (json['goals'] as List? ?? <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      categories: (json['categories'] as List? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      preferences: Map<String, dynamic>.from(json['preferences'] as Map? ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      coverage: Map<String, dynamic>.from(json['coverage'] as Map? ?? {}),
      documents: (json['documents'] as List? ?? <dynamic>[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList(),
    );
  }
}

/// Résumé lisible affiché avant confirmation de restauration.
@immutable
class BackupSummary {
  final int formatVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final String appVersion;
  final bool encrypted;
  final String? encryptionMode; // local_key | portable_passphrase | null
  final Map<String, dynamic>? kdf; // paramètres dérivation (portable) - sans secret
  final BackupData data;
  final List<String> warnings;

  const BackupSummary({
    required this.formatVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.encrypted,
    required this.encryptionMode,
    required this.kdf,
    required this.data,
    this.warnings = const [],
  });

  int get transactionCount => data.transactions.length;
  int get goalCount => data.goals.length;
  int get categoryCount => data.categories.length;
  int get preferenceCount => data.preferences.length;
  int get documentCount => data.documents.length;
  bool get hasProfile => data.profile != null;
  int get budgetCount {
    final categories = data.budgets['categories'] as Map? ?? <String, dynamic>{};
    return (data.budgets['global'] != null ? 1 : 0) + categories.length;
  }

  bool get isPortable => encryptionMode == BackupEncryptionMode.portablePassphrase;
}

/// Fichier de sauvegarde complet : métadonnées + données + intégrité.
@immutable
class BackupFile {
  final String format;
  final int version;
  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final bool encrypted;
  /// `local_key` | `portable_passphrase` | null (v1/clair)
  final String? encryptionMode;
  /// Paramètres KDF publics (portable) : algorithme, sel, itérations/mémoire, etc.
  /// Ne contient jamais la phrase de passe ni une clé.
  final Map<String, dynamic>? kdf;
  /// Empreinte SHA-256 du JSON canonique des données AVANT chiffrement.
  final String checksum;
  /// Données structurées (clair) ou blob chiffré string (chiffré).
  final dynamic data;

  const BackupFile({
    required this.format,
    required this.version,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.encrypted,
    required this.encryptionMode,
    required this.kdf,
    required this.checksum,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'createdAt': createdAt.toIso8601String(),
        'appVersion': appVersion,
        'schemaVersion': schemaVersion,
        'encrypted': encrypted,
        if (encryptionMode != null) 'encryptionMode': encryptionMode,
        if (kdf != null) 'kdf': kdf,
        'checksum': checksum,
        'data': data,
      };

  factory BackupFile.fromJson(Map<String, dynamic> json) {
    final enc = json['encrypted'] as bool? ?? false;
    final mode = json['encryptionMode'] as String? ??
        (enc ? BackupEncryptionMode.localKey : null); // v1 compat
    return BackupFile(
      format: json['format'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      appVersion: json['appVersion'] as String? ?? 'inconnu',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      encrypted: enc,
      encryptionMode: mode,
      kdf: json['kdf'] == null
          ? null
          : Map<String, dynamic>.from(json['kdf'] as Map),
      checksum: json['checksum'] as String? ?? '',
      data: json['data'],
    );
  }
}

/// Erreurs de sauvegarde/restauration (aucun écrasement silencieux).
class BackupException implements Exception {
  final String code;
  final String message;
  const BackupException(this.code, this.message);
  @override
  String toString() => 'BackupException($code: $message)';
}

/// Résultat de validation/prévisualisation.
@immutable
class BackupValidationResult {
  final bool isValid;
  final String? reason;
  final BackupSummary? summary;

  const BackupValidationResult._({required this.isValid, this.reason, this.summary});

  factory BackupValidationResult.valid(BackupSummary summary) =>
      BackupValidationResult._(isValid: true, summary: summary);

  factory BackupValidationResult.invalid(String reason) =>
      BackupValidationResult._(isValid: false, reason: reason);
}

/// Résultat détaillé d'une restauration.
@immutable
class BackupRestoreResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final String? preRestoreBackupPath;
  final int transactionsRestored;
  final int budgetsRestored;
  final int goalsRestored;
  final int categoriesRestored;
  final bool profileRestored;
  final int preferencesRestored;
  final int documentsRestored;
  final List<String> warnings;
  final List<String> skipped;

  const BackupRestoreResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.preRestoreBackupPath,
    this.transactionsRestored = 0,
    this.budgetsRestored = 0,
    this.goalsRestored = 0,
    this.categoriesRestored = 0,
    this.profileRestored = false,
    this.preferencesRestored = 0,
    this.documentsRestored = 0,
    this.warnings = const [],
    this.skipped = const [],
  });

  factory BackupRestoreResult.failure(String code, String message,
          {String? preRestoreBackupPath, List<String> warnings = const []}) =>
      BackupRestoreResult(
        success: false,
        errorCode: code,
        errorMessage: message,
        preRestoreBackupPath: preRestoreBackupPath,
        warnings: warnings,
      );
}
