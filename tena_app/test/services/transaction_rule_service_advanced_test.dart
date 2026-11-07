import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/transaction.dart';
import '../../lib/services/transaction_rule_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Transaction tx(String label, {String category = 'Autres', TransactionType type = TransactionType.expense, double amount = 10, DateTime? date}) {
    return Transaction(
      id: '1',
      amount: amount,
      category: category,
      description: label,
      date: date ?? DateTime(2026, 1, 1),
      type: type,
    );
  }

  group('TransactionRuleService advanced', () {
    test('priority ordering resolves conflict', () {
      final svc = TransactionRuleService(rules: [
        const TransactionRule(keywords: ['uber'], category: 'Transport', priority: 5),
        const TransactionRule(keywords: ['uber'], category: 'Loisirs', priority: 20),
      ]);
      expect(svc.suggestCategory(tx('Uber trajet')), 'Loisirs');
    });

    test('normalizeMerchant strips bank noise', () {
      expect(TransactionRuleService.normalizeMerchant('CB *CARREFOUR 15/01'), contains('carrefour'));
    });

    test('explain returns matched keyword', () {
      final svc = TransactionRuleService();
      final r = svc.explain(tx('Courses Carrefour'));
      expect(r.category, 'Alimentation');
      expect(r.matchedKeyword, isNotNull);
    });

    test('preserve manual category', () {
      final svc = TransactionRuleService();
      final t = tx('Courses Carrefour', category: 'Manuel');
      expect(svc.apply(t).category, 'Manuel');
    });

    test('learnFromCorrection creates high priority rule', () {
      final rule = TransactionRuleService.learnFromCorrection(tx('Uber trajet'), 'Transport Pro');
      expect(rule.priority, 100);
      expect(rule.userDefined, isTrue);
    });

    test('detectRecurring finds repeated', () {
      final txs = [
        tx('Netflix 15/01', amount: 12.99, date: DateTime(2026, 1, 15)),
        tx('Netflix 15/02', amount: 12.99, date: DateTime(2026, 2, 15)),
      ];
      final groups = TransactionRuleService.detectRecurring(txs);
      expect(groups.length, 1);
    });
  });
}
