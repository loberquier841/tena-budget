import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/category_service.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final DatabaseService _database = DatabaseService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Transaction> _transactions = [];
  bool _loading = true;
  String _search = '';
  TransactionType? _filterType;
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    final transactions = await _database.getTransactions();

    if (!mounted) return;

    setState(() {
      _transactions = transactions;
      _loading = false;
    });
  }

  List<Transaction> get _filteredTransactions {
    final result = _transactions.where((transaction) {
      final matchesType =
          _filterType == null || transaction.type == _filterType;

      final text = [
        transaction.category,
        transaction.description,
      ].join(' ').toLowerCase();

      final matchesSearch = _search.isEmpty || text.contains(_search);

      return matchesType && matchesSearch;
    }).toList();

    result.sort((a, b) {
      final comparison = a.date.compareTo(b.date);
      return _newestFirst ? -comparison : comparison;
    });

    return result;
  }

  double get _income {
    return _filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get _expenses {
    return _filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get _balance => _income - _expenses;

  String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  Future<void> _addTransaction() async {
    final result = await showDialog<Transaction>(
      context: context,
      builder: (context) => const _TransactionDialog(),
    );

    if (result == null) return;

    await _database.insertTransaction(result);
    await _loadTransactions();
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final result = await showDialog<Transaction>(
      context: context,
      builder: (context) => _TransactionDialog(transaction: transaction),
    );

    if (result == null) return;

    await _database.updateTransaction(result);
    await _loadTransactions();
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la transaction ?'),
          content: Text(
            'Cette action supprimera définitivement « '
            '${transaction.description.isEmpty ? transaction.category : transaction.description} ».',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _database.deleteTransaction(transaction.id);
    await _loadTransactions();
  }

  String _date(Transaction transaction) {
    final date = transaction.date;

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleTransactions = _filteredTransactions;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('Gère tes revenus et tes dépenses.'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addTransaction,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCard(
                  title: 'Revenus',
                  value: _money(_income),
                  icon: Icons.arrow_downward,
                ),
                _SummaryCard(
                  title: 'Dépenses',
                  value: _money(_expenses),
                  icon: Icons.arrow_upward,
                ),
                _SummaryCard(
                  title: 'Solde',
                  value: _money(_balance),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une transaction...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<TransactionType?>(
                  tooltip: 'Filtrer',
                  onSelected: (value) {
                    setState(() {
                      _filterType = value;
                    });
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: null, child: Text('Toutes')),
                    PopupMenuItem(
                      value: TransactionType.expense,
                      child: Text('Dépenses'),
                    ),
                    PopupMenuItem(
                      value: TransactionType.income,
                      child: Text('Revenus'),
                    ),
                  ],
                  child: const IconButton(
                    onPressed: null,
                    icon: Icon(Icons.filter_list),
                  ),
                ),
                IconButton(
                  tooltip: _newestFirst
                      ? 'Plus anciennes d’abord'
                      : 'Plus récentes d’abord',
                  onPressed: () {
                    setState(() {
                      _newestFirst = !_newestFirst;
                    });
                  },
                  icon: Icon(
                    _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleTransactions.isEmpty
                  ? Center(
                      child: Text(
                        _transactions.isEmpty
                            ? 'Aucune transaction pour le moment.'
                            : 'Aucune transaction ne correspond aux filtres.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleTransactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final transaction = visibleTransactions[index];

                        final isIncome =
                            transaction.type == TransactionType.income;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                              ),
                            ),
                            title: Text(
                              transaction.description.isEmpty
                                  ? transaction.category
                                  : transaction.description,
                            ),
                            subtitle: Text(
                              '${transaction.category} • ${_date(transaction)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isIncome ? '+' : '-'}'
                                  '${_money(transaction.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editTransaction(transaction);
                                    } else if (value == 'delete') {
                                      _deleteTransaction(transaction);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Modifier'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline),
                                        title: Text('Supprimer'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
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

class _TransactionDialog extends StatefulWidget {
  final Transaction? transaction;

  const _TransactionDialog({this.transaction});

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late TransactionType _type;
  late DateTime _date;

  List<String> _categories = [];
  String? _selectedCategory;

  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    _amountController = TextEditingController(
      text: transaction?.amount.toString().replaceAll('.', ',') ?? '',
    );

    _selectedCategory = transaction?.category;

    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );

    _type = transaction?.type ?? TransactionType.expense;
    _date = transaction?.date ?? DateTime.now();

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await CategoryService.getCategories();

    if (!mounted) return;

    setState(() {
      _categories = categories;

      if (_selectedCategory != null &&
          !_categories.contains(_selectedCategory)) {
        _categories = [_selectedCategory!, ..._categories];
      }

      if (_selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) return;

    setState(() {
      _date = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    final transaction = Transaction(
      id:
          widget.transaction?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      category: _selectedCategory ?? '',
      description: _descriptionController.text.trim(),
      date: _date,
      type: _type,
    );

    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _editing ? 'Modifier la transaction' : 'Nouvelle transaction',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Dépense'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Revenu'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() {
                    _type = selection.first;
                  });
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: '€',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    value?.replaceAll(',', '.') ?? '',
                  );

                  if (amount == null || amount <= 0) {
                    return 'Entre un montant valide.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                // `initialValue` remplace `value` (déprécié depuis v3.33).
                // Le dialogue étant recréé à chaque ouverture, la valeur
                // initiale est toujours correctement appliquée.
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Choisis une catégorie.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optionnel',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(
                  '${_date.day.toString().padLeft(2, '0')}/'
                  '${_date.month.toString().padLeft(2, '0')}/'
                  '${_date.year}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _chooseDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_editing ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
