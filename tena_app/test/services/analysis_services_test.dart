import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/insight_service.dart';
import 'package:tena_budget/services/notification_service.dart';
import 'package:tena_budget/services/report_service.dart';

Transaction _transaction({
  required String id,
  required double amount,
  required DateTime date,
  String category = 'Courses',
  TransactionType type = TransactionType.expense,
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    description: 'Test',
    date: date,
    type: type,
  );
}

/// Construit un bilan à partir des transactions.
///
/// Le rapport est intégralement recalculé par [ReportService.build] : les
/// transactions sont la seule source de vérité, ce qui évite qu'un test
/// atteste d'un total que le service ne calculerait pas.
PeriodReport _report({
  required List<Transaction> transactions,
  double previousExpenses = 0,
  int comparedMonths = 1,
}) {
  return ReportService.build(
    month: DateTime(2026, 3),
    transactions: transactions,
    previousExpenses: previousExpenses,
    previousIncome: 0,
    comparedMonths: comparedMonths,
  );
}

void main() {
  group('ReportService', () {
    test('un mois sans donnée renvoie des totaux à zéro', () {
      final report = _report( transactions: []);

      expect(report.income, 0);
      expect(report.expenses, 0);
      expect(report.balance, 0);
      expect(report.topCategories, isEmpty);
    });

    test('ignore les transactions des autres mois', () {
      final report = _report(
        transactions: [
          _transaction(id: 'a', amount: 100, date: DateTime(2026, 3, 5)),
          _transaction(id: 'b', amount: 999, date: DateTime(2026, 4, 5)),
        ],
      );

      expect(report.expenses, 100);
    });

    test('classe les catégories de la plus à la moins lourde', () {
      final report = _report(
        transactions: [
          _transaction(
            id: 'a',
            amount: 100,
            date: DateTime(2026, 3, 1),
            category: 'Petit',
          ),
          _transaction(
            id: 'b',
            amount: 300,
            date: DateTime(2026, 3, 2),
            category: 'Gros',
          ),
          _transaction(id: 'c', amount: 200, date: DateTime(2026, 3, 3)),
        ],
      );

      expect(report.expenses, 600);

      // Trois catégories distinctes : Petit (100), Gros (300) et Courses (200).
      expect(report.topCategories.length, 3);
      expect(report.topCategories[0].category, 'Gros');
      expect(report.topCategories[0].total, 300);
      expect(report.topCategories[0].share, 0.5);
      expect(report.topCategories[2].total, 100);
    });

    test('le taux d épargne vaut zéro sans revenu', () {
      final report = _report(
        transactions: [
          _transaction(id: 'a', amount: 100, date: DateTime(2026, 3, 1)),
        ],
      );

      // Diviser par un revenu nul donnerait NaN ou l'infini.
      expect(report.savingsRate, 0);
    });

    test('le taux d épargne rapporte le solde au revenu', () {
      final report = _report(
        transactions: [
          _transaction(
            id: 'a',
            amount: 2000,
            date: DateTime(2026, 3, 1),
            type: TransactionType.income,
          ),
          _transaction(id: 'b', amount: 500, date: DateTime(2026, 3, 2)),
        ],
      );

      expect(report.income, 2000);
      expect(report.expenses, 500);
      expect(report.balance, 1500);
      expect(report.savingsRate, 0.75);
    });

    test('la variation est nulle sans historique comparable', () {
      final report = _report(
        transactions: [
          _transaction(id: 'a', amount: 100, date: DateTime(2026, 3, 1)),
        ],
      );

      // Comparer une dépense à zéro n'a pas de sens.
      expect(report.expensesVariation, isNull);
      expect(report.hasEnoughHistory, isFalse);
    });

    test('compte les mois distincts', () {
      final months = ReportService.countMonthsWithData([
        _transaction(id: 'a', amount: 1, date: DateTime(2026, 1, 1)),
        _transaction(id: 'b', amount: 1, date: DateTime(2026, 1, 2)),
        _transaction(id: 'c', amount: 1, date: DateTime(2026, 2, 1)),
      ]);

      expect(months, 2);
    });

    test('distingue janvier de novembre', () {
      // Régression : sans clé zero-padrée, `1` et `11` produisaient la même
      // chaîne et ces deux mois n'en faisaient qu'un.
      final months = ReportService.countMonthsWithData([
        _transaction(id: 'a', amount: 1, date: DateTime(2026, 1, 10)),
        _transaction(id: 'b', amount: 1, date: DateTime(2026, 11, 10)),
      ]);

      expect(months, 2);
    });

    test('énumère les mois récents et franchit les années', () {
      final months = ReportService.recentMonths(DateTime(2026, 1), 3);

      expect(months.length, 3);
      expect(months[0], DateTime(2026, 1));
      expect(months[1], DateTime(2025, 12));
      expect(months[2], DateTime(2025, 11));
    });
  });

  group('InsightService', () {
    test('ne produit aucun conseil sans données', () {
      final insights = InsightService.analyze(
        month: DateTime(2026, 3),
        transactions: [],
        report: _report( transactions: []),
      );

      // Sans revenu ni dépense, aucun conseil n'est justifié.
      expect(insights, isEmpty);
    });

    test('signale l’absence de revenu s’il y a des dépenses', () {
      final transactions = [
        _transaction(id: 'a', amount: 300, date: DateTime(2026, 3, 1)),
      ];

      final insights = InsightService.analyze(
        month: DateTime(2026, 3),
        transactions: transactions,
        report: _report( transactions: transactions),
      );

      expect(insights.any((i) => i.tone == InsightTone.warning), isTrue);
    });

    test('signale un solde négatif', () {
      final transactions = [
        _transaction(
          id: 'a',
          amount: 1000,
          date: DateTime(2026, 3, 1),
          type: TransactionType.income,
        ),
        _transaction(id: 'b', amount: 1500, date: DateTime(2026, 3, 2)),
      ];

      final insights = InsightService.analyze(
        month: DateTime(2026, 3),
        transactions: transactions,
        report: _report(
          transactions: transactions,
        ),
      );

      expect(insights.any((i) => i.tone == InsightTone.warning), isTrue);
    });

    test('pointe le poste principal', () {
      final transactions = [
        _transaction(
          id: 'a',
          amount: 800,
          date: DateTime(2026, 3, 1),
          category: 'Voyages',
        ),
        _transaction(id: 'b', amount: 200, date: DateTime(2026, 3, 2)),
      ];

      final insights = InsightService.analyze(
        month: DateTime(2026, 3),
        transactions: transactions,
        report: _report(
          transactions: transactions,
        ),
      );

      expect(insights.any((i) => i.title.contains('Voyages')), isTrue);
    });

    test('trie les conseils par priorité décroissante', () {
      final transactions = [
        _transaction(id: 'a', amount: 100, date: DateTime(2026, 3, 1)),
      ];

      final insights = InsightService.analyze(
        month: DateTime(2026, 3),
        transactions: transactions,
        report: _report( transactions: transactions),
      );

      for (var i = 1; i < insights.length; i++) {
        expect(
          insights[i - 1].weight >= insights[i].weight,
          isTrue,
          reason: 'les conseils doivent être triés du plus au moins urgent',
        );
      }
    });
  });

  group('NotificationRules.checkBudgets', () {
    final now = DateTime(2026, 3, 15);

    test('ignore une catégorie sans budget défini', () {
      final alerts = NotificationRules.checkBudgets(
        spentByCategory: {'Courses': 500},
        budgetByCategory: const {},
        now: now,
      );

      expect(alerts, isEmpty);
    });

    test('n’alerte pas sous 90 % du budget', () {
      final alerts = NotificationRules.checkBudgets(
        spentByCategory: {'Courses': 800},
        budgetByCategory: {'Courses': 1000},
        now: now,
      );

      expect(alerts, isEmpty);
    });

    test('prévient à 90 % du budget', () {
      final alerts = NotificationRules.checkBudgets(
        spentByCategory: {'Courses': 950},
        budgetByCategory: {'Courses': 1000},
        now: now,
      );

      expect(alerts.length, 1);
      expect(alerts.single.severity, NotificationSeverity.warning);
    });

    test('signale le dépassement et chiffre l’excédent', () {
      final alerts = NotificationRules.checkBudgets(
        spentByCategory: {'Courses': 1200},
        budgetByCategory: {'Courses': 1000},
        now: now,
      );

      expect(alerts.length, 1);
      expect(alerts.single.severity, NotificationSeverity.critical);
      expect(alerts.single.message, contains('200,00 €'));
    });
  });

  group('NotificationRules.checkNegativeBalance', () {
    final now = DateTime(2026, 3, 15);

    test('reste muette sans revenu déclaré', () {
      final alerts = NotificationRules.checkNegativeBalance(
        income: 0,
        expenses: 500,
        now: now,
      );

      expect(alerts, isEmpty);
    });

    test('reste muette si le solde est positif', () {
      final alerts = NotificationRules.checkNegativeBalance(
        income: 2000,
        expenses: 1500,
        now: now,
      );

      expect(alerts, isEmpty);
    });

    test('alerte sur un solde négatif', () {
      final alerts = NotificationRules.checkNegativeBalance(
        income: 1000,
        expenses: 1500,
        now: now,
      );

      expect(alerts.length, 1);
      expect(alerts.single.severity, NotificationSeverity.critical);
    });
  });

  group('NotificationRules.checkGoals', () {
    final now = DateTime(2026, 3, 15);

    test('ignore un objectif sans cible', () {
      final alerts = NotificationRules.checkGoals(
        goals: [(name: 'PC', target: 0, saved: 500)],
        now: now,
      );

      expect(alerts, isEmpty);
    });

    test('signale un objectif atteint', () {
      final alerts = NotificationRules.checkGoals(
        goals: [(name: 'PC', target: 1000, saved: 1000)],
        now: now,
      );

      expect(alerts.length, 1);
      expect(alerts.single.severity, NotificationSeverity.info);
    });

    test('prévient à 80 % d un objectif', () {
      final alerts = NotificationRules.checkGoals(
        goals: [(name: 'Vacances', target: 1000, saved: 850)],
        now: now,
      );

      expect(alerts.length, 1);
      expect(alerts.single.severity, NotificationSeverity.warning);
    });

    test('reste muette sur un objectif en retard normal', () {
      final alerts = NotificationRules.checkGoals(
        goals: [(name: 'PC', target: 1000, saved: 200)],
        now: now,
      );

      expect(alerts, isEmpty);
    });
  });
}
