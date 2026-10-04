import '../models/transaction.dart';

class ForecastResult {
  final double averageMonthlyExpenses;
  final double averageMonthlyIncome;
  final double estimatedNextMonthExpenses;
  final double estimatedNextMonthIncome;
  final double estimatedBalance;

  const ForecastResult({
    required this.averageMonthlyExpenses,
    required this.averageMonthlyIncome,
    required this.estimatedNextMonthExpenses,
    required this.estimatedNextMonthIncome,
    required this.estimatedBalance,
  });
}

class ForecastService {
  static ForecastResult calculate(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const ForecastResult(
        averageMonthlyExpenses: 0,
        averageMonthlyIncome: 0,
        estimatedNextMonthExpenses: 0,
        estimatedNextMonthIncome: 0,
        estimatedBalance: 0,
      );
    }

    final months = <String>{};

    for (final transaction in transactions) {
      // Clé zero-padrée : sans elle, janvier (`1`) et novembre (`11`)
      // produiraient la même chaîne et seraient comptés pour un seul mois,
      // ce qui gonflerait artificiellement la moyenne mensuelle.
      final month = transaction.date.month.toString().padLeft(2, '0');

      months.add('${transaction.date.year}-$month');
    }

    final monthCount = months.isEmpty ? 1 : months.length;

    double totalExpenses = 0;
    double totalIncome = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        totalExpenses += transaction.amount;
      } else {
        totalIncome += transaction.amount;
      }
    }

    final averageExpenses = totalExpenses / monthCount;
    final averageIncome = totalIncome / monthCount;

    return ForecastResult(
      averageMonthlyExpenses: averageExpenses,
      averageMonthlyIncome: averageIncome,
      estimatedNextMonthExpenses: averageExpenses,
      estimatedNextMonthIncome: averageIncome,
      estimatedBalance: averageIncome - averageExpenses,
    );
  }
}
