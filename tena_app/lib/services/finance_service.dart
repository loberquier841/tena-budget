import '../models/finance_summary.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'package:tena_budget/services/notification_service_secure.dart';

class FinanceService {
  static Future<List<Transaction>> getTransactions() {
    return DatabaseService.instance.getTransactions();
  }

   static Future<FinanceSummary> getSummaryForMonth(
     DateTime month,
   ) async {
     final startDate = DateTime(month.year, month.month, 1);
     final endDate = month.month == 12
         ? DateTime(month.year + 1, 1, 1)
         : DateTime(month.year, month.month + 1, 1);
     final transactions = await DatabaseService.instance.getTransactions(
       startDate: startDate,
       endDate: endDate,
     );

     double income = 0;
     double expenses = 0;

     for (final transaction in transactions) {
       if (transaction.type == TransactionType.income) {
         income += transaction.amount;
       } else {
         expenses += transaction.amount;
       }
     }

     return FinanceSummary(
       balance: income - expenses,
       income: income,
       expenses: expenses,
       recentTransactions: transactions.take(5).toList(),
       allTransactions: transactions,
     );
   }
  static Future<FinanceSummary> getSummary() async {
    final transactions = await getTransactions();

    double income = 0;
    double expenses = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
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
