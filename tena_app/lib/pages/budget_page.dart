import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

class BudgetPage extends StatefulWidget {
  final DateTime month;

  const BudgetPage({super.key, required this.month});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final DatabaseService _database = DatabaseService.instance;

  List<String> _categories = [];
  List<Transaction> _transactions = [];

  /// Budgets par catégorie, chargés une seule fois par chargement.
  /// Auparavant un FutureBuilder était créé directement dans build(), ce qui
  /// relisait les préférences à chaque reconstruction et faisait clignoter les
  /// cartes au premier affichage.
  Map<String, double> _categoryBudgets = {};

  double _globalBudget = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BudgetPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _load();
    }
  }

  Future<void> _load() async {
    final categories = await CategoryService.getCategories();
    final transactions = await _database.getTransactions();
    final globalBudget = await BudgetService.getGlobalBudget();

    final categoryBudgets = <String, double>{};

    for (final category in categories) {
      categoryBudgets[category] =
          await BudgetService.getCategoryBudget(category);
    }

    if (!mounted) return;

    setState(() {
      _categories = categories;
      _transactions = transactions;
      _globalBudget = globalBudget;
      _categoryBudgets = categoryBudgets;
      _loading = false;
    });
  }

  List<Transaction> get _monthExpenses {
    return _transactions.where((transaction) {
      return transaction.type == TransactionType.expense &&
          transaction.date.year == widget.month.year &&
          transaction.date.month == widget.month.month;
    }).toList();
  }

  double get _totalExpenses {
    return _monthExpenses.fold(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
  }

  double _categorySpent(String category) {
    return _monthExpenses
        .where((transaction) => transaction.category == category)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  String _monthName() {
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

    return '${months[widget.month.month - 1]} ${widget.month.year}';
  }

  Future<void> _editGlobalBudget() async {
    final controller = TextEditingController(
      text: _globalBudget == 0
          ? ''
          : _globalBudget.toStringAsFixed(2).replaceAll('.', ','),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Budget mensuel global'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant',
              suffixText: '€',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );

                if (amount == null || amount < 0) return;

                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null) return;

    await BudgetService.setGlobalBudget(value);
    await _load();
  }

  Future<void> _editCategoryBudget(String category) async {
    final current = await BudgetService.getCategoryBudget(category);

    if (!mounted) return;

    final controller = TextEditingController(
      text: current == 0 ? '' : current.toStringAsFixed(2).replaceAll('.', ','),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Budget : $category'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant mensuel',
              suffixText: '€',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );

                if (amount == null || amount < 0) return;

                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null) return;

    await BudgetService.setCategoryBudget(category, value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final globalRemaining = _globalBudget - _totalExpenses;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(TenaSpacing.lg),
          children: [
            // En-tête repliable sur téléphone : le titre et le bouton côte à
            // côte débordaient sous 420 px de large.
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;

                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Budget', style: TenaLabels.title),
                    const SizedBox(height: TenaSpacing.xs),
                    Text(
                      '${_monthName()} — contrôle ton budget mensuel.',
                      style: TenaLabels.subtitle,
                    ),
                  ],
                );

                final action = OutlinedButton.icon(
                  onPressed: _editGlobalBudget,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Budget global'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: TenaSpacing.md),
                      action,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: TenaSpacing.lg),
                    action,
                  ],
                );
              },
            ),

            const SizedBox(height: TenaSpacing.xl),

            _globalBudgetCard(globalRemaining),

            const SizedBox(height: TenaSpacing.xxl),

            const TenaSectionTitle(
              title: 'Budgets par catégorie',
              subtitle: 'Touche une catégorie pour ajuster son plafond.',
              icon: Icons.category_outlined,
            ),

            const SizedBox(height: TenaSpacing.md),

            ..._categories.map(_categoryCard),
          ],
        ),
      ),
    );
  }

  /// Carte récapitulative du budget global.
  Widget _globalBudgetCard(double remaining) {
    // Sans budget défini, la carte doit inciter à le créer plutôt que
    // d'afficher une barre vide qui ne veut rien dire.
    if (_globalBudget <= 0) {
      return TenaCard(
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
                    'Aucun budget global',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fixe un plafond mensuel pour suivre ta consommation et '
                    'recevoir des alertes.',
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

    final overBudget = remaining < 0;

    return TenaCard(
      highlighted: overBudget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BUDGET GLOBAL', style: TenaLabels.overline),
          const SizedBox(height: TenaSpacing.md),
          TenaAmountRow(
            label: 'Dépensé',
            value: tenaMoney(_totalExpenses),
            suffix: '/ ${tenaMoney(_globalBudget)}',
            emphasize: true,
            valueColor: overBudget
                ? TenaColors.danger
                : TenaColors.textPrimary,
          ),
          const SizedBox(height: TenaSpacing.lg),
          TenaProgressBar(
            value: _totalExpenses,
            total: _globalBudget,
            height: 12,
          ),
          const SizedBox(height: TenaSpacing.md),
          Row(
            children: [
              Icon(
                overBudget
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 16,
                color: overBudget
                    ? TenaColors.danger
                    : TenaColors.success,
              ),
              const SizedBox(width: TenaSpacing.sm),
              Expanded(
                child: Text(
                  overBudget
                      ? 'Dépassement de ${tenaMoney(-remaining)}'
                      : 'Il reste ${tenaMoney(remaining)} pour ce mois',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: overBudget
                        ? TenaColors.danger
                        : TenaColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte d'une catégorie : toute la surface est cliquable pour éditer le
  /// budget, l'icône d'édition étant difficile à toucher sur petit écran.
  Widget _categoryCard(String category) {
    final budget = _categoryBudgets[category] ?? 0;
    final spent = _categorySpent(category);
    final remaining = budget - spent;
    final overBudget = budget > 0 && remaining < 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: TenaSpacing.md),
      child: TenaCard(
        highlighted: overBudget,
        onTap: () => _editCategoryBudget(category),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: TenaSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: TenaColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: TenaSpacing.md),
            TenaAmountRow(
              label: 'Dépensé',
              value: tenaMoney(spent),
              suffix: budget > 0 ? '/ ${tenaMoney(budget)}' : null,
            ),
            const SizedBox(height: TenaSpacing.md),
            if (budget > 0) ...[
              TenaProgressBar(value: spent, total: budget),
              const SizedBox(height: TenaSpacing.md),
            ],
            Text(
              budget <= 0
                  ? 'Aucun budget — touche pour en définir un'
                  : remaining >= 0
                  ? 'Il reste ${tenaMoney(remaining)}'
                  : 'Dépassement de ${tenaMoney(-remaining)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: budget <= 0
                    ? TenaColors.textTertiary
                    : overBudget
                    ? TenaColors.danger
                    : TenaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
