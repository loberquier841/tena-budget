enum TransactionType {
  income,
  expense,
  transfer,
}

class Transaction {
  final String id;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final TransactionType type;

  /// Note libre associée à la transaction (facture, référence, commentaire).
  final String notes;

  /// Suppression logique : la ligne est conservée en base afin qu'aucune
  /// donnée financière ne soit définitivement perdue.
  final bool isDeleted;

  const Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    required this.type,
    this.notes = '',
    this.isDeleted = false,
  });

  Transaction copyWith({
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    TransactionType? type,
    String? notes,
    bool? isDeleted,
  }) {
    return Transaction(
      id: id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
