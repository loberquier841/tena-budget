/// Modèles de données pour le format de sauvegarde TENΛ Budget.
///
/// Le format est versionné, structuré et validable. Il contient uniquement
/// les données réellement présentes et autorisées : profil, transactions,
/// budgets et objectifs.
///
/// Le champ `checksum` garantit l'intégrité : toute altération du fichier est
/// détectée avant toute restauration.

import 'dart:convert';

import 'package:meta/meta.dart';

/// Version actuelle du format de sauvegarde.
///
/// Toute modification du format (ajout/suppression de champ, changement de
/// encodage) doit incrémenter ce numéro. Les versions inconnues sont rejetées
/// par [BackupService].
const int backupFormatVersion = 1;

/// Schéma de base de données cible de cette version du format.
const int backupSchemaVersion = 5;

/// Préfixe identifiant un fichier de sauvegarde TENΛ Budget valide.
const String _backupFormatMarker = 'tena_budget_backup';

/// Données personnelles collectées pour une sauvegarde.
///
/// Seules les données effectivement présentes sont incluses. Aucun champ
/// n'est inventé pour combler une absence.
@immutable
class BackupData {
  /// Profil utilisateur (questionnaire local), `null` si absent.
  final Map<String, dynamic>? profile;

  /// Transactions locales, chiffrées ou non selon l'origine.
  final List<Map<String, dynamic>> transactions;

  /// Budgets : montant global et budgets par catégorie.
  final Map<String, dynamic> budgets;

  /// Objectifs d'épargne.
  final List<Map<String, dynamic>> goals;

  const BackupData({
    this.profile,
    required this.transactions,
    required this.budgets,
    required this.goals,
  });

  /// Nombre total de données personnelles incluses dans la sauvegarde.
  int get itemCount =>
      transactions.length +
      goals.length +
      (budgets['categories'] as Map? ?? <String, dynamic>{}).length +
      (budgets['global'] != null ? 1 : 0) +
      (profile != null ? 1 : 0);

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'transactions': transactions,
        'budgets': budgets,
        'goals': goals,
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
    );
  }
}

/// Résumé lisible des données qui seront restaurées.
///
/// Affiché à l'utilisateur avant confirmation de la restauration.
@immutable
class BackupSummary {
  final int formatVersion;
  final int schemaVersion;
  final DateTime createdAt;
  final String appVersion;
  final bool encrypted;
  final BackupData data;

  const BackupSummary({
    required this.formatVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.encrypted,
    required this.data,
  });

  /// Nombre de transactions à restaurer.
  int get transactionCount => data.transactions.length;

  /// Nombre d'objectifs à restaurer.
  int get goalCount => data.goals.length;

  /// Nombre de budgets à restaurer (global + par catégorie).
  int get budgetCount {
    final categories =
        data.budgets['categories'] as Map? ?? <String, dynamic>{};
    return (data.budgets['global'] != null ? 1 : 0) + categories.length;
  }

  /// Indique si un profil est présent.
  bool get hasProfile => data.profile != null;
}

/// Fichier de sauvegarde complet : métadonnées + données + contrôle d'intégrité.
@immutable
class BackupFile {
  /// Identifiant du format (`tena_budget_backup`).
  final String format;

  /// Version du format.
  final int version;

  /// Date de création.
  final DateTime createdAt;

  /// Version de l'application au moment de la création.
  final String appVersion;

  /// Version du schéma de base de données.
  final int schemaVersion;

  /// Indique si la section `data` est chiffrée.
  final bool encrypted;

  /// Empreinte SHA-256 de la section `data` (avant chiffrement).
  final String checksum;

  /// Données de sauvegarde (structurées, ou chaîne chiffrée si `encrypted`).
  final dynamic data;

  const BackupFile({
    required this.format,
    required this.version,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.encrypted,
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
        'checksum': checksum,
        'data': data,
      };

  factory BackupFile.fromJson(Map<String, dynamic> json) {
    return BackupFile(
      format: json['format'] as String,
      version: json['version'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      appVersion: json['appVersion'] as String,
      schemaVersion: json['schemaVersion'] as int,
      encrypted: json['encrypted'] as bool,
      checksum: json['checksum'] as String,
      data: json['data'],
    );
  }
}

/// Erreurs de sauvegarde et restauration.
///
/// Aucune de ces erreurs n'entraîne d'écrasement silencieux des données
/// existantes.
class BackupException implements Exception {
  final String code;
  final String message;

  const BackupException(this.code, this.message);

  @override
  String toString() => 'BackupException($code: $message)';
}

/// Résultat de validation d'un fichier de sauvegarde.
@immutable
class BackupValidationResult {
  /// Le fichier est valide et peut être restauré.
  final bool isValid;

  /// Motif du rejet, si `isValid` est false.
  final String? reason;

  /// Résumé des données contenues, si valide.
  final BackupSummary? summary;

  const BackupValidationResult._({
    required this.isValid,
    this.reason,
    this.summary,
  });

  factory BackupValidationResult.valid(BackupSummary summary) =>
      BackupValidationResult._(isValid: true, summary: summary);

  factory BackupValidationResult.invalid(String reason) =>
      BackupValidationResult._(isValid: false, reason: reason);
}

/// Sérialise les données de manière canonique (clés triées) pour le calcul
/// de l'empreinte. Le résultat est déterministe pour un même contenu.
String _canonicalJson(dynamic value) {
  return const JsonEncoder.withIndent(' ').convert(value);
}