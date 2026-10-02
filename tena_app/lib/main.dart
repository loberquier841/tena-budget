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
        colorSchemeSeed: const Color(0xFF7C4DFF),
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinanceSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Impossible de charger le budget.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final summary = snapshot.data!;

        final chartLabels = summary.allTransactions.map((transaction) {
          return '${transaction.date.day}/${transaction.date.month}';
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bonjour 👋',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Voici la situation de ton budget.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Mois précédent',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Période',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                      IconButton(
                        tooltip: 'Mois suivant',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Solde',
                    value: _money(summary.balance),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _StatCard(
                    title: 'Dépenses',
                    value: _money(summary.expenses),
                    icon: Icons.arrow_upward,
                  ),
                  _StatCard(
                    title: 'Revenus',
                    value: _money(summary.income),
                    icon: Icons.arrow_downward,
                  ),
                  _StatCard(
                    title: 'Transactions',
                    value: '${summary.recentTransactions.length}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              if (summary.recentTransactions.isNotEmpty) ...[
                const Text(
                  'Évolution financière',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 28),
              ],

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/tena_icon.png',
                        width: 42,
                        height: 42,
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
                            Text('L’assistant financier sera disponible ici.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Activité de ${_monthName(_selectedMonth)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (summary.recentTransactions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Aucune transaction pour ce mois.',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: summary.recentTransactions.map((transaction) {
                      final isIncome =
                          transaction.type == TransactionType.income;

                      return ListTile(
                        leading: Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        ),
                        title: Text(
                          transaction.description.isEmpty
                              ? transaction.category
                              : transaction.description,
                        ),
                        subtitle: Text(transaction.category),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${_money(transaction.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(title, style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
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
