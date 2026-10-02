import 'package:flutter/material.dart';

import 'pages/transactions_page.dart';
import 'pages/categories_page.dart';
import 'pages/budget_page.dart';
import 'pages/goals_page.dart';
import 'pages/forecast_page.dart';
import 'models/finance_summary.dart';
import 'widgets/finance_chart.dart';

import 'package:fl_chart/fl_chart.dart';

import 'models/transaction.dart';
import 'services/finance_service.dart';

void main() {
  runApp(const TenaBudgetApp());
}

class TenaBudgetApp extends StatelessWidget {
  const TenaBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TENΛ Budget',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFD4AF37),
          surface: const Color(0xFF111113),
        ),
        scaffoldBackgroundColor: const Color(0xFF09090B),
        cardTheme: CardThemeData(
          color: const Color(0xFF141416),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF09090B),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const TenaHome(),
    );
  }
}

class TenaHome extends StatefulWidget {
  const TenaHome({super.key});

  @override
  State<TenaHome> createState() => _TenaHomeState();
}

class _TenaHomeState extends State<TenaHome> {
  int selectedIndex = 0;

  final pages = const [
    _Page(title: 'Accueil', icon: Icons.home_outlined),
    _Page(title: 'Budget', icon: Icons.account_balance_wallet_outlined),
    _Page(title: 'Transactions', icon: Icons.swap_vert),
    _Page(title: 'Catégories', icon: Icons.category_outlined),
    _Page(title: 'Objectifs', icon: Icons.track_changes_outlined),
    _Page(title: 'Prévisions', icon: Icons.insights_outlined),
    _Page(title: 'IA TENΛ', icon: Icons.auto_awesome),
    _Page(title: 'Rapports', icon: Icons.assessment_outlined),
    _Page(title: 'Documents', icon: Icons.folder_outlined),
    _Page(title: 'Notifications', icon: Icons.notifications_none),
    _Page(title: 'Comparateur', icon: Icons.compare_arrows),
    _Page(title: 'Famille', icon: Icons.family_restroom),
    _Page(title: 'Entreprise', icon: Icons.business_outlined),
    _Page(title: 'Autopilot', icon: Icons.bolt_outlined),
    _Page(title: 'Paramètres', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final current = pages[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/tena_icon.png', width: 32, height: 32),
            const SizedBox(width: 10),
            const Text('TENΛ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              'Budget',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => setState(() => selectedIndex = 8),
            icon: const Icon(Icons.notifications_none),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(radius: 17, child: Text('C')),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  children: [
                    Image.asset('assets/tena_icon.png', width: 42, height: 42),
                    const SizedBox(width: 12),
                    const Text(
                      'TENΛ Budget',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < pages.length; i++)
                ListTile(
                  leading: Icon(pages[i].icon),
                  title: Text(pages[i].title),
                  selected: selectedIndex == i,
                  onTap: () {
                    setState(() => selectedIndex = i);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
      body: _buildPage(current),
    );
  }

  Widget _buildPage(_Page page) {
    if (selectedIndex == 0) {
      return const DashboardPage();
    }

    if (selectedIndex == 1) {
      return BudgetPage(month: DateTime.now());
    }

    if (selectedIndex == 2) {
      return const TransactionsPage();
    }

    if (selectedIndex == 3) {
      return const CategoriesPage();
    }
    if (selectedIndex == 4) {
      return const GoalsPage();
    }
    if (selectedIndex == 5) {
      return const ForecastPage();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              page.icon,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              page.title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Module TENΛ Budget',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<FinanceSummary> _summaryFuture;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  void _loadMonth() {
    _summaryFuture = FinanceService.getSummaryForMonth(_selectedMonth);
  }

  void _changeMonth(int amount) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + amount,
      );
      _loadMonth();
    });
  }

  String _monthName(DateTime date) {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];

    return months[date.month - 1];
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  List<FlSpot> _chartSpots(
    List<Transaction> transactions,
    TransactionType type,
  ) {
    final spots = <FlSpot>[];

    for (var i = 0; i < transactions.length; i++) {
      final transaction = transactions[i];

      if (transaction.type == type) {
        spots.add(FlSpot(i.toDouble(), transaction.amount));
      }
    }

    return spots;
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _monthSelector(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                tooltip: 'Mois précédent',
                onPressed: () => _changeMonth(-1),
                icon: Icon(
                  Icons.chevron_left,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'PÉRIODE',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_monthName(_selectedMonth)} ${_selectedMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                tooltip: 'Mois suivant',
                onPressed: () => _changeMonth(1),
                icon: Icon(
                  Icons.chevron_right,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewCard(BuildContext context, FinanceSummary summary) {
    final scheme = Theme.of(context).colorScheme;
    final net = summary.income - summary.expenses;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;

          final mainContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solde du mois',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _money(summary.balance),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    net >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${net >= 0 ? '+' : ''}${_money(net)} ce mois-ci',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          );

          final details = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverviewMiniStat(
                label: 'Revenus',
                value: _money(summary.income),
                icon: Icons.arrow_downward_rounded,
              ),
              const SizedBox(width: 24),
              _OverviewMiniStat(
                label: 'Dépenses',
                value: _money(summary.expenses),
                icon: Icons.arrow_upward_rounded,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [mainContent, const SizedBox(height: 24), details],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: mainContent),
              details,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinanceSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Impossible de charger le budget.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      setState(_loadMonth);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final summary = snapshot.data!;
        final chartLabels = summary.allTransactions.map((transaction) {
          return '${transaction.date.day}/${transaction.date.month}';
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 1000
                ? 32.0
                : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour 👋',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Voici la situation de ton budget.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (constraints.maxWidth >= 700)
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Image.asset(
                            'assets/tena_icon.png',
                            width: 48,
                            height: 48,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _monthSelector(context),

                  const SizedBox(height: 18),

                  _overviewCard(context, summary),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    context,
                    'Vue d’ensemble',
                    'Les indicateurs clés de la période sélectionnée.',
                  ),

                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final width = cardConstraints.maxWidth;
                      final columns = width >= 1100
                          ? 4
                          : width >= 620
                          ? 2
                          : 1;
                      const gap = 12.0;
                      final cardWidth = (width - gap * (columns - 1)) / columns;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          _StatCard(
                            width: cardWidth,
                            title: 'Solde',
                            value: _money(summary.balance),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          _StatCard(
                            width: cardWidth,
                            title: 'Dépenses',
                            value: _money(summary.expenses),
                            icon: Icons.arrow_upward_rounded,
                          ),
                          _StatCard(
                            width: cardWidth,
                            title: 'Revenus',
                            value: _money(summary.income),
                            icon: Icons.arrow_downward_rounded,
                          ),
                          _StatCard(
                            width: cardWidth,
                            title: 'Transactions',
                            value: '${summary.allTransactions.length}',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  if (summary.allTransactions.isNotEmpty) ...[
                    _sectionTitle(
                      context,
                      'Évolution financière',
                      'Revenus et dépenses du mois.',
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 280,
                          child: FinanceChart(
                            income: _chartSpots(
                              summary.allTransactions,
                              TransactionType.income,
                            ),
                            expenses: _chartSpots(
                              summary.allTransactions,
                              TransactionType.expense,
                            ),
                            labels: chartLabels,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.asset('assets/tena_icon.png'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TENΛ IA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Ton futur assistant financier pourra '
                                  'analyser ton budget et tes habitudes ici.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.auto_awesome, size: 22),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  _sectionTitle(
                    context,
                    'Activité récente',
                    'Les dernières opérations de ce mois.',
                  ),

                  const SizedBox(height: 12),

                  if (summary.recentTransactions.isEmpty)
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 42,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Aucune transaction pour ce mois.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      child: Column(
                        children: summary.recentTransactions.asMap().entries.map((
                          entry,
                        ) {
                          final index = entry.key;
                          final transaction = entry.value;
                          final isIncome =
                              transaction.type == TransactionType.income;

                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                  ),
                                ),
                                title: Text(
                                  transaction.description.isEmpty
                                      ? transaction.category
                                      : transaction.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(transaction.category),
                                ),
                                trailing: Text(
                                  '${isIncome ? '+' : '-'}${_money(transaction.amount)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (index < summary.recentTransactions.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 18,
                                  endIndent: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OverviewMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _OverviewMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page {
  final String title;
  final IconData icon;

  const _Page({required this.title, required this.icon});
}
