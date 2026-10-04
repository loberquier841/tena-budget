import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/forecast_service.dart';

Transaction _transaction({
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
}) {
  return Transaction(
    id: '${date.toIso8601String()}-$amount-$type',
    amount: amount,
    category: 'Test',
    description: '',
    date: date,
    type: type,
  );
}

void main() {
  group('ForecastService', () {
    test('renvoie des zéros quand il n’y a aucune transaction', () {
      final result = ForecastService.calculate([]);

      expect(result.averageMonthlyExpenses, 0);
      expect(result.averageMonthlyIncome, 0);
      expect(result.estimatedNextMonthExpenses, 0);
      expect(result.estimatedNextMonthIncome, 0);
      expect(result.estimatedBalance, 0);
    });

    test('divise les totaux par le nombre de mois distincts', () {
      final result = ForecastService.calculate([
        _transaction(amount: 100, date: DateTime(2026, 1, 10)),
        _transaction(amount: 300, date: DateTime(2026, 2, 10)),
        _transaction(
          amount: 2000,
          date: DateTime(2026, 2, 20),
          type: TransactionType.income,
        ),
      ]);

      // 2 mois distincts : (100 + 300) / 2 = 200 de dépenses, 2000 / 2 = 1000
      expect(result.averageMonthlyExpenses, 200);
      expect(result.averageMonthlyIncome, 1000);
      expect(result.estimatedBalance, 800);
    });

    test('additionne les montants du même jour', () {
      final result = ForecastService.calculate([
        _transaction(amount: 10, date: DateTime(2026, 1, 10)),
        _transaction(amount: 15, date: DateTime(2026, 1, 10)),
      ]);

      expect(result.averageMonthlyExpenses, 25);
    });

    test('compte un mois par année distincte', () {
      final result = ForecastService.calculate([
        _transaction(amount: 120, date: DateTime(2025, 12, 31)),
        _transaction(amount: 480, date: DateTime(2026, 1, 1)),
      ]);

      expect(result.averageMonthlyExpenses, 300);
    });
  });
}
