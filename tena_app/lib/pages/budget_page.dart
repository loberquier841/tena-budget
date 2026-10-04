import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';

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

  String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
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
    final globalProgress = _globalBudget <= 0
        ? 0.0
        : (_totalExpenses / _globalBudget).clamp(0.0, 1.0);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('Contrôle ton budget mensuel.'),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _editGlobalBudget,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Budget global'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(_monthName(), style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget global',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _money(_totalExpenses),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _globalBudget > 0
                              ? '/ ${_money(_globalBudget)}'
                              : 'Aucun budget défini',
                          style: const TextStyle(
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: globalProgress,
                      minHeight: 12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _globalBudget > 0
                          ? globalRemaining >= 0
                                ? 'Il reste ${_money(globalRemaining)}'
                                : 'Dépassement de ${_money(-globalRemaining)}'
                          : 'Définis un budget global pour suivre ton mois.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Budgets par catégorie',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ..._categories.map((category) {
              final budget = _categoryBudgets[category] ?? 0;
              final spent = _categorySpent(category);
              final remaining = budget - spent;
              final progress = budget <= 0
                  ? 0.0
                  : (spent / budget).clamp(0.0, 1.0);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            budget > 0
                                ? '${_money(spent)} / ${_money(budget)}'
                                : _money(spent),
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editCategoryBudget(category),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          budget <= 0
                              ? 'Aucun budget défini'
                              : remaining >= 0
                              ? 'Reste ${_money(remaining)}'
                              : 'Dépassement de ${_money(-remaining)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
