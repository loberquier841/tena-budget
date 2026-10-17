import 'package:flutter/material.dart';

import 'pages/transactions_page.dart';
import 'pages/categories_page.dart';
import 'pages/budget_page.dart';
import 'pages/goals_page.dart';
import 'pages/forecast_page.dart';
import 'pages/profile_page.dart';
import 'pages/reports_page.dart';
import 'models/finance_summary.dart';
import 'widgets/finance_chart.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/transaction.dart';
import 'services/crypto_service.dart';
import 'services/budget_service.dart';
import 'services/finance_service.dart';
import 'services/goal_service.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/secure_key_store.dart';
import 'state/period_state.dart';
import 'theme/tena_app_theme.dart';
import 'theme/tena_theme.dart';
import 'widgets/tena_card.dart';
import 'widgets/tena_future_section.dart';
import 'widgets/tena_sidebar.dart';
import 'models/user_profile.dart';
import 'services/user_profile_service.dart';

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

  // L'état de paiement doit être connu avant le premier rendu : sans lui,
  // l'écran afficherait la page principale puis le paywall (flash).
  await PaymentService.instance.load();

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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Seuil au-delà duquel la navigation devient une colonne permanente.
  ///
  /// 1080 px permet au contenu de conserver une largeur de lecture confortable
  /// même avec la barre latérale visible.
  static const double _wideBreakpoint = 1080;

  final pages = const [
    TenaNavItem(
      title: 'Accueil',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    TenaNavItem(
      title: 'Budget',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    TenaNavItem(title: 'Transactions', icon: Icons.swap_vert_rounded),
    TenaNavItem(
      title: 'Catégories',
      icon: Icons.category_outlined,
      activeIcon: Icons.category_rounded,
    ),
    TenaNavItem(
      title: 'Objectifs',
      icon: Icons.track_changes_outlined,
      activeIcon: Icons.track_changes_rounded,
    ),
    TenaNavItem(
      title: 'Prévisions',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
    ),
    TenaNavItem(
      title: 'IA TENΛ',
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
    ),
    TenaNavItem(title: 'Rapports', icon: Icons.assessment_outlined),
    TenaNavItem(title: 'Documents', icon: Icons.folder_outlined),
    TenaNavItem(title: 'Notifications', icon: Icons.notifications_none),
    TenaNavItem(title: 'Comparateur', icon: Icons.compare_arrows_rounded),
    TenaNavItem(title: 'Famille', icon: Icons.family_restroom_rounded),
    TenaNavItem(title: 'Entreprise', icon: Icons.business_outlined),
    TenaNavItem(title: 'Autopilot', icon: Icons.bolt_rounded),
    TenaNavItem(title: 'Paramètres', icon: Icons.settings_outlined),
    TenaNavItem(title: 'Mon profil', icon: Icons.person_outline_rounded),
  ];

late Future<UserProfile?> _profileFuture;

@override
void initState() {
  super.initState();
  _profileFuture = UserProfileService.getProfile();
}
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

  /// Sélectionne un module et referme le tiroir s'il est ouvert.
  void _selectPage(int index) {
    _goToPage(index);

    final scaffold = _scaffoldKey.currentState;

    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null) {
          return ProfilePage(
            isOnboarding: true,
            onSaved: () {
              setState(() => _profileFuture = UserProfileService.getProfile());
            },
          );
        }
        // → Normal home UI (original build method body)
    final current = pages[selectedIndex];

    final sidebar = TenaSidebar(
      items: pages,
      selectedIndex: selectedIndex,
      onSelected: _selectPage,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        final content = _buildPage(current);

        return Scaffold(
          key: _scaffoldKey,

          // Sur grand écran la navigation est permanente ; sur téléphone elle
          // passe dans le tiroir. Le même composant sert les deux cas.
          appBar: isWide
              ? null
              : AppBar(
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Navigation',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  title: Text(
                    current.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => _selectPage(9),
                      icon: const Icon(Icons.notifications_none),
                    ),
                    const SizedBox(width: TenaSpacing.sm),
                  ],
                ),

          drawer: isWide
              ? null
              : Drawer(
                  width: TenaSidebar.drawerWidth,
                  backgroundColor: const Color(0xFF0D0D10),
                  child: sidebar,
                ),

          body: isWide
              ? Row(
                  children: [
                    SizedBox(width: TenaSidebar.railWidth, child: sidebar),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
        );
      },
    );
      },
    );
  }

  Widget _buildPage(TenaNavItem page) {
    if (page.title == 'Mon profil') {
      return const ProfilePage();
    }
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

    if (selectedIndex == 7) {
      return const ReportsPage();
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

    // Le budget global est injecté dans le tableau de bord : il sert à la
    // carte « Budget global » et aux alertes, et doit donc refléter la
    // dernière valeur enregistrée dans le module Budget.
    BudgetService.getGlobalBudget()
        .then((value) {
          if (!mounted) return;

          setState(() => _DashboardBudget.lastKnown = value);
        })
        .catchError((_) {
          // Un budget illisible ne doit pas empêcher l'affichage du tableau de
          // bord : la carte indiquera « Aucun budget défini ».
        });
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
                        color:
                            (isPositive
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
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                TenaSpacing.gutter(constraints.maxWidth),
                TenaSpacing.xl,
                TenaSpacing.gutter(constraints.maxWidth),
                TenaSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rangée d'en-tête : titre à gauche, sélecteur de période et
                  // action IA à droite. Sur téléphone, tout se réempile.
                  _dashboardHeader(context, constraints.maxWidth),

                  const SizedBox(height: TenaSpacing.xl),

                  _overviewCard(context, summary),

                  const SizedBox(height: TenaSpacing.xl),

                  // Zone d'alertes calculée à partir des données réelles :
                  // budget, solde et objectifs. Elle n'apparaît que si une
                  // alerte est réellement déclenchée.
                  _alertsSection(summary),

                  const SizedBox(height: TenaSpacing.xl),

                  _statsGrid(context, summary),

                  const SizedBox(height: TenaSpacing.xl),

                  _chartSection(context, summary, chart),

                  const SizedBox(height: TenaSpacing.xl),

                  _bottomColumns(context, summary),

                  const SizedBox(height: TenaSpacing.xl),

                  _aiCard(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// En-tête du tableau de bord : titre, période et accès rapide.
  Widget _dashboardHeader(BuildContext context, double width) {
    final compact = width < 760;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bonjour 👋', style: TenaLabels.title),
        const SizedBox(height: TenaSpacing.xs),
        Text('Voici la situation de ton budget.', style: TenaLabels.subtitle),
      ],
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _monthSelector(context)),
        const SizedBox(width: TenaSpacing.sm),
        Material(
          color: TenaColors.surface,
          borderRadius: TenaRadius.md,
          child: InkWell(
            onTap: () => widget.onNavigate(2),
            borderRadius: TenaRadius.md,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: TenaRadius.md,
                border: Border.all(color: TenaColors.border),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: TenaColors.gold,
              ),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: TenaSpacing.md),
          controls,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: TenaSpacing.lg),
        controls,
      ],
    );
  }

  /// Grille Revenus / Dépenses / Budget.
  ///
  /// Le budget est calculé ici et non importé d'une page : le tableau de bord
  /// doit se suffire à lui-même, sans changement d'onglet.
  Widget _statsGrid(BuildContext context, FinanceSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 900
            ? 3
            : width >= 560
            ? 2
            : 1;

        const gap = TenaSpacing.md;

        final cardWidth = (width - gap * (columns - 1)) / columns;

        final budget = _DashboardBudget.of(summary);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            TenaStatCard(
              width: cardWidth,
              label: 'Revenus',
              value: tenaMoney(summary.income),
              icon: Icons.south_west_rounded,
              valueColor: TenaColors.success,
              hint: summary.income > 0
                  ? 'Entrés du mois'
                  : 'Aucun revenu déclaré',
            ),
            TenaStatCard(
              width: cardWidth,
              label: 'Dépenses',
              value: tenaMoney(summary.expenses),
              icon: Icons.north_east_rounded,
              valueColor: TenaColors.danger,
              hint: summary.expenses > 0
                  ? '${summary.allTransactions.length} opérations'
                  : 'Aucune dépense',
            ),
            TenaStatCard(
              width: cardWidth,
              label: 'Budget global',
              value: budget.hasBudget ? tenaMoney(budget.remaining) : '—',
              icon: Icons.account_balance_wallet_outlined,
              valueColor: budget.overBudget
                  ? TenaColors.danger
                  : TenaColors.goldLight,
              hint: budget.hint,
              hintIsWarning: budget.overBudget,
            ),
          ],
        );
      },
    );
  }

  /// Zone d'alertes intelligentes.
  ///
  /// Les alertes proviennent de [NotificationRules] et portent donc sur des
  /// faits calculés, jamais sur des textes figés. La zone disparaît
  /// entièrement lorsqu'aucune alerte n'est justifiée.
  Widget _alertsSection(FinanceSummary summary) {
    final budget = _DashboardBudget.of(summary);

    final alerts = <_DashboardAlert>[
      if (budget.overBudget)
        _DashboardAlert(
          title: 'Budget global dépassé',
          message:
              'Tu as dépassé ton budget de ${tenaMoney(-budget.remaining)} '
              'ce mois-ci.',
          severity: NotificationSeverity.critical,
          pageIndex: 1,
        )
      else if (budget.hasBudget && budget.ratio >= 0.9)
        _DashboardAlert(
          title: 'Budget bientôt atteint',
          message:
              'Tu as consommé ${(budget.ratio * 100).round()} % de ton '
              'budget global.',
          severity: NotificationSeverity.warning,
          pageIndex: 1,
        ),
      if (summary.income > 0 && summary.balance < 0)
        _DashboardAlert(
          title: 'Solde négatif',
          message:
              'Tes dépenses dépassent tes revenus de '
              '${tenaMoney(-summary.balance)}.',
          severity: NotificationSeverity.critical,
          pageIndex: 6,
        ),
    ];

    if (alerts.isEmpty) return const SizedBox.shrink();

    return TenaCard(
      padding: const EdgeInsets.all(TenaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 16,
                color: TenaColors.gold,
              ),
              const SizedBox(width: TenaSpacing.sm),
              const Expanded(
                child: Text('ALERTES', style: TenaLabels.overline),
              ),
              Text(
                '${alerts.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TenaColors.gold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: TenaSpacing.md),
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: TenaSpacing.sm),
              child: _AlertRow(
                alert: alert,
                onTap: () => widget.onNavigate(alert.pageIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section graphique, intégrée dans une carte unique.
  Widget _chartSection(
    BuildContext context,
    FinanceSummary summary,
    _DailyChart chart,
  ) {
    final hasData = chart.labels.isNotEmpty;

    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Revenus et dépenses',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (hasData)
                Text(
                  '${chart.labels.length} jour'
                  '${chart.labels.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TenaColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TenaSpacing.lg),
          if (hasData)
            FinanceChart(
              income: chart.income,
              expenses: chart.expenses,
              labels: chart.labels,
            )
          else
            const TenaEmptyState(
              icon: Icons.show_chart_rounded,
              title: 'Pas encore de données',
              message:
                  'Le graphique se remplira dès que tu enregistreras des '
                  'transactions sur ce mois.',
            ),
        ],
      ),
    );
  }

  /// Bas de page : objectifs à gauche, activité récente à droite.
  ///
  /// Sur téléphone les deux sections s'empilent.
  Widget _bottomColumns(BuildContext context, FinanceSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 860;

        final goals = _goalsSection();

        final activity = _recentSection(summary);

        if (!twoColumns) {
          return Column(
            children: [
              goals,
              const SizedBox(height: TenaSpacing.xl),
              activity,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: goals),
            const SizedBox(width: TenaSpacing.lg),
            Expanded(child: activity),
          ],
        );
      },
    );
  }

  /// Section « Objectifs » : aperçu des objectifs en cours.
  ///
  /// Les données proviennent de [GoalService] : aucun objectif n'est
  /// inventé, et la section n'affiche que l'état réel de l'épargne.
  Widget _goalsSection() {
    return TenaFutureSection(
      future: GoalService.getGoals(),
      title: 'Objectifs',
      icon: Icons.track_changes_outlined,
      emptyIcon: Icons.track_changes_outlined,
      emptyTitle: 'Aucun objectif',
      emptyMessage: 'Crée un objectif pour suivre ton épargne mois après mois.',
      emptyActionLabel: 'Créer un objectif',
      onEmptyAction: () => widget.onNavigate(4),
      builder: (context, goals) {
        if (goals.isEmpty) {
          return const TenaEmptyState(
            icon: Icons.track_changes_outlined,
            title: 'Aucun objectif',
            message:
                'Crée un objectif pour suivre ton épargne mois après mois.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OBJECTIFS', style: TenaLabels.overline),
            const SizedBox(height: TenaSpacing.md),
            ...goals
                .take(3)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: TenaSpacing.md),
                    child: _GoalPreviewRow(
                      name: goal.name,
                      saved: goal.saved,
                      target: goal.target,
                    ),
                  ),
                ),
            if (goals.length > 3)
              TextButton.icon(
                onPressed: () => widget.onNavigate(4),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Voir les ${goals.length} objectifs'),
              ),
          ],
        );
      },
    );
  }

  /// Section « Activité récente » : les dernières transactions du mois.
  Widget _recentSection(FinanceSummary summary) {
    final transactions = summary.recentTransactions;

    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('ACTIVITÉ RÉCENTE', style: TenaLabels.overline),
              ),
              if (transactions.isNotEmpty)
                TextButton(
                  onPressed: () => widget.onNavigate(2),
                  child: const Text('Tout voir'),
                ),
            ],
          ),
          const SizedBox(height: TenaSpacing.md),
          if (transactions.isEmpty)
            const TenaEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aucune transaction',
              message:
                  'Les opérations du mois s\'afficheront ici dès ton premier '
                  'enregistrement.',
            )
          else
            ...transactions.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == transactions.length - 1
                      ? 0
                      : TenaSpacing.md,
                ),
                child: _TransactionRow(transaction: entry.value),
              ),
            ),
        ],
      ),
    );
  }
}

/// Budget global ramené dans le tableau de bord.
///
/// Encapsule les calculs de reste et de dépassement, utilisés à la fois par la
/// grille de statistiques et par la zone d'alertes : sans cette classe, les
/// deux sections recalculaient le même ratio séparément.
class _DashboardBudget {
  final double budget;
  final double expenses;

  const _DashboardBudget({required this.budget, required this.expenses});

  /// Dernier budget global connu, mis à jour à chaque chargement par
  /// [_DashboardPageState] depuis [BudgetService].
  ///
  /// Le tableau de bord ne possède pas de stockage propre ; cette valeur lui
  /// est injectée plutôt que relue, afin de ne pas doubler les lectures de
  /// préférences à chaque reconstruction.
  static double lastKnown = 0;

  static _DashboardBudget of(FinanceSummary summary) {
    return _DashboardBudget(budget: lastKnown, expenses: summary.expenses);
  }

  bool get hasBudget => budget > 0;

  double get remaining => budget - expenses;

  bool get overBudget => hasBudget && remaining < 0;

  double get ratio => hasBudget ? expenses / budget : 0;

  String get hint {
    if (!hasBudget) return 'Aucun budget défini';

    if (overBudget) return 'Dépassement de ${tenaMoney(-remaining)}';

    return 'Il reste ${tenaMoney(remaining)}';
  }
}

/// Alerte affichée dans la zone d'alertes du tableau de bord.
class _DashboardAlert {
  final String title;
  final String message;
  final NotificationSeverity severity;
  final int pageIndex;

  const _DashboardAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.pageIndex,
  });

  Color get color {
    switch (severity) {
      case NotificationSeverity.info:
        return TenaColors.info;
      case NotificationSeverity.warning:
        return const Color(0xFFFBBF24);
      case NotificationSeverity.critical:
        return TenaColors.danger;
    }
  }

  IconData get icon {
    switch (severity) {
      case NotificationSeverity.info:
        return Icons.info_outline_rounded;
      case NotificationSeverity.warning:
        return Icons.warning_amber_rounded;
      case NotificationSeverity.critical:
        return Icons.error_outline_rounded;
    }
  }
}

/// Ligne d'alerte cliquable : redirige vers le module concerne.
class _AlertRow extends StatelessWidget {
  final _DashboardAlert alert;
  final VoidCallback onTap;

  const _AlertRow({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: alert.color.withValues(alpha: 0.07),
      borderRadius: TenaRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: TenaRadius.md,
        child: Container(
          padding: const EdgeInsets.all(TenaSpacing.md),
          decoration: BoxDecoration(
            borderRadius: TenaRadius.md,
            border: Border(left: BorderSide(color: alert.color, width: 3)),
          ),
          child: Row(
            children: [
              Icon(alert.icon, size: 17, color: alert.color),
              const SizedBox(width: TenaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TenaColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: TenaColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apercu d'un objectif dans le tableau de bord.
class _GoalPreviewRow extends StatelessWidget {
  final String name;
  final double saved;
  final double target;

  const _GoalPreviewRow({
    required this.name,
    required this.saved,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final reached = target > 0 && saved >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              reached
                  ? 'Atteint'
                  : '${tenaMoney(saved)} / ${tenaMoney(target)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: reached ? TenaColors.success : TenaColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: TenaSpacing.sm),
        TenaProgressBar(value: saved, total: target, height: 7),
      ],
    );
  }
}

/// Ligne de transaction du tableau de bord.
class _TransactionRow extends StatelessWidget {
  final Transaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;

    return TenaTransactionRow(
      title: transaction.description.isEmpty
          ? transaction.category
          : transaction.description,
      subtitle: transaction.category,
      amount: tenaMoney(transaction.amount),
      isIncome: isIncome,
      trailingDate:
          '${transaction.date.day.toString().padLeft(2, '0')}/'
          '${transaction.date.month.toString().padLeft(2, '0')}',
    );
  }
}

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
