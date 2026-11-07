import '../models/finance_entry.dart';
import '../models/finance_summary.dart';
import '../services/budget_service.dart';
import '../services/database_service.dart';
import '../services/finance_service.dart';
import '../services/goal_service.dart';

class Finance360Snapshot {
  final FinanceSummary monthSummary;
  final int assetsCents;
  final int liabilitiesCents;
  final int netWorthCents;
  final int savingsGoalsCents;
  final double globalBudget;
  final List<FinanceEntry> entries;
  const Finance360Snapshot({
    required this.monthSummary,
    required this.assetsCents,
    required this.liabilitiesCents,
    required this.netWorthCents,
    required this.savingsGoalsCents,
    required this.globalBudget,
    required this.entries,
  });
}

/// LOT 12 — agrège données réelles existantes + entrées déclaratives (additif).
class Finance360Service {
  static Future<Finance360Snapshot> load(DateTime month, {String userId = 'primary'}) async {
    final monthSummary = await FinanceService.getSummaryForMonth(month, userId: userId);
    List<FinanceEntry> entries = const [];
    try {
      entries = await DatabaseService.instance.getFinanceEntries(userId: userId);
    } catch (_) {}
    double globalBudget = 0;
    try { globalBudget = await BudgetService.getGlobalBudget(userId: userId); } catch (_) {}
    int assets = 0;
    int liabilities = 0;
    for (final e in entries.where((e) => !e.archived)) {
      if (e.kind == FinanceEntryKind.liability) {
        liabilities += e.amountCents;
      } else {
        assets += e.amountCents;
      }
    }
    int savings = 0;
    try {
      final goals = await GoalService.getGoals(userId: userId);
      for (final g in goals) {
        try { savings += (g as dynamic).savedCents as int; }
        catch (_) { try { savings += (g as dynamic).currentCents as int; } catch (_) {} }
      }
    } catch (_) {}
    return Finance360Snapshot(
      monthSummary: monthSummary,
      assetsCents: assets,
      liabilitiesCents: liabilities,
      netWorthCents: assets - liabilities,
      savingsGoalsCents: savings,
      globalBudget: globalBudget,
      entries: entries,
    );
  }
}
