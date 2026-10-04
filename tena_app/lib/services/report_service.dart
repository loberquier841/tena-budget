import '../models/transaction.dart';

/// Dépenses agrégées pour une catégorie.
class CategoryTotal {
  final String category;
  final double total;

  /// Part de la catégorie dans le total des dépenses (0 à 1).
  final double share;

  const CategoryTotal({
    required this.category,
    required this.total,
    required this.share,
  });
}

/// Bilan chiffré d'une période, calculé à partir des transactions réelles.
class PeriodReport {
  final DateTime month;
  final double income;
  final double expenses;
  final double balance;

  /// Taux d'épargne : part du revenu qui n'a pas été dépensée.
  final double savingsRate;

  /// Dépense moyenne par jour calendaire écoulé dans le mois.
  final double averageDailyExpense;

  final List<CategoryTotal> topCategories;

  /// Nombre de mois de référence : comparer un mois partiel à un mois
  /// complet induirait en erreur l'utilisateur.
  final int comparedMonths;

  final double previousExpenses;
  final double previousIncome;

  const PeriodReport({
    required this.month,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.savingsRate,
    required this.averageDailyExpense,
    required this.topCategories,
    required this.comparedMonths,
    required this.previousExpenses,
    required this.previousIncome,
  });

  /// Variation des dépenses par rapport au mois précédent, en pourcentage.
  ///
  /// Vaut `null` si le mois précédent n'a aucune dépense : comparer avec zéro
  /// donnerait une division par zéro et un pourcentage sans signification.
  double? get expensesVariation {
    if (previousExpenses <= 0) return null;

    return (expenses - previousExpenses) / previousExpenses;
  }

  bool get hasEnoughHistory => comparedMonths >= 2;
}

/// Analyse des dépenses d'un mois et comparaison avec les mois précédents.
class ReportService {
  /// Calcule le bilan de [month] à partir des transactions fournies.
  ///
  /// [previousExpenses] et [previousIncome] sont fournis séparément car ils
  /// dépendent de l'historique, que cette méthode ne recharge pas.
  static PeriodReport build({
    required DateTime month,
    required List<Transaction> transactions,
    required double previousExpenses,
    required double previousIncome,
    required int comparedMonths,
  }) {
    final monthTransactions = transactions.where((t) {
      return t.date.year == month.year && t.date.month == month.month;
    }).toList();

    double income = 0;
    double expenses = 0;
    final byCategory = <String, double>{};

    for (final transaction in monthTransactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;

        byCategory.update(
          transaction.category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    // Le total par catégorie est ramené à une clé connue pour éviter que la
    // division ne dépende de l'ordre de parcours de la map.
    final safeExpenses = expenses == 0 ? 1.0 : expenses;

    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories
        .map(
          (entry) => CategoryTotal(
            category: entry.key,
            total: entry.value,
            share: entry.value / safeExpenses,
          ),
        )
        .toList();

    return PeriodReport(
      month: month,
      income: income,
      expenses: expenses,
      balance: income - expenses,
      savingsRate: income > 0 ? (income - expenses) / income : 0,
      averageDailyExpense: _dailyAverage(expenses, month),
      topCategories: topCategories,
      comparedMonths: comparedMonths,
      previousExpenses: previousExpenses,
      previousIncome: previousIncome,
    );
  }

  /// Moyenne quotidienne sur les seuls jours écoulés du mois.
  ///
  /// Diviser par le nombre de jours du mois sous-estimerait le rythme de
  /// dépense en cours de mois : le 3 du mois, on n'a dépensé que sur 3 jours.
  static double _dailyAverage(double expenses, DateTime month) {
    if (expenses <= 0) return 0;

    final now = DateTime.now();

    final isCurrentMonth =
        month.year == now.year && month.month == now.month;

    final days = isCurrentMonth ? now.day : _daysInMonth(month.year, month.month);

    return expenses / days;
  }

  static int _daysInMonth(int year, int month) {
    // Le jour 0 du mois suivant donne le nombre de jours du mois courant.
    return DateTime(year, month + 1, 0).day;
  }

  /// Historique des mois présents dans [transactions], du plus récent au plus
  /// ancien.
  ///
  /// Sert à déterminer si l'utilisateur dispose d'un historique suffisant
  /// pour une prévision crédible.
  /// Nombre de mois de [transactions] contenant au moins une donnée.
  ///
  /// La clé est zero-padrée : sans elle, janvier (`1`) et novembre (`11`)
  /// produiraient la même chaîne et seraient comptés comme un seul mois.
  static int countMonthsWithData(List<Transaction> transactions) {
    final months = <String>{};

    for (final transaction in transactions) {
      months.add(_monthKey(transaction.date));
    }

    return months.length;
  }

  /// Clé de mois stable et sans ambiguïté.
  static String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    return '${date.year}-$month';
  }

  /// Noms des mois de [month] et des [count - 1] mois précédents.
  static List<DateTime> recentMonths(DateTime month, int count) {
    return List.generate(count, (index) {
      return DateTime(month.year, month.month - index);
    });
  }
}
