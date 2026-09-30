enum TransactionType {
  income,
  expense,
}

class Transaction {
  final String id;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final TransactionType type;

  const Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.type,
  });
}
