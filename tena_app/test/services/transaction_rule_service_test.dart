import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/transaction.dart';
import '../../lib/services/transaction_rule_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Transaction tx(String label, {String category = 'Autres', TransactionType type = TransactionType.expense}) {
    return Transaction(
      id: '1',
      amount: 10,
      category: category,
      description: label,
      date: DateTime(2026, 1, 1),
      type: type,
    );
  }

  group('TransactionRuleService', () {
    test('suggests category from label', () {
      final svc = TransactionRuleService();
      expect(svc.suggestCategory(tx('Courses Carrefour')), 'Alimentation');
      expect(svc.suggestCategory(tx('Uber trajet')), 'Transport');
    });

    test('apply keeps existing non-default category', () {
      final svc = TransactionRuleService();
      final t = tx('Courses Carrefour', category: 'Loisirs');
      expect(svc.apply(t).category, 'Loisirs');
    });

    test('apply updates default/empty category', () {
      final svc = TransactionRuleService();
      final t = tx('Courses Carrefour', category: 'Autres');
      expect(svc.apply(t).category, 'Alimentation');
    });

    test('applyAll processes list', () {
      final svc = TransactionRuleService();
      final out = svc.applyAll([tx('Salaire janvier', type: TransactionType.income)]);
      expect(out.first.category, 'Salaire');
    });
  });
}
