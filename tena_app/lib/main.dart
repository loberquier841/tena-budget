import 'package:flutter/material.dart';

import 'pages/transactions_page.dart';
import 'pages/categories_page.dart';
import 'pages/budget_page.dart';
import 'pages/goals_page.dart';
import 'pages/forecast_page.dart';
import 'models/finance_summary.dart';
import 'widgets/finance_chart.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/transaction.dart';
import 'services/crypto_service.dart';
import 'services/finance_service.dart';
import 'services/secure_key_store.dart';
import 'state/period_state.dart';
import 'theme/tena_app_theme.dart';
import 'theme/tena_theme.dart';
import 'widgets/tena_card.dart';

Future<void> main() async {
  // La clé maîtresse doit être résolue avant le premier accès à la base : la
  // migration v3 chiffre les lignes existantes à l'ouverture. Le keystore du
  // système est tenté en premier, les préférences servent de repli.
  WidgetsFlutterBinding.ensureInitialized();

  CryptoService.useKeyStore(
    SecureStorageKeyStore(
      fallback: PreferencesKeyStore(SharedPreferences.getInstance),
    ),
  );

  runApp(const TenaBudgetApp());
}

class TenaBudgetApp extends StatelessWidget {
  const TenaBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TENΛ Budget',
      debugShowCheckedModeBanner: false,
      // Thème centralisé : voir `buildTenaTheme` pour le détail des choix.
      theme: buildTenaTheme(),
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

  /// Période partagée par les pages : le mois sélectionné sur le tableau de
  /// bord s'applique également au module Budget (PeriodState était jusqu'ici
  /// créé mais jamais utilisé).
  final PeriodState _period = PeriodState();

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
  void dispose() {
    _period.dispose();
    super.dispose();
  }

  /// Change de page dans la navigation principale.
  ///
  /// L'index est borné pour qu'un appel depuis un widget ne puisse pas
  /// laisser l'interface dans un état incohérent.
  void _goToPage(int index) {
    if (index < 0 || index >= pages.length) return;

    setState(() => selectedIndex = index);
  }

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
            // Index 9 = page « Notifications » de la liste `pages`
            // (l'index 8 correspond à « Documents »).
            onPressed: () => setState(() => selectedIndex = 9),
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
      return DashboardPage(period: _period, onNavigate: _goToPage);
    }

    if (selectedIndex == 1) {
      return BudgetPage(month: _period.selectedMonth);
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
  final PeriodState period;

  /// Navigation vers un autre module, fournie par l'écran hôte.
  final void Function(int index) onNavigate;

  const DashboardPage({
    super.key,
    required this.period,
    required this.onNavigate,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<FinanceSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  void _loadMonth() {
    _summaryFuture = FinanceService.getSummaryForMonth(
      widget.period.selectedMonth,
    );
  }

  void _changeMonth(int amount) {
    // La période est partagée : le module Budget suivra le mois choisi ici.
    if (amount < 0) {
      widget.period.previousMonth();
    } else {
      widget.period.nextMonth();
    }

    setState(_loadMonth);
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

  /// Agrège les transactions par jour calendaire.
  ///
  /// Auparavant, une pointe était créée par transaction : l'axe X
  /// représentait l'ordre des lignes et non les dates, ce qui était trompeur
  /// (deux mouvements le même jour apparaissaient à deux abscisses). Les deux
  /// séries partagent désormais le même axe, avec 0 pour un jour sans mouvement.
  _DailyChart _dailyChart(List<Transaction> transactions) {
    final totals = <DateTime, _DailyTotals>{};

    for (final transaction in transactions) {
      final day = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      final current = totals[day] ?? _DailyTotals();

      if (transaction.type == TransactionType.income) {
        current.income += transaction.amount;
      } else {
        current.expenses += transaction.amount;
      }

      totals[day] = current;
    }

    final days = totals.keys.toList()..sort();

    return _DailyChart(
      labels: [for (final day in days) '${day.day}/${day.month}'],
      income: [
        for (var i = 0; i < days.length; i++)
          FlSpot(i.toDouble(), totals[days[i]]!.income),
      ],
      expenses: [
        for (var i = 0; i < days.length; i++)
          FlSpot(i.toDouble(), totals[days[i]]!.expenses),
      ],
    );
  }


  Widget _monthSelector(BuildContext context) {
    return TenaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TenaSpacing.sm,
        vertical: TenaSpacing.sm,
      ),
      child: Row(
        children: [
          _MonthArrow(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Mois précédent',
            onPressed: () => _changeMonth(-1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'PÉRIODE',
                  style: TenaLabels.overline.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_monthName(widget.period.selectedMonth)} '
                  '${widget.period.selectedMonth.year}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          _MonthArrow(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Mois suivant',
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  /// Carte d'appel à l'assistant IA.
  ///
  /// C'est l'action principale du tableau de bord : elle est traitée comme
  /// un bouton, avec une zone tactile couvrant toute la carte, un liseré doré
  /// et un dégradé discret. La navigation est réellement fonctionnelle : elle
  /// ouvre le module IA.
  Widget _aiCard(BuildContext context) {
    return TenaCard(
      highlighted: true,
      padding: EdgeInsets.zero,
      onTap: () => widget.onNavigate(6),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: TenaRadius.lg,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: TenaColors.goldGradient,
          ),
        ),
        padding: const EdgeInsets.all(TenaSpacing.xl),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: TenaColors.gold.withValues(alpha: 0.12),
                borderRadius: TenaRadius.lg,
                border: Border.all(
                  color: TenaColors.gold.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset('assets/tena_icon.png'),
            ),
            const SizedBox(width: TenaSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 15,
                        color: TenaColors.gold,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Demander à TENΛ IA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Analyse tes dépenses, tes habitudes et tes objectifs.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: TenaColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TenaSpacing.md),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: TenaColors.gold,
                borderRadius: TenaRadius.md,
                boxShadow: TenaShadows.gold,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 19,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte principale « solde du mois ».
  ///
  /// C'est le point focal du tableau de bord : elle est volontairement la seule
  /// zone en or de l'écran, ce qui crée un point d'entrée visuel clair au lieu
  /// de saupoudrer la même couleur partout.
  Widget _overviewCard(BuildContext context, FinanceSummary summary) {
    final net = summary.balance;

    final isPositive = net >= 0;

    // Une carte entièrement vide serait un aplat décoratif trompeur : on
    // indique clairement qu'aucune opération n'est enregistrée.
    if (summary.income == 0 && summary.expenses == 0) {
      return TenaCard(
        highlighted: true,
        padding: const EdgeInsets.all(TenaSpacing.xl),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TenaColors.gold.withValues(alpha: 0.12),
                borderRadius: TenaRadius.md,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: TenaColors.gold,
              ),
            ),
            const SizedBox(width: TenaSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aucune opération ce mois-ci',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TenaColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ajoute une transaction depuis l\'onglet Transactions '
                    'pour voir apparaître ton solde et tes graphiques.',
                    style: TextStyle(
                      fontSize: 13,
                      color: TenaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return TenaCard(
      highlighted: true,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: TenaRadius.lg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: TenaColors.goldGradient,
          ),
        ),
        padding: const EdgeInsets.all(TenaSpacing.xl),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Seuil bas : sur téléphone portrait, les deux indicateurs côte à
            // côte deviennent illisibles bien avant 600 px.
            final compact = constraints.maxWidth < 520;

            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('SOLDE DU MOIS', style: TenaLabels.overline),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TenaSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (isPositive
                                ? TenaColors.success
                                : TenaColors.danger)
                            .withValues(alpha: 0.14),
                        borderRadius: TenaRadius.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 13,
                            color: isPositive
                                ? TenaColors.success
                                : TenaColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPositive ? 'Excédent' : 'Découvert',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isPositive
                                  ? TenaColors.success
                                  : TenaColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TenaSpacing.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tenaMoney(net),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      color: isPositive
                          ? TenaColors.goldLight
                          : TenaColors.danger,
                    ),
                  ),
                ),
                const SizedBox(height: TenaSpacing.xs),
                Text(
                  isPositive
                      ? 'Tu as mis de côté ${tenaMoney(net)} ce mois-ci.'
                      : 'Tes dépenses dépassent tes revenus de '
                            '${tenaMoney(net.abs())}.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: TenaColors.textSecondary,
                  ),
                ),
              ],
            );

            final details = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OverviewMiniStat(
                  label: 'Revenus',
                  value: tenaMoney(summary.income),
                  icon: Icons.south_west_rounded,
                  color: TenaColors.success,
                ),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(
                    horizontal: TenaSpacing.xl,
                  ),
                  color: TenaColors.border,
                ),
                _OverviewMiniStat(
                  label: 'Dépenses',
                  value: tenaMoney(summary.expenses),
                  icon: Icons.north_east_rounded,
                  color: TenaColors.danger,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  main,
                  const SizedBox(height: TenaSpacing.xl),
                  details,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: main),
                const SizedBox(width: TenaSpacing.xl),
                details,
              ],
            );
          },
        ),
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
        final chart = _dailyChart(summary.allTransactions);

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

                  const SizedBox(height: TenaSpacing.xl),

                  _monthSelector(context),

                  const SizedBox(height: TenaSpacing.lg),

                  _overviewCard(context, summary),

                  const SizedBox(height: TenaSpacing.xxl),

                  TenaSectionTitle(
                    title: 'Vue d’ensemble',
                    subtitle: 'Les indicateurs clés de la période sélectionnée.',
                    icon: Icons.dashboard_outlined,
                  ),

                  const SizedBox(height: TenaSpacing.md),

                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final width = cardConstraints.maxWidth;

                      final columns = width >= 1100
                          ? 4
                          : width >= 620
                          ? 2
                          : 1;

                      const gap = TenaSpacing.md;

                      final cardWidth = (width - gap * (columns - 1)) / columns;

                      final isPositive = summary.balance >= 0;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          TenaStatCard(
                            width: cardWidth,
                            label: 'Solde',
                            value: tenaMoney(summary.balance),
                            icon: Icons.account_balance_wallet_outlined,
                            valueColor: isPositive
                                ? TenaColors.goldLight
                                : TenaColors.danger,
                            hint: isPositive ? 'Excédent' : 'Découvert',
                            hintIsWarning: !isPositive,
                          ),
                          TenaStatCard(
                            width: cardWidth,
                            label: 'Revenus',
                            value: tenaMoney(summary.income),
                            icon: Icons.south_west_rounded,
                            valueColor: TenaColors.success,
                          ),
                          TenaStatCard(
                            width: cardWidth,
                            label: 'Dépenses',
                            value: tenaMoney(summary.expenses),
                            icon: Icons.north_east_rounded,
                            valueColor: TenaColors.danger,
                          ),
                          TenaStatCard(
                            width: cardWidth,
                            label: 'Transactions',
                            value: '${summary.allTransactions.length}',
                            icon: Icons.receipt_long_outlined,
                            hint: 'sur la période',
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: TenaSpacing.xxl),

                  if (summary.allTransactions.isNotEmpty) ...[
                    const TenaSectionTitle(
                      title: 'Évolution financière',
                      subtitle: 'Revenus et dépenses du mois.',
                      icon: Icons.show_chart_rounded,
                    ),
                    const SizedBox(height: TenaSpacing.md),
                    TenaCard(
                      child: FinanceChart(
                        income: chart.income,
                        expenses: chart.expenses,
                        labels: chart.labels,
                      ),
                    ),
                    const SizedBox(height: TenaSpacing.xxl),
                  ],

                  // L'assistant IA est l'action principale du tableau de
                  // bord : elle reçoit un liseré doré, un dégradé et une
                  // zone tactile large.
                  _aiCard(context),

                  const SizedBox(height: TenaSpacing.xxl),

                  const TenaSectionTitle(
                    title: 'Activité récente',
                    subtitle: 'Les dernières opérations de ce mois.',
                    icon: Icons.receipt_long_outlined,
                  ),

                  const SizedBox(height: TenaSpacing.md),

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

/// Bouton de navigation de période.
///
/// Isolé pour que les deux flèches partagent exactement le même rendu et la
/// même zone tactile.
class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MonthArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TenaColors.surfaceRaised,
      borderRadius: TenaRadius.md,
      child: InkWell(
        onTap: onPressed,
        borderRadius: TenaRadius.md,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            // Zone tactile confortable, sans dépasser la hauteur de la carte.
            width: 44,
            height: 40,
            child: Icon(icon, size: 22, color: TenaColors.gold),
          ),
        ),
      ),
    );
  }
}

class _OverviewMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewMiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: TenaColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: TenaColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}


class _Page {
  final String title;
  final IconData icon;

  const _Page({required this.title, required this.icon});
}

class _DailyTotals {
  double income = 0;
  double expenses = 0;
}

class _DailyChart {
  final List<String> labels;
  final List<FlSpot> income;
  final List<FlSpot> expenses;

  const _DailyChart({
    required this.labels,
    required this.income,
    required this.expenses,
  });
}
