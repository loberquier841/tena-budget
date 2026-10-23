import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';

/// Resultat d'un import CSV
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

  ImportReport({
    required this.imported,
    required this.ignored,
    required this.modified,
    required this.ambiguous,
    required this.duplicates,
    required this.errors,
    required this.isPartial,
    required this.yearsImported,
  });
}

/// État du pipeline d'import
enum ImportStep { selection, analysis, detection, preview, validation, completion }

/// Mappage des headers CSV vers les champs internes
final Map<String, String> _csvHeaderMap = {
  'categorie': 'category',
  'catégorie': 'category',
  'categories': 'category',
  'budget': 'budget',
  'budget annuel': 'budget',
  'prévu': 'budget',
  'dépense': 'amount',
  'depensé': 'spent',
  'dépensé': 'spent',
  'restant': 'remaining',
  'reste': 'remaining',
  'personne': 'person',
  'person': 'person',
  'qui': 'person',
  'date': 'date',
  'année': 'date',
  'montant': 'amount',
  'libellé': 'label',
  'libelle': 'label',
  'description': 'label',
  'objectif': 'goal',
  'économies': 'goal',
};

/// Normalise un header en lowercase trimmed
String _normalizeHeader(String header) => header.toLowerCase().trim();

/// Parse un fichier CSV et extrait les données
Future<CsvToListResult> _parseCsvFile(File file) async {
  final bytes = await file.readAsBytes();
  final utf8 = Utf8Decoder().convert(bytes);
  return const CsvConverter().convert(utf8);
}

/// Détecte le type de colonne basé sur l'en-tête et les valeurs d'échantillon
String? _detectColumnType(String header, List<List<dynamic>> rows) {
  final norm = _normalizeHeader(header);
  
  // Vérification directe du mappage
  if (_csvHeaderMap.containsKey(norm)) {
    return _csvHeaderMap[norm];
  }
  
  // Analyse du contenu si pas dans la liste mapping
  if (rows.isNotEmpty) {
    final firstRow = rows.first;
    if (firstRow.length > _csvHeaderMap.keys.first.length) {
      // Essayer de détecter par le contenu
      for (int i = 0; i < firstRow.length; i++) {
        final value = firstRow[i];
        if (value != null) {
          final s = value.toString().trim();
          // Montant en euros
          if (RegExp(r'[\d\s]+\s*€').hasMatch(s) || RegExp(r'[\d,]+\s*€').hasMatch(s)) {
            return 'amount';
          }
          // Date française
          if (RegExp(r'^\d{1,2}[/\.\-]\d{1,2}[/\.\-]\d{2,4}$').hasMatch(s)) {
            return 'date';
          }
        }
      }
    }
  }
  
  return null;
}

/// Convertit un montant en format EUR vers des centimes
int _parseAmountToCents(dynamic value) {
  if (value == null) return 0;
  final s = value.toString().trim();
  
  // Enlève le symbole € et les espaces
  s = s.replaceAll('€', '').replaceAll(' ', '');
  
  // Gère "4 000 €" ou "4000€" ou "4.000,50 €" ou "4000,50"
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  }
  
  s = s.replaceAll(RegExp(r'[^\d.-]'), '');
  
  try {
    final num = double.parse(s);
    return (num * 100).round();
  } catch (e) {
    return 0;
  }
}

/// Parse une date française
DateTime? _parseFrenchDate(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  
  // Format JJ/MM/AAAA ou JJ-MM-AAAA ou JJ.MM.AAAA
  final match = RegExp(r'^(\d{1,2})[/\.\-](\d{1,2})[/\.\-](\d{2,4})$').firstMatch(s);
  if (match != null) {
    final d = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!) - 1; // mois 0-indexé
    final y = int.parse(match.group(3)!);
    if (y < 100) y += 2000;
    
    try {
      return DateTime(y, m, d);
    } catch (e) {
      return null;
    }
  }
  
  // Essai format ISO
  try {
    return DateTime.parse(s);
  } catch (e) {
    return null;
  }
  
  return null;
}

/// Crée une transaction à partir d'une ligne CSV
Transaction _csvToTransaction(List<dynamic> row, List<String> headers, int rowIndex) {
  // Trouver les indices des champs nécessaires
  final labelIdx = headers.indexOf('libellé');
  final amountIdx = headers.indexOf('montant');
  final dateIdx = headers.indexOf('date');
  final categoryIdx = headers.indexOf('catégorie');
  final personIdx = headers.indexOf('personne');
  
  // Label (déscription)
  final label = labelIdx >= 0 && row.length > labelIdx ? row[labelIdx].toString() : '';
  
  // Montant en centimes
  int amountCents = 0;
  if (amountIdx >= 0 && row.length > amountIdx) {
    amountCents = _parseAmountToCents(row[amountIdx]);
  }
  
  // Date
  DateTime? bookingDate;
  if (dateIdx >= 0 && row.length > dateIdx) {
    bookingDate = _parseFrenchDate(row[dateIdx]);
    if (bookingDate == null) {
      // Fallback à la date actuelle
      bookingDate = DateTime.now();
    }
  } else {
    bookingDate = DateTime.now();
  }
  
  // Catégorie
  String category = '';
  if (categoryIdx >= 0 && row.length > categoryIdx) {
    category = row[categoryIdx].toString();
  }
  
  // Personne (optionnel)
  String? person;
  if (personIdx >= 0 && row.length > personIdx) {
    final p = row[personIdx].toString();
    if (p.isNotEmpty) person = p;
  }
  
  // Type par défaut : dépense
  final TransactionType type = TransactionType.expense;
  
  // Générer un ID unique
  final id = '${bookingDate.year}-${bookingDate.month}-${bookingDate.day}-$rowIndex-${amountCents}';
  
  return Transaction(
    id: id,
    amount: amountCents / 100,
    category: category.isNotEmpty ? category : 'Non classée',
    description: label.isNotEmpty ? label : 'Ligne ${rowIndex + 1}',
    date: bookingDate,
    type: type,
    isDeleted: false,
  );
}
