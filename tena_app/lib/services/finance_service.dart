import '../models/finance_summary.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class FinanceService {
  static Future<List<Transaction>> getTransactions() async {
    try {
      return await DatabaseService.instance.getTransactions();
    } catch (e) {
      // Log the error and rethrow to let caller handle if needed
      print('Error fetching transactions: $e');
      rethrow;
    }
  }

  static FinanceSummary _computeSummary(List<Transaction> transactions) {
    // Sort by date descending to ensure most recent first
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    double income = 0;
    double expenses = 0;
    for (final transaction in sorted) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
    }

    final recent = sorted.take(5).toList();
    return FinanceSummary(
      balance: income - expenses,
      income: income,
      expenses: expenses,
      recentTransactions: recent,
      allTransactions: sorted,
    );
  }

  static Future<FinanceSummary> getSummaryForMonth(
    DateTime month,
  ) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = month.month == 12
          ? DateTime(month.year + 1, 1, 1)
          : DateTime(month.year, month.month + 1, 1);
      final transactions = await DatabaseService.instance.getTransactions(
        startDate: startDate,
        endDate: endDate,
      );
      return _computeSummary(transactions);
    } catch (e) {
      print('Error computing monthly summary: $e');
      // Return an empty summary to avoid breaking UI
      return const FinanceSummary(
        balance: 0,
        income: 0,
        expenses: 0,
        recentTransactions: [],
        allTransactions: [],
      );
    }
  }

  static Future<FinanceSummary> getSummary() async {
    try {
      final transactions = await getTransactions();
      return _computeSummary(transactions);
    } catch (e) {
      print('Error computing overall summary: $e');
      return const FinanceSummary(
        balance: 0,
        income: 0,
        expenses: 0,
        recentTransactions: [],
        allTransactions: [],
      );
    }
  }
}
