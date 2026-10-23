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

  /// Affiche aussi les transactions supprimées (suppression logique).
  bool _showDeleted = false;

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
    final transactions = await _database.getTransactions(
      includeDeleted: _showDeleted,
    );

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
        transaction.notes,
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
    if (transaction.isDeleted) {
      await _confirmPurge(transaction);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la transaction ?'),
          content: Text(
            '« '
            '${transaction.description.isEmpty ? transaction.category : transaction.description}'
            ' » sera déplacée dans les transactions supprimées. Vous pourrez la '
            'restaurer à tout moment : aucune donnée n’est perdue.',
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

  Future<void> _restoreTransaction(Transaction transaction) async {
    await _database.restoreTransaction(transaction.id);
    await _loadTransactions();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction restaurée.')),
    );
  }

  /// Suppression définitive : elle est réservée à l'effacement explicite
  /// demandé par l'utilisateur et n'est jamais proposée par défaut.
  Future<void> _confirmPurge(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer définitivement ?'),
          content: const Text(
            'Cette transaction sera effacée de la base. Cette action est '
            'irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer définitivement'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _database.purgeTransaction(transaction.id);
    await _loadTransactions();
  }

  /// Actions proposées pour une transaction, qui dépendent de son état :
  /// une transaction supprimée peut être restaurée ou effacée, plus jamais
  /// modifiée.
  List<PopupMenuEntry<String>> _menuItems(Transaction transaction) {
    if (transaction.isDeleted) {
      return const [
        PopupMenuItem(
          value: 'restore',
          child: ListTile(
            leading: Icon(Icons.restore),
            title: Text('Restaurer'),
          ),
        ),
        PopupMenuItem(
          value: 'purge',
          child: ListTile(
            leading: Icon(Icons.delete_forever),
            title: Text('Supprimer définitivement'),
          ),
        ),
      ];
    }

    return const [
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
    ];
  }

  /// Ligne secondaire de la liste : catégorie, date, note et état.
  String _subtitle(Transaction transaction) {
    final base = '${transaction.category} • ${_date(transaction)}';

    if (transaction.isDeleted) return '$base • supprimée';

    if (transaction.notes.isNotEmpty) return '$base • ${transaction.notes}';

    return base;
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
                FilterChip(
                  label: const Text('Supprimées'),
                  avatar: const Icon(Icons.restore, size: 18),
                  selected: _showDeleted,
                  onSelected: (selected) {
                    setState(() {
                      _showDeleted = selected;
                    });

                    _loadTransactions();
                  },
                ),
                const SizedBox(width: 12),
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
                              _subtitle(transaction),
                              style: TextStyle(
                                fontStyle: transaction.isDeleted
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: transaction.isDeleted
                                    ? Theme.of(context)
                                          .colorScheme
                                          .outline
                                    : null,
                              ),
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
                                    } else if (value == 'restore') {
                                      _restoreTransaction(transaction);
                                    } else if (value == 'purge') {
                                      _confirmPurge(transaction);
                                    }
                                  },
                                  itemBuilder: (context) =>
                                      _menuItems(transaction),
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

void _showExportImportMenu() {
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Export / Import CSV',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _exportTransactions,
                  child: const Text('Exporter'),
                  icon: const Icon(Icons.download),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _importTransactions,
                  child: const Text('Importer'),
                  icon: const Icon(Icons.upload),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Format CSV colonnes: id, amount, category, description, date (yyyy-MM-dd), type (income/expense), isDeleted, notes',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Future<void> _exportTransactions() async {
  final csvData = await _database.exportTransactionsToCsv();
  // Write to a simple location accessible for demo purposes
  final String filePath = '/tena_transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
  // Note: In a full app, use path_provider for proper platform-specific paths
  // For now, we just verify the CSV can be generated
  if (csvData.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV généré avec ${csvData.length} caractères - enregistrement manuel requis')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text'Aucune transaction à exporter')),
  );
}

Future<void> _importTransactions() async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Importer des transactions'),
      content: const Text(
        'Sélectionnez un fichier CSV exporté depuis TENΛ Budget.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _importSampleCsv();
          },
          child: const Text('Essayer un exemple'),
        ),
      ],
    ),
  );
}

Future<void> _importSampleCsv() async {
  final csvData = '''id,amount,category,description,date,type,isDeleted,notes
tx1,100.50,Alimentation,Course du dimanche,2024-01-15,expense,0,Course hebdo
tx2,200.00,Salaire,Revenus du mois,2024-01-01,income,0,Salaire net
tx3,30.99,Transport,Bus du travail,2024-01-10,expense,0,Pass monthly''';
  final int imported = await _database.importTransactionsFromCsv(csvData);
  _loadTransactions();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$imported transactions importées')),
  );
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
  late final TextEditingController _notesController;

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

    _notesController = TextEditingController(text: transaction?.notes ?? '');

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
    _notesController.dispose();
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
      notes: _notesController.text.trim(),
      // Une transaction supprimée puis restaurée conserve son état d'origine :
      // sans cela, la ré-enregistrement la ferait repasser pour supprimée.
      isDeleted: widget.transaction?.isDeleted ?? false,
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

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Facture, référence, commentaire...',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showExportImportMenu,
        tooltip: 'Export/Import',
        child: const Icon(Icons.upload_file),
      ),
      floatingActionButtonLocation: FloatingActionButton.endFloat,
    );
  }
}
