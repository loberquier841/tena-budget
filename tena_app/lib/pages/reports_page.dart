import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/finance_service.dart';
import '../models/transaction.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';


class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  String? _error;
  List<MonthlyData> _monthlyData = [];
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalSavings = 0;
  double _savingsRate = 0;
  Map<String, double> _categoryTotals = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transactions = await FinanceService.getTransactions();
      if (transactions.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Aucune transaction trouvée.';
        });
        return;
      }

      // Group by month
      final Map<String, MonthlyData> monthlyMap = {};
      final Map<String, double> categoryMap = {};

      for (final t in transactions) {
        final monthKey = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
        final data = monthlyMap.putIfAbsent(
          monthKey,
          () => MonthlyData(
            month: DateTime(t.date.year, t.date.month),
            income: 0,
            expenses: 0,
          ),
        );

        if (t.type == TransactionType.income) {
          data.income += t.amount;
        } else {
          data.expenses += t.amount;
          categoryMap.update(
            t.category,
            (value) => value + t.amount,
            ifAbsent: () => t.amount,
          );
        }
      }

      // Convert to list and sort by month ascending
      final List<MonthlyData> list = monthlyMap.values.toList()
        ..sort((a, b) => a.month.compareTo(b.month));

      // Keep only last 12 months
      final List<MonthlyData> last12 = list.length > 12
          ? list.sublist(list.length - 12)
          : list;

      // Compute totals across last 12 months
      double totalInc = 0, totalExp = 0;
      for (final d in last12) {
        totalInc += d.income;
        totalExp += d.expenses;
      }
      final totalSave = totalInc - totalExp;
      final saveRate = totalInc > 0 ? totalSave / totalInc : 0.0;

      setState(() {
        _monthlyData = last12;
        _totalIncome = totalInc;
        _totalExpenses = totalExp;
        _totalSavings = totalSave;
        _savingsRate = saveRate;
        _categoryTotals = categoryMap;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erreur lors du chargement des données : $e';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: TenaCard(
          padding: const EdgeInsets.all(TenaSpacing.lg),
          child: Text(
            _error!,
            style: TextStyle(color: TenaColors.textSecondary),
          ),
        ),
      );
    }

    if (_monthlyData.isEmpty) {
      return const Center(
        child: TenaEmptyState(
          icon: Icons.insights_outlined,
          title: 'Aucune donnée',
          message:
              'Aucune transaction disponible pour afficher les rapports.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(TenaSpacing.lg),
        children: [
          // Summary cards
          Wrap(
            spacing: TenaSpacing.md,
            runSpacing: TenaSpacing.md,
            children: [
              TenaStatCard(
                label: 'Revenus (12 mois)',
                value: '${_totalIncome.toStringAsFixed(2).replaceAll('.', ',')} €',
                icon: Icons.arrow_downward,
                valueColor: TenaColors.success,
                hint: 'Total des revenus sur les 12 derniers mois',
              ),
              TenaStatCard(
                label: 'Dépenses (12 mois)',
                value: '${_totalExpenses.toStringAsFixed(2).replaceAll('.', ',')} €',
                icon: Icons.arrow_upward,
                valueColor: TenaColors.danger,
                hint: 'Total des dépenses sur les 12 derniers mois',
              ),
              TenaStatCard(
                label: 'Épargne (12 mois)',
                value: '${_totalSavings.toStringAsFixed(2).replaceAll('.', ',')} €',
                icon: Icons.account_balance_wallet_outlined,
                valueColor: _totalSavings >= 0 ? TenaColors.success : TenaColors.danger,
                hint:
                    'Revenus moins dépenses sur les 12 derniers mois',
              ),
              TenaStatCard(
                label: "Taux d'épargne",
                value: '${(_savingsRate * 100).roundToDouble()} %',
                icon: Icons.trending_up,
                valueColor: TenaColors.gold,
                hint: 'Part du revenu épargnée',
              ),
            ],
          ),
          const SizedBox(height: TenaSpacing.xl),
          // Line chart: monthly income/expenses
          TenaCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(TenaSpacing.lg),
                  child: Text(
                    'Évolution des revenus et dépenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: TenaColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(enabled: false),
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= _monthlyData.length) {
                                return const Text('');
                              }
                              final month = _monthlyData[index].month;
                              return SideTitleWidget(
                                child: Text(
                                  '${month.month}/${month.year.toString().substring(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: TenaColors.textSecondary,
                                  ),
                                ),
                                meta: meta,
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                child: Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: TenaColors.textSecondary,
                                  ),
                                ),
                                meta: meta,
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      minY: 0,
                      maxY: (_monthlyData
                              .map((e) => e.income > e.expenses
                                  ? e.income
                                  : e.expenses)
                              .reduce((a, b) => a > b ? a : b) *
                          1.1),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _monthlyData
                              .asMap()
                              .entries
                              .map((e) => FlSpot(
                                  e.key.toDouble(), e.value.income))
                              .toList(),
                          isCurved: true,
                          color: TenaColors.success,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: TenaColors.success.withValues(alpha: 0.1),
                          ),
                        ),
                        LineChartBarData(
                          spots: _monthlyData
                              .asMap()
                              .entries
                              .map((e) => FlSpot(
                                  e.key.toDouble(), e.value.expenses))
                              .toList(),
                          isCurved: true,
                          color: TenaColors.danger,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: TenaColors.danger.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TenaSpacing.xl),
          // Expenses by category bar chart
          TenaCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(TenaSpacing.lg),
                  child: Text(
                    'Répartition des dépenses par catégorie',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: TenaColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 250,
                  child: _categoryTotals.isEmpty
                      ? const Center(child: Text('Aucune dépense'))
                      : BarChart(
                          BarChartData(
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    final sortedEntries =
                                        _categoryTotals.entries.toList()
                                          ..sort((a, b) =>
                                              b.value.compareTo(a.value));
                                    if (index < 0 ||
                                        index >= sortedEntries.length) {
                                      return const Text('');
                                    }
                                    final category =
                                        sortedEntries[index].key;
                                    final display = category.length > 10
                                        ? '${category.substring(0, 10)}…'
                                        : category;
                                    return SideTitleWidget(
                                      child: Text(
                                        display,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: TenaColors.textSecondary,
                                        ),
                                      ),
                                      meta: meta,
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return SideTitleWidget(
                                      child: Text(
                                        value.toInt().toString(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: TenaColors.textSecondary,
                                        ),
                                      ),
                                      meta: meta,
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            barGroups: _categoryTotals.entries
                                .map((e) {
                                  final index = _categoryTotals.entries
                                      .toList()
                                      .indexOf(e);
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: e.value,
                                        color: TenaColors.danger,
                                        width: 18,
                                      )
                                    ],
                                  );
                                })
                                .toList(),
                            maxY: _categoryTotals.values.reduce(
                                    (a, b) => a > b ? a : b) *
                                1.1,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MonthlyData {
  final DateTime month;
  double income;
  double expenses;

  MonthlyData({
    required this.month,
    required this.income,
    required this.expenses,
  });
}
