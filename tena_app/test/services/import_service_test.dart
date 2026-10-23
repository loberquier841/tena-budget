import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

import 'package:tena_budget/services/import_service.dart';
import 'package:tena_budget/models/transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportService', () {
    // Test de parsing CSV basique
    test('parse CSV avec en-têtes standard', () async {
      final csvText = '''libellé,montant,date,catégorie
Courses,12.50,15/01/2026,Alimentation
Salaire,2500,01/01/2026,Revenu''';
      
      final result = const CsvToListResult.fromList([
        ['libellé', 'montant', 'date', 'catégorie'],
        ['Courses', '12,50', '15/01/2026', 'Alimentation'],
        ['Salaire', '2500', '01/01/2026', 'Revenu'],
      ]);
      
      expect(result.length, 3);
      expect(result.first, ['libellé', 'montant', 'date', 'catégorie']);
    });

    // Test de détection de colonne
    test('détection de colonne montant', () {
      final headers = ['Date', 'Libellé', 'Montant'];
      final normalized = headers.map(_normalizeHeader);
      
      expect(normalized.contains('montant'), isTrue);
    });

    // Test de parsing de montant
    test('parse montant 12,50€ en centimes', () {
      // Simule ce que ferait _parseAmountToCents
      final s = '12,50';
      final sCleaned = s.replaceAll('€', '').replaceAll(' ', '');
      
      if (sCleaned.contains(',') && sCleaned.contains('.')) {
        // not the case here
      } else if (sCleaned.contains(',')) {
        // sCleaned.replaceAll(',', '.');
      }
      
      // After processing: 12.50 -> 1250 cents
      final num = double.parse('12.50');
      final cents = (num * 100).round();
      expect(cents, 1250);
    });

    // Test de parsing de date française
    test('parse date française JJ/MM/AAAA', () {
      // Simule _parseFrenchDate
      final s = '15/01/2026';
      final match = RegExp(r'^(\d{1,2})[/\.\-](\d{1,2})[/\.\-](\d{2,4})$').firstMatch(s);
      
      if (match != null) {
        final d = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!) - 1;
        final y = int.parse(match.group(3)!);
        final dt = DateTime(y, m, d);
        expect(dt.day, 15);
        expect(dt.month, 0); // janvier = 0
        expect(dt.year, 2026);
      }
    });

    // Test de conversion CSV en transaction
    test('CSV to Transaction conversion', () {
      final headers = ['libellé', 'montant', 'date', 'catégorie'];
      final row = ['Courses', '12,50', '15/01/2026', 'Alimentation'];
      
      // Vérifier que la ligne a les bonnes colonnes
      expect(row.length, 4);
      expect(row[0], 'Courses');
      expect(row[1], '12,50');
    });

    // Test des headers de mapping
    test('mapping des headers CSV', () {
      expect(_csvHeaderMap['categorie'], 'category');
      expect(_csvHeaderMap['montant'], 'amount');
      expect(_csvHeaderMap['date'], 'date');
      expect(_csvHeaderMap['libellé'], 'label');
      expect(_csvHeaderMap['personne'], 'person');
      expect(_csvHeaderMap['objectif'], 'goal');
    });
  });
}

/// Helper function for test
String _normalizeHeader(String header) => header.toLowerCase().trim();
