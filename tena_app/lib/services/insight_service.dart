import '../models/transaction.dart';
import 'report_service.dart';

/// Ton d'un conseil, Determines la presentation.
enum InsightTone {
  positive,
  neutral,
  warning;

  String get label {
    switch (this) {
      case InsightTone.positive:
        return 'Bon point';
      case InsightTone.neutral:
        return 'À savoir';
      case InsightTone.warning:
        return 'Vigilance';
    }
  }
}

/// Conseil calcule à partir des donnees reelles de l'utilisateur.
class Insight {
  final String title;
  final String detail;

  /// Page à ouvrir pour agir sur ce conseil.
  final int pageIndex;

  final InsightTone tone;

  /// Priorité : plus la valeur est haute, plus le compte.
  final int weight;

  const Insight({
    required this.title,
    required this.detail,
    required this.pageIndex,
    required this.tone,
    required this.weight,
  });
}

/// Moteur d'analyse produisant les conseils affichés dans le module IA.
///
/// Les conseils sont dérivés des transactions et du bilan de période : aucun
/// texte n'est figé dans l'interface, ce qui évite d'annoncer une tendance que
/// les données ne soutiennent pas.
class InsightService {
  // Pages de la navigation (cf. `pages` dans main.dart).
  static const int pageTransactions = 2;
  static const int pageBudget = 1;
  static const int pageGoals = 4;
  static const int pageForecast = 5;

  /// Nombre minimal de mois de données avant d'annoncer une évolution.
  ///
  /// En dessous, une hausse ou une baisse relève de l'aléa d'un seul mois.
  static const int _minMonthsForTrend = 2;

  /// Génère les conseils pour le mois [month].
  static List<Insight> analyze({
    required DateTime month,
    required List<Transaction> transactions,
    required PeriodReport report,
  }) {
    final insights = <Insight>[];

    final monthCount = ReportService.countMonthsWithData(transactions);

    _addTrend(insights, report);
    _addSavings(insights, report);
    _addTopCategory(insights, report);
    _addConcentration(insights, report, monthCount);
    _addDailyPace(insights, report);

    // Les plus pertinents d'abord.
    insights.sort((a, b) => b.weight.compareTo(a.weight));

    return insights;
  }

  /// Compare les dépenses du mois à celles du mois précédent.
  static void _addTrend(List<Insight> insights, PeriodReport report) {
    if (!report.hasEnoughHistory) return;

    final variation = report.expensesVariation;

    if (variation == null) return;

    final percent = (variation * 100).round();

    if (variation > 0.05) {
      insights.add(
        Insight(
          title: 'Dépenses en hausse de $percent %',
          detail:
              'Tu dépenses ${_money(report.expenses)} ce mois-ci contre '
              '${_money(report.previousExpenses)} le mois précédent. '
              'Vérifie les postes qui ont progressé.',
          pageIndex: pageTransactions,
          tone: InsightTone.warning,
          weight: 80 + percent,
        ),
      );
    } else if (variation < -0.05) {
      insights.add(
        Insight(
          title: 'Dépenses en baisse de ${percent.abs()} %',
          detail:
              'Tu dépenses ${_money(report.expenses)} ce mois-ci contre '
              '${_money(report.previousExpenses)} le mois précédent.',
          pageIndex: pageTransactions,
          tone: InsightTone.positive,
          weight: 80 + percent.abs(),
        ),
      );
    } else {
      insights.add(
        Insight(
          title: 'Dépenses stables',
          detail:
              'Tes dépenses restent proches de celles du mois précédent '
              '(${_money(report.expenses)}).',
          pageIndex: pageTransactions,
          tone: InsightTone.neutral,
          weight: 40,
        ),
      );
    }
  }

  /// Commentaire sur le taux d'épargne.
  static void _addSavings(List<Insight> insights, PeriodReport report) {
    // Sans aucune transaction, aucun conseil n'est justifié : annoncer « aucun
    // revenu » sur une base vide serait une fausse information.
    if (report.income <= 0 && report.expenses <= 0) return;

    if (report.income <= 0) {
      insights.add(
        const Insight(
          title: 'Aucun revenu enregistré ce mois-ci',
          detail:
              'Sans revenu, le taux d\'épargne n\'est pas calculable. Ajoute '
              'au moins un revenu pour suivre ta capacité d\'épargne.',
          pageIndex: pageTransactions,
          tone: InsightTone.warning,
          weight: 90,
        ),
      );

      return;
    }

    final rate = (report.savingsRate * 100).round();

    if (report.balance < 0) {
      insights.add(
        Insight(
          title: 'Solde négatif de ${_money(report.balance.abs())}',
          detail:
              'Tes dépenses dépassent tes revenus. Identifie les dépenses '
              'compressibles pour redresser le solde.',
          pageIndex: pageBudget,
          tone: InsightTone.warning,
          weight: 100,
        ),
      );
    } else if (report.savingsRate >= 0.2) {
      insights.add(
        Insight(
          title: 'Taux d\'épargne de $rate %',
          detail:
              'Tu épargnes ${_money(report.balance)} ce mois-ci. '
              'Un taux supérieur à 20 % est confortable.',
          pageIndex: pageGoals,
          tone: InsightTone.positive,
          weight: 70,
        ),
      );
    } else {
      insights.add(
        Insight(
          title: 'Taux d\'épargne de $rate %',
          detail:
              'Il reste ${_money(report.balance)} après dépenses. '
              'Une petite redirection suffirait à alimenter un objectif.',
          pageIndex: pageGoals,
          tone: InsightTone.neutral,
          weight: 55,
        ),
      );
    }
  }

  /// Pointe la catégorie la plus lourde.
  static void _addTopCategory(List<Insight> insights, PeriodReport report) {
    if (report.topCategories.isEmpty) return;

    final top = report.topCategories.first;

    insights.add(
      Insight(
        title: 'Poste principal : ${top.category}',
        detail:
            '${_money(top.total)}, soit '
            '${(top.share * 100).round()} % de tes dépenses du mois.',
        pageIndex: pageTransactions,
        tone: InsightTone.neutral,
        weight: 50,
      ),
    );
  }

  /// Signale une concentration excessive des dépenses sur un seul poste.
  static void _addConcentration(
    List<Insight> insights,
    PeriodReport report,
    int monthCount,
  ) {
    if (monthCount < _minMonthsForTrend) return;

    if (report.topCategories.isEmpty) return;

    final top = report.topCategories.first;

    if (top.share >= 0.5) {
      insights.add(
        Insight(
          title: 'Dépenses concentrées sur ${top.category}',
          detail:
              'Un seul poste représente '
              '${(top.share * 100).round()} % de tes dépenses. '
              'C\'est là que se joue le plus d\'économies.',
          pageIndex: pageBudget,
          tone: InsightTone.warning,
          weight: 75,
        ),
      );
    }
  }

  /// Compare le rythme de dépense à la moyenne des mois précédents.
  static void _addDailyPace(List<Insight> insights, PeriodReport report) {
    if (!report.hasEnoughHistory) return;

    if (report.previousExpenses <= 0) return;

    final previousDaily = report.previousExpenses / 30;

    if (previousDaily <= 0) return;

    if (report.averageDailyExpense / previousDaily > 1.15) {
      insights.add(
        Insight(
          title: 'Rythme de dépense en hausse',
          detail:
              'Tu dépenses ${_money(report.averageDailyExpense)} par jour en '
              'moyenne, contre ${_money(previousDaily)} le mois précédent.',
          pageIndex: pageForecast,
          tone: InsightTone.warning,
          weight: 65,
        ),
      );
    }
  }

  static String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}
