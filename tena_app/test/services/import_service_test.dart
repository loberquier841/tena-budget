import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportService', () {
    test('parse CSV avec en-têtes standard', () async {
      const result = [
        ['libellé', 'montant', 'date', 'catégorie'],
        ['Courses', '12,50', '15/01/2026', 'Alimentation'],
        ['Salaire', '2500', '01/01/2026', 'Revenu'],
      ];
      
      expect(result.length, 3);
      expect(result.first, ['libellé', 'montant', 'date', 'catégorie']);
    });

    test('détection de colonne montant', () {
      final headers = ['Date', 'Libellé', 'Montant'];
      final normalized = headers.map(ImportService.normalizeHeader);
      
      expect(normalized.contains('montant'), isTrue);
    });

    test('parse montant 12,50€ en centimes', () {
      final cents = ImportService.parseAmountToCents('12,50 €');
      expect(cents, 1250);
    });

    test('parse montant négatif en centimes', () {
      final cents = ImportService.parseAmountToCents('-45,99 €');
      expect(cents, -4599);
    });

    test('parse date française JJ/MM/AAAA', () {
      final dt = ImportService.parseFrenchDate('15/01/2026');
      expect(dt, isNotNull);
      expect(dt!.day, 15);
      expect(dt.month, 1);
      expect(dt.year, 2026);
    });

    test('CSV to Transaction conversion', () {
      final headers = ['libellé', 'montant', 'date', 'catégorie'];
      final row = ['Courses', '-12,50', '15/01/2026', 'Alimentation'];
      
      final tx = ImportService.csvToTransaction(row, headers, 0);
      expect(tx.description, 'Courses');
      expect(tx.amount, 12.50);
      expect(tx.category, 'Alimentation');
    });

    test('mapping des headers CSV', () {
      expect(ImportService.csvHeaderMap['categorie'], 'category');
      expect(ImportService.csvHeaderMap['montant'], 'amount');
      expect(ImportService.csvHeaderMap['date'], 'date');
      expect(ImportService.csvHeaderMap['libellé'], 'label');
      expect(ImportService.csvHeaderMap['personne'], 'person');
      expect(ImportService.csvHeaderMap['objectif'], 'goal');
    });
  });
}
