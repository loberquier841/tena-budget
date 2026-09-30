import 'transaction.dart';

class FinanceSummary {
  final double balance;
  final double income;
  final double expenses;
  final List<Transaction> recentTransactions;
  final List<Transaction> allTransactions;

  const FinanceSummary({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.recentTransactions,
    required this.allTransactions,
  });
}
