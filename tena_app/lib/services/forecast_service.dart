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
      months.add('${transaction.date.year}-${transaction.date.month}');
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
