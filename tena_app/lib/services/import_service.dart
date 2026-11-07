import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import '../models/transaction.dart';

/// Résultat d'analyse d'un import (pré-validation), fidèle au commit.
class ImportAnalysis {
  final String separator;
  final bool hasHeader;
  final List<String> headers;
  final CsvColumnMapping mapping;
  final List<ImportRowResult> rows;
  final ImportReport report;

  const ImportAnalysis({
    required this.separator,
    required this.hasHeader,
    required this.headers,
    required this.mapping,
    required this.rows,
    required this.report,
  });

  /// Lignes prêtes à être commitées (hors doublons probables exclus et erreurs).
  List<PreparedTransaction> preparedTransactions({
    bool includeProbableDuplicates = false,
  }) {
    return rows
        .where((r) => r.prepared != null)
        .where(
          (r) =>
              includeProbableDuplicates ||
              r.status != ImportRowStatus.duplicateProbable,
        )
        .map((r) => r.prepared!)
        .toList();
  }

  ImportAnalysis copyWithMapping(CsvColumnMapping newMapping) {
    final remapped = ImportService._remapRows(
      rawRows: rows.map((r) => r.rawRow).toList(),
      headers: headers,
      mapping: newMapping,
      hasHeader: hasHeader,
      separator: separator,
    );
    return remapped;
  }
}

/// Mapping colonnes CSV -> champs internes.
/// index = -1 signifie non mappé.
class CsvColumnMapping {
  final int dateIndex;
  final int labelIndex;
  final int amountIndex;
  final int debitIndex;
  final int creditIndex;
  final int categoryIndex;
  final int idIndex;
  final int typeIndex;
  final int isDeletedIndex;
  final int notesIndex;

  const CsvColumnMapping({
    this.dateIndex = -1,
    this.labelIndex = -1,
    this.amountIndex = -1,
    this.debitIndex = -1,
    this.creditIndex = -1,
    this.categoryIndex = -1,
    this.idIndex = -1,
    this.typeIndex = -1,
    this.isDeletedIndex = -1,
    this.notesIndex = -1,
  });

  bool get isCanonicalTenA =>
      idIndex >= 0 &&
      amountIndex >= 0 &&
      categoryIndex >= 0 &&
      labelIndex >= 0 &&
      dateIndex >= 0 &&
      typeIndex >= 0 &&
      isDeletedIndex >= 0;

  CsvColumnMapping copyWith({
    int? dateIndex,
    int? labelIndex,
    int? amountIndex,
    int? debitIndex,
    int? creditIndex,
    int? categoryIndex,
    int? idIndex,
    int? typeIndex,
    int? isDeletedIndex,
    int? notesIndex,
  }) {
    return CsvColumnMapping(
      dateIndex: dateIndex ?? this.dateIndex,
      labelIndex: labelIndex ?? this.labelIndex,
      amountIndex: amountIndex ?? this.amountIndex,
      debitIndex: debitIndex ?? this.debitIndex,
      creditIndex: creditIndex ?? this.creditIndex,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      idIndex: idIndex ?? this.idIndex,
      typeIndex: typeIndex ?? this.typeIndex,
      isDeletedIndex: isDeletedIndex ?? this.isDeletedIndex,
      notesIndex: notesIndex ?? this.notesIndex,
    );
  }
}

enum ImportRowStatus { ready, error, duplicateProbable, updateById }

class PreparedTransaction {
  final String id;
  final int amountCentsSigned;
  final String category;
  final String description;
  final DateTime date;
  final TransactionType type;
  final String notes;
  final bool isDeleted;
  final bool canonicalIdUpdate;
  final bool preserveSignedAmount;
  final String fingerprint;

  const PreparedTransaction({
    required this.id,
    required this.amountCentsSigned,
    required this.category,
    required this.description,
    required this.date,
    required this.type,
    required this.notes,
    required this.isDeleted,
    required this.canonicalIdUpdate,
    required this.preserveSignedAmount,
    required this.fingerprint,
  });

  double get amountAbsEuros => (amountCentsSigned.abs()) / 100.0;

  /// Pour format canonique TENΛ (compat export/import), conserve le montant
  /// signé tel qu'attendu par les contrats existants.
  Transaction toTransaction({bool? preserveSignedAmount}) {
    final signed = preserveSignedAmount ?? this.preserveSignedAmount;
    final amount = signed ? amountCentsSigned / 100.0 : amountAbsEuros;
    return Transaction(
      id: id,
      amount: amount,
      category: category,
      description: description,
      date: date,
      type: type,
      notes: notes,
      isDeleted: isDeleted,
    );
  }
}

class ImportRowResult {
  final int rowIndex;
  final List<dynamic> rawRow;
  final ImportRowStatus status;
  final PreparedTransaction? prepared;
  final List<String> errors;
  final String? duplicateOf; // id ou empreinte existante
  final bool canInclude;

  const ImportRowResult({
    required this.rowIndex,
    required this.rawRow,
    required this.status,
    required this.prepared,
    required this.errors,
    required this.duplicateOf,
    required this.canInclude,
  });
}

/// Résultat d'un import CSV (compat héritée)
class ImportResult {
  final bool success;
  final List<Transaction> transactions;
  final List<Map<String, dynamic>> errors;
  final ImportReport report;

  ImportResult({
    required this.success,
    required this.transactions,
    required this.errors,
    required this.report,
  });
}

/// Rapport d'import complet
class ImportReport {
  final int imported;
  final int ignored;
  final int modified;
  final int ambiguous;
  final int duplicates;
  final int errors;
  final bool isPartial;
  final List<int> yearsImported;
  final int totalRows;
  final int ready;
  final int duplicateProbable;
  final int updatesById;

  ImportReport({
    this.imported = 0,
    this.ignored = 0,
    this.modified = 0,
    this.ambiguous = 0,
    this.duplicates = 0,
    this.errors = 0,
    this.isPartial = false,
    this.yearsImported = const [],
    this.totalRows = 0,
    this.ready = 0,
    this.duplicateProbable = 0,
    this.updatesById = 0,
  });
}

/// État du pipeline d'import (compat)
enum ImportStep {
  selection,
  analysis,
  detection,
  preview,
  validation,
  completion,
}

class ImportService {
  /// Mappage des headers CSV vers les champs internes (compat + détection)
  static const Map<String, String> csvHeaderMap = {
    'categorie': 'category',
    'catégorie': 'category',
    'category': 'category',
    'categories': 'category',
    'budget': 'budget',
    'budget annuel': 'budget',
    'prévu': 'budget',
    'prevu': 'budget',
    'dépense': 'debit',
    'depense': 'debit',
    'débit': 'debit',
    'debit': 'debit',
    'depensé': 'spent',
    'dépensé': 'spent',
    'depense montant': 'debit',
    'sortie': 'debit',
    'credit': 'credit',
    'crédit': 'credit',
    'recette': 'credit',
    'entree': 'credit',
    'entrée': 'credit',
    'restant': 'remaining',
    'reste': 'remaining',
    'personne': 'person',
    'person': 'person',
    'qui': 'person',
    'date': 'date',
    'date operation': 'date',
    'date opération': 'date',
    'date valeur': 'date',
    'booking date': 'date',
    'année': 'date',
    'annee': 'date',
    'montant': 'amount',
    'amount': 'amount',
    'value': 'amount',
    'somme': 'amount',
    'libellé': 'label',
    'libelle': 'label',
    'label': 'label',
    'description': 'label',
    'intitule': 'label',
    'intitulé': 'label',
    'nom': 'label',
    'memo': 'label',
    'notes': 'notes',
    'note': 'notes',
    'commentaire': 'notes',
    'objectif': 'goal',
    'économies': 'goal',
    'economies': 'goal',
    'type': 'type',
    'isdeleted': 'isdeleted',
    'is_deleted': 'isdeleted',
    'supprime': 'isdeleted',
    'supprimé': 'isdeleted',
    'id': 'id',
    'identifiant': 'id',
  };

  /// Normalise un header en lowercase trimmed
  static String normalizeHeader(String header) =>
      header.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Parse un fichier CSV et extrait les données
  static Future<List<List<dynamic>>> parseCsvFile(File file) async {
    final bytes = await file.readAsBytes();
    var decoded = const Utf8Decoder(allowMalformed: true).convert(bytes);
    if (decoded.startsWith('\uFEFF')) decoded = decoded.substring(1);
    final sep = detectSeparator(decoded);
    return CsvToListConverter(
      fieldDelimiter: sep,
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(decoded);
  }

  /// Détecte le séparateur le plus probable parmi `;`, `,`, tab.
  static String detectSeparator(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .take(10)
        .toList();
    if (lines.isEmpty) return ',';
    String best = ',';
    var bestScore = -1;
    for (final sep in [';', '\t', ',']) {
      var score = 0;
      var consistent = true;
      int? cols;
      for (final l in lines) {
        final c = _countSep(l, sep);
        score += c;
        if (cols == null) {
          cols = c;
        } else if (c != cols && c > 0) {
          consistent = false;
        }
      }
      if (!consistent) score = (score * 0.8).round();
      if (score > bestScore) {
        bestScore = score;
        best = sep;
      }
    }
    return best;
  }

  static int _countSep(String line, String sep) {
    var count = 0;
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && ch == sep) {
        count++;
      }
    }
    return count;
  }

  /// Détecte le type de colonne (compat)
  static String? detectColumnType(String header, List<List<dynamic>> rows) {
    final norm = normalizeHeader(header);
    if (csvHeaderMap.containsKey(norm)) return csvHeaderMap[norm];
    if (rows.isNotEmpty) {
      for (final row in rows.take(5)) {
        for (final value in row) {
          if (value == null) continue;
          final s = value.toString().trim();
          if (RegExp(r'[-(]?\d[\d\s,.]*€?\)?$').hasMatch(s) &&
              RegExp(r'\d').hasMatch(s)) {
            return 'amount';
          }
          if (parseFrenchDate(s) != null || _parseIsoDate(s) != null) {
            return 'date';
          }
        }
      }
    }
    return null;
  }

  /// Convertit un montant en centimes entiers (jamais de calcul float métier).
  static int parseAmountToCents(dynamic value) {
    if (value == null) return 0;
    var s = value.toString().trim();
    if (s.isEmpty) return 0;
    var negative = false;
    if (s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    }
    if (s.startsWith('+')) s = s.substring(1);
    s = s
        .replaceAll('€', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(' ', '')
        .trim();
    if (s.isEmpty) return 0;

    // Déterminer séparateur décimal
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    String intPart;
    String decPart = '';
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        // 1.234,56
        intPart = s
            .substring(0, lastComma)
            .replaceAll('.', '')
            .replaceAll(',', '');
        decPart = s.substring(lastComma + 1);
      } else {
        // 1,234.56
        intPart = s
            .substring(0, lastDot)
            .replaceAll(',', '')
            .replaceAll('.', '');
        decPart = s.substring(lastDot + 1);
      }
    } else if (lastComma >= 0) {
      final digitsAfter = s.length - lastComma - 1;
      if (digitsAfter == 0 || digitsAfter == 1 || digitsAfter == 2) {
        intPart = s
            .substring(0, lastComma)
            .replaceAll('.', '')
            .replaceAll(',', '');
        decPart = s.substring(lastComma + 1);
      } else {
        intPart = s.replaceAll(',', '');
      }
    } else if (lastDot >= 0) {
      final digitsAfter = s.length - lastDot - 1;
      if (digitsAfter == 0 || digitsAfter == 1 || digitsAfter == 2) {
        intPart = s
            .substring(0, lastDot)
            .replaceAll(',', '')
            .replaceAll('.', '');
        decPart = s.substring(lastDot + 1);
      } else {
        intPart = s.replaceAll('.', '');
      }
    } else {
      intPart = s;
    }

    intPart = intPart.replaceAll(RegExp(r'[^\d]'), '');
    decPart = decPart.replaceAll(RegExp(r'[^\d]'), '');
    if (intPart.isEmpty) intPart = '0';
    if (decPart.length == 1) decPart = '${decPart}0';
    if (decPart.length > 2) decPart = decPart.substring(0, 2);
    if (decPart.isEmpty) decPart = '00';

    final cents = int.tryParse(intPart + decPart) ?? 0;
    return negative ? -cents : cents;
  }

  /// Parse une date FR/internationale courante.
  static DateTime? parseFrenchDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;

    final iso = _parseIsoDate(s);
    if (iso != null) return iso;

    final match = RegExp(r'^(\d{1,2})[/\.\-](\d{1,2})[/\.\-](\d{2,4})$')
        .firstMatch(s);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      var y = int.parse(match.group(3)!);
      if (y < 100) y += (y >= 70 ? 1900 : 2000);
      try {
        final dt = DateTime(y, m, d);
        if (dt.year == y && dt.month == m && dt.day == d) return dt;
      } catch (_) {}
      return null;
    }

    final ymd = RegExp(r'^(\d{4})[/\.\-](\d{1,2})[/\.\-](\d{1,2})$')
        .firstMatch(s);
    if (ymd != null) {
      final y = int.parse(ymd.group(1)!);
      final m = int.parse(ymd.group(2)!);
      final d = int.parse(ymd.group(3)!);
      try {
        final dt = DateTime(y, m, d);
        if (dt.year == y && dt.month == m && dt.day == d) return dt;
      } catch (_) {}
    }

    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseIsoDate(String s) {
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (iso == null) return null;
    try {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    } catch (_) {
      return null;
    }
  }

  /// Analyse complète d'un CSV (pipeline unique).
  static ImportAnalysis analyzeCsv(
    String csvText, {
    CsvColumnMapping? mappingOverride,
    Set<String> existingFingerprints = const {},
    Map<String, String> existingIds = const {}, // id -> fingerprint
  }) {
    var text = csvText;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    // Normalise les fins de ligne : évite qu'allowInvalid (csv 6.x) fusionne
    // les lignes avec le eol par défaut.
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final separator = detectSeparator(text);
    var table = CsvToListConverter(
      fieldDelimiter: separator,
      shouldParseNumbers: false,
      allowInvalid: true,
      eol: '\n',
    ).convert(text);
    // Fallback défensif si le parse retourne une seule ligne alors que le texte
    // en contient plusieurs.
    if (table.length <= 1 && text.contains('\n')) {
      try {
        table = CsvToListConverter(
          fieldDelimiter: separator,
          shouldParseNumbers: false,
          eol: '\n',
        ).convert(text);
      } catch (_) {}
    }

    if (table.isEmpty) {
      return ImportAnalysis(
        separator: separator,
        hasHeader: false,
        headers: const [],
        mapping: const CsvColumnMapping(),
        rows: const [],
        report: ImportReport(totalRows: 0),
      );
    }

    // Détecter en-tête
    final first = table.first.map((e) => e?.toString() ?? '').toList();
    final firstNorm = first.map(normalizeHeader).toList();
    final hasHeader =
        firstNorm.any((h) => csvHeaderMap.containsKey(h)) ||
        _looksLikeHeader(first);

    final headers = hasHeader ? firstNorm : <String>[];
    final dataRows = hasHeader ? table.skip(1).toList() : table;

    final mapping = mappingOverride ?? detectMapping(headers, dataRows);

    return _remapRows(
      rawRows: dataRows,
      headers: headers,
      mapping: mapping,
      hasHeader: hasHeader,
      separator: separator,
      existingFingerprints: existingFingerprints,
      existingIds: existingIds,
    );
  }

  static bool _looksLikeHeader(List<String> row) {
    if (row.isEmpty) return false;
    var nonNumeric = 0;
    for (final c in row) {
      final s = c.trim();
      if (s.isEmpty) continue;
      if (double.tryParse(s.replaceAll(',', '.')) == null &&
          parseFrenchDate(s) == null) {
        nonNumeric++;
      }
    }
    return nonNumeric >= (row.length / 2).ceil();
  }

  static CsvColumnMapping detectMapping(
    List<String> headers,
    List<List<dynamic>> dataRows,
  ) {
    var m = const CsvColumnMapping();
    for (var i = 0; i < headers.length; i++) {
      final field = csvHeaderMap[normalizeHeader(headers[i])];
      if (field == null) continue;
      m = _applyField(m, field, i);
    }
    // Fallbacks heuristiques si champs critiques absents
    if (headers.isEmpty && dataRows.isNotEmpty) {
      final row = dataRows.first;
      for (var i = 0; i < row.length; i++) {
        final v = row[i]?.toString().trim() ?? '';
        if (m.dateIndex < 0 && parseFrenchDate(v) != null) {
          m = m.copyWith(dateIndex: i);
        } else if (m.amountIndex < 0 &&
            m.debitIndex < 0 &&
            RegExp(r'^[-+(]?\d').hasMatch(v)) {
          m = m.copyWith(amountIndex: i);
        } else if (m.labelIndex < 0 &&
            v.isNotEmpty &&
            parseFrenchDate(v) == null) {
          m = m.copyWith(labelIndex: i);
        }
      }
    }
    return m;
  }

  static CsvColumnMapping _applyField(CsvColumnMapping m, String field, int i) {
    switch (field) {
      case 'date':
        return m.dateIndex < 0 ? m.copyWith(dateIndex: i) : m;
      case 'label':
        return m.labelIndex < 0 ? m.copyWith(labelIndex: i) : m;
      case 'amount':
        return m.amountIndex < 0 ? m.copyWith(amountIndex: i) : m;
      case 'debit':
      case 'spent':
        return m.debitIndex < 0 ? m.copyWith(debitIndex: i) : m;
      case 'credit':
        return m.creditIndex < 0 ? m.copyWith(creditIndex: i) : m;
      case 'category':
        return m.categoryIndex < 0 ? m.copyWith(categoryIndex: i) : m;
      case 'id':
        return m.idIndex < 0 ? m.copyWith(idIndex: i) : m;
      case 'type':
        return m.typeIndex < 0 ? m.copyWith(typeIndex: i) : m;
      case 'isdeleted':
        return m.isDeletedIndex < 0 ? m.copyWith(isDeletedIndex: i) : m;
      case 'notes':
        return m.notesIndex < 0 ? m.copyWith(notesIndex: i) : m;
      default:
        return m;
    }
  }

  static ImportAnalysis _remapRows({
    required List<List<dynamic>> rawRows,
    required List<String> headers,
    required CsvColumnMapping mapping,
    required bool hasHeader,
    required String separator,
    Set<String> existingFingerprints = const {},
    Map<String, String> existingIds = const {},
  }) {
    final results = <ImportRowResult>[];
    final seenFingerprints = <String>{...existingFingerprints};
    final years = <int>{};
    var ready = 0, errors = 0, dups = 0, updates = 0;

    for (var i = 0; i < rawRows.length; i++) {
      final row = rawRows[i];
      final rowIndex = (hasHeader ? i + 2 : i + 1);
      if (_isRowEmpty(row)) continue;

      final res = _parseRow(
        row: row,
        rowIndex: rowIndex,
        mapping: mapping,
        existingIds: existingIds,
        seenFingerprints: seenFingerprints,
      );
      results.add(res);
      if (res.status == ImportRowStatus.error) errors++;
      if (res.status == ImportRowStatus.duplicateProbable) {
        dups++;
        if (res.prepared != null) ready++; // incluable
      }
      if (res.status == ImportRowStatus.updateById) {
        updates++;
        ready++;
      }
      if (res.status == ImportRowStatus.ready) ready++;
      if (res.prepared != null) years.add(res.prepared!.date.year);
    }

    return ImportAnalysis(
      separator: separator,
      hasHeader: hasHeader,
      headers: headers,
      mapping: mapping,
      rows: results,
      report: ImportReport(
        totalRows: results.length,
        ready: ready,
        duplicateProbable: dups,
        updatesById: updates,
        errors: errors,
        isPartial: errors > 0,
        yearsImported: years.toList()..sort(),
      ),
    );
  }

  static bool _isRowEmpty(List<dynamic> row) {
    return row.every((c) => c == null || c.toString().trim().isEmpty);
  }

  static ImportRowResult _parseRow({
    required List<dynamic> row,
    required int rowIndex,
    required CsvColumnMapping mapping,
    required Map<String, String> existingIds,
    required Set<String> seenFingerprints,
  }) {
    final errs = <String>[];
    String? cell(int idx) {
      if (idx < 0 || idx >= row.length) return null;
      final v = row[idx]?.toString();
      return v;
    }

    // Date
    DateTime? date;
    final dateRaw = cell(mapping.dateIndex);
    if (dateRaw != null && dateRaw.trim().isNotEmpty) {
      date = parseFrenchDate(dateRaw);
      if (date == null) errs.add('Date invalide: "$dateRaw"');
    } else if (mapping.dateIndex >= 0) {
      errs.add('Date manquante');
    } else {
      // fallback: date du jour si non mappée (import bancaire souple) mais signalé
      date = DateTime.now();
      errs.add('Colonne date non mappée (date du jour appliquée)');
    }

    // Type explicite (canonique) — pré-calcul pour l'inférence montant
    final typeRaw = cell(mapping.typeIndex)?.trim().toLowerCase();
    var hasExplicitType = false;
    TransactionType? explicitType;
    if (typeRaw != null && typeRaw.isNotEmpty) {
      hasExplicitType = true;
      switch (typeRaw) {
        case 'income':
        case 'revenu':
          explicitType = TransactionType.income;
          break;
        case 'expense':
        case 'depense':
        case 'dépense':
          explicitType = TransactionType.expense;
          break;
        case 'transfer':
        case 'virement':
          explicitType = TransactionType.transfer;
          break;
        default:
          errs.add('Type invalide: "$typeRaw"');
      }
    }

    // Montant (centimes signés)
    int? amountCents;
    TransactionType type = explicitType ?? TransactionType.expense;
    final hasDebitCredit = mapping.debitIndex >= 0 || mapping.creditIndex >= 0;
    if (hasDebitCredit) {
      final debitRaw = cell(mapping.debitIndex);
      final creditRaw = cell(mapping.creditIndex);
      final debitCents = (debitRaw != null && debitRaw.trim().isNotEmpty)
          ? parseAmountToCents(debitRaw).abs()
          : 0;
      final creditCents = (creditRaw != null && creditRaw.trim().isNotEmpty)
          ? parseAmountToCents(creditRaw).abs()
          : 0;
      final debitFilled =
          debitRaw != null && debitRaw.trim().isNotEmpty && debitCents != 0;
      final creditFilled =
          creditRaw != null && creditRaw.trim().isNotEmpty && creditCents != 0;
      if (debitFilled && creditFilled) {
        errs.add('Ambiguïté: débit et crédit renseignés simultanément');
      } else {
        amountCents = creditCents - debitCents;
        if (creditCents > 0) type = TransactionType.income;
        if (debitCents > 0) type = TransactionType.expense;
      }
    } else {
      final amtRaw = cell(mapping.amountIndex);
      if (amtRaw != null && amtRaw.trim().isNotEmpty) {
        final trimmed = amtRaw.trim();
        final looksNumeric =
            RegExp(r'[-+]?\d').hasMatch(trimmed) &&
            RegExp(r'^[\s\-+()0-9.,€\u00A0]+$').hasMatch(trimmed);
        if (!looksNumeric) {
          errs.add('Montant invalide: "$amtRaw"');
        } else {
          amountCents = parseAmountToCents(amtRaw);
          if (!hasExplicitType) {
            type = amountCents < 0
                ? TransactionType.expense
                : (amountCents > 0
                      ? TransactionType.income
                      : TransactionType.expense);
          }
        }
      } else if (mapping.amountIndex >= 0) {
        errs.add('Montant manquant');
      } else {
        errs.add('Colonne montant/débit/crédit non mappée');
      }
    }

    // type explicite déjà appliqué (pré-calcul)

    final labelRaw = cell(mapping.labelIndex)?.trim() ?? '';
    final categoryRaw = cell(mapping.categoryIndex)?.trim() ?? '';
    final notesRaw = cell(mapping.notesIndex)?.trim() ?? '';
    final isDeletedRaw = cell(mapping.isDeletedIndex)?.trim() ?? '0';
    final isDeleted =
        isDeletedRaw == '1' || isDeletedRaw.toLowerCase() == 'true';

    if (errs.any(
      (e) =>
          e.startsWith('Date invalide') ||
          e.startsWith('Date manquante') ||
          e.startsWith('Montant manquant') ||
          e.startsWith('Montant invalide') ||
          e.startsWith('Type invalide') ||
          e.contains('non mappée') ||
          e.startsWith('Ambiguïté'),
    )) {
      return ImportRowResult(
        rowIndex: rowIndex,
        rawRow: row,
        status: ImportRowStatus.error,
        prepared: null,
        errors: errs,
        duplicateOf: null,
        canInclude: false,
      );
    }

    date ??= DateTime.now();
    amountCents ??= 0;
    final category = categoryRaw.isNotEmpty ? categoryRaw : 'Autre';
    final description = labelRaw.isNotEmpty ? labelRaw : 'Ligne $rowIndex';

    final dateIso =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final normLabel = _normalizeForFp(description);
    final normCat = mapping.categoryIndex >= 0 ? _normalizeForFp(category) : '';
    final fingerprint = 'fp|$dateIso|$amountCents|$normLabel|$normCat';

    final explicitId = cell(mapping.idIndex)?.trim() ?? '';
    final canonicalFormat = mapping.idIndex >= 0 && mapping.typeIndex >= 0;

    String id;
    ImportRowStatus status = ImportRowStatus.ready;
    bool canonicalIdUpdate = false;
    String? duplicateOf;

    if (canonicalFormat && explicitId.isNotEmpty) {
      id = explicitId;
      if (existingIds.containsKey(id)) {
        status = ImportRowStatus.updateById;
        canonicalIdUpdate = true;
        duplicateOf = 'id:$id';
      }
      // ID explicite: MAJ si connu (commit vérifie portée userId), sinon insertion
      // sûre avec cet ID (aucun remplacement d'une autre transaction).
    } else if (explicitId.isNotEmpty) {
      id = explicitId;
    } else {
      // ID déterministe (contenu + index)
      id = _deterministicId(fingerprint, rowIndex);
    }

    // Détection doublon probable (empreinte), même si updateById? updateById prime.
    if (status == ImportRowStatus.ready &&
        seenFingerprints.contains(fingerprint)) {
      status = ImportRowStatus.duplicateProbable;
      duplicateOf = 'empreinte';
      // Doublon volontairement inclus => nouvel ID unique sans écraser
      id = _deterministicId(fingerprint, rowIndex, salt: 'dup');
    } else if (status == ImportRowStatus.ready) {
      seenFingerprints.add(fingerprint);
    } else if (status == ImportRowStatus.updateById) {
      seenFingerprints.add(fingerprint);
    }

    final preserveSigned =
        hasExplicitType || (mapping.amountIndex >= 0 && mapping.idIndex >= 0);
    final prepared = PreparedTransaction(
      id: id,
      amountCentsSigned: amountCents,
      category: category,
      description: description,
      date: date,
      type: type,
      notes: notesRaw,
      isDeleted: isDeleted,
      canonicalIdUpdate: canonicalIdUpdate,
      preserveSignedAmount: preserveSigned,
      fingerprint: fingerprint,
    );

    return ImportRowResult(
      rowIndex: rowIndex,
      rawRow: row,
      status: status,
      prepared: prepared,
      errors: errs,
      duplicateOf: duplicateOf,
      canInclude: status != ImportRowStatus.error,
    );
  }

  static String _normalizeForFp(String s) {
    return s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _deterministicId(String fp, int rowIndex, {String salt = ''}) {
    final bytes = utf8.encode('$fp|$rowIndex|$salt');
    final h = sha256.convert(bytes).toString().substring(0, 24);
    return 'imp_$h';
  }

  /// Crée une transaction à partir d'une ligne CSV (compat tests existants).
  static Transaction csvToTransaction(
    List<dynamic> row,
    List<String> headers,
    int rowIndex,
  ) {
    final norm = headers.map(normalizeHeader).toList();
    final labelIdx = _findAny(norm, const [
      'libellé',
      'libelle',
      'label',
      'description',
    ]);
    final amountIdx = _findAny(norm, const ['montant', 'amount']);
    final dateIdx = _findAny(norm, const ['date']);
    final categoryIdx = _findAny(norm, const [
      'catégorie',
      'categorie',
      'category',
    ]);

    final label = labelIdx >= 0 && row.length > labelIdx
        ? row[labelIdx].toString()
        : '';

    int amountCents = 0;
    if (amountIdx >= 0 && row.length > amountIdx) {
      amountCents = parseAmountToCents(row[amountIdx]);
    }

    DateTime? bookingDate;
    if (dateIdx >= 0 && row.length > dateIdx) {
      bookingDate = parseFrenchDate(row[dateIdx]) ?? DateTime.now();
    } else {
      bookingDate = DateTime.now();
    }

    String category = 'Non classée';
    if (categoryIdx >= 0 && row.length > categoryIdx) {
      final cat = row[categoryIdx].toString().trim();
      if (cat.isNotEmpty) category = cat;
    }

    final isNegative = amountCents < 0;
    final type = isNegative ? TransactionType.expense : TransactionType.income;
    final absAmount = (amountCents.abs()) / 100.0;

    final id =
        'import_${bookingDate.year}${bookingDate.month}${bookingDate.day}_${rowIndex}_${amountCents.abs()}';

    return Transaction(
      id: id,
      amount: absAmount,
      category: category,
      description: label.isNotEmpty ? label : 'Ligne ${rowIndex + 1}',
      date: bookingDate,
      type: type,
      isDeleted: false,
    );
  }

  static int _findAny(List<String> normHeaders, List<String> candidates) {
    for (final c in candidates) {
      final i = normHeaders.indexOf(c);
      if (i >= 0) return i;
    }
    return -1;
  }

  /// Calcule l'empreinte d'une transaction existante (2C).
  static String fingerprintFor({
    required DateTime date,
    required double amountEuros,
    required String description,
    String? category,
    bool includeCategory = false,
  }) {
    final cents = (amountEuros * 100).round();
    final dateIso =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final normLabel = _normalizeForFp(description);
    final normCat = includeCategory && category != null
        ? _normalizeForFp(category)
        : '';
    return 'fp|$dateIso|$cents|$normLabel|$normCat';
  }
}
