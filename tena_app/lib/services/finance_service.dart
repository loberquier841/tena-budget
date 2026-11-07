import '../models/finance_summary.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class FinanceService {
  static Future<List<Transaction>> getTransactions({String userId = 'primary'}) {
    return DatabaseService.instance.getTransactions(userId: userId);
  }

  static Future<FinanceSummary> getSummaryForMonth(
    DateTime month, {
    String userId = 'primary',
  }) async {
    final transactions = await getTransactions(userId: userId);

    final monthTransactions = transactions.where((transaction) {
      return transaction.date.year == month.year &&
          transaction.date.month == month.month;
    }).toList();

    double income = 0;
    double expenses = 0;

    for (final transaction in monthTransactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        expenses += transaction.amount;
      }
      // TransactionType.transfer is excluded from both income and expenses
    }

    return FinanceSummary(
      balance: income - expenses,
      income: income,
      expenses: expenses,
      recentTransactions: monthTransactions.take(5).toList(),
      allTransactions: monthTransactions,
    );
  }

  static Future<FinanceSummary> getSummaryForRange(
    DateTime start,
    DateTime end, {
    String userId = 'primary',
  }) async {
    final transactions = await getTransactions(userId: userId);

    final rangeTransactions = transactions.where((transaction) {
      return !transaction.date.isBefore(start) &&
          transaction.date.isBefore(end);
    }).toList();

    double income = 0;
    double expenses = 0;

    for (final transaction in rangeTransactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        expenses += transaction.amount;
      }
    }

    return FinanceSummary(
      balance: income - expenses,
      income: income,
      expenses: expenses,
      recentTransactions: rangeTransactions.take(5).toList(),
      allTransactions: rangeTransactions,
    );
  }

  static Future<FinanceSummary> getSummary({String userId = 'primary'}) async {
    final transactions = await getTransactions(userId: userId);

    double income = 0;
    double expenses = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        expenses += transaction.amount;
      }
      // TransactionType.transfer is excluded from both income and expenses
    }

    return FinanceSummary(
      balance: income - expenses,
      income: income,
      expenses: expenses,
      recentTransactions: transactions.take(5).toList(),
      allTransactions: transactions,
    );
  }
}
