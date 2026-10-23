import '../models/finance_summary.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class FinanceService {
  static Future<List<Transaction>> getTransactions() {
    return DatabaseService.instance.getTransactions();
  }

  static Future<FinanceSummary> getSummaryForMonth(
    DateTime month,
  ) async {
    final transactions = await getTransactions();

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

  static Future<FinanceSummary> getSummary() async {
    final transactions = await getTransactions();

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
