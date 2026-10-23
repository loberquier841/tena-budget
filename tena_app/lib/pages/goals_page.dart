import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/goal_service.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<Goal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await GoalService.getGoals();

    if (!mounted) return;

    setState(() {
      _goals = goals;
      _loading = false;
    });
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  Future<void> _addGoal() async {
    final result = await _showGoalDialog();

    if (result == null) return;

    await GoalService.addGoal(
      name: result.name,
      targetEuros: result.targetEuros,
      savedEuros: result.savedEuros,
      category: result.category,
      targetDate: result.targetDate,
      recurringAmountEuros: result.recurringAmountEuros,
      recurringStartDate: result.recurringStartDate,
      milestones: result.milestones,
    );

    await _load();
  }

  Future<void> _editGoal(Goal goal) async {
    final result = await _showGoalDialog(goal: goal);

    if (result == null) return;

    await GoalService.updateGoal(
      goal.copyWith(
        name: result.name,
        targetCents: (result.targetEuros * 100).round(),
        savedCents: (result.savedEuros * 100).round(),
        category: result.category,
        targetDate: result.targetDate,
        recurringAmountCents: result.recurringAmountEuros != null ? (result.recurringAmountEuros! * 100).round() : null,
        recurringStartDate: result.recurringStartDate,
        milestones: result.milestones,
      ),
    );

    await _load();
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l'objectif ?'),
          content: Text('L'objectif « ${goal.name} » sera supprimé.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await GoalService.deleteGoal(goal.id);
    await _load();
  }

  Future<_GoalFormResult?> _showGoalDialog({Goal? goal}) async {
    return showDialog<_GoalFormResult>(
      context: context,
      builder: (dialogContext) {
        final nameController = TextEditingController(text: goal?.name ?? '');
        final targetController = TextEditingController(
          text: goal == null
              ? ''
              : goal.targetEuros.toStringAsFixed(2).replaceAll('.', ','),
        );
        final savedController = TextEditingController(
          text: goal == null
              ? '0'
              : goal.savedEuros.toStringAsFixed(2).replaceAll('.', ','),
        );
        final recurringAmountController = TextEditingController(
          text: goal?.recurringAmountEuros == null
              ? ''
              : goal!.recurringAmountEuros!.toStringAsFixed(2).replaceAll('.', ','),
        );

        GoalCategory selectedCategory = goal?.category ?? GoalCategory.other;
        DateTime? selectedTargetDate = goal?.targetDate;
        DateTime? selectedRecurringStartDate = goal?.recurringStartDate;
        List<int> selectedMilestones = goal?.milestones ?? [25, 50, 75, 100];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(goal == null ? 'Nouvel objectif' : 'Modifier l'objectif'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        hintText: 'Ex. Nouveau PC',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<GoalCategory>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                      items: GoalCategory.values.map((cat) {
                        return DropdownMenuItem<GoalCategory>(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(cat.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(cat.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant cible',
                        suffixText: '€',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: savedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Déjà épargné',
                        suffixText: '€',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date cible (optionnel)'),
                      subtitle: Text(
                        selectedTargetDate != null
                            ? DateFormat('dd/MM/yyyy').format(selectedTargetDate!)
                            : 'Aucune date',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedTargetDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedTargetDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: recurringAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Contribution mensuelle auto. (optionnel)',
                        suffixText: '€/mois',
                        border: OutlineInputBorder(),
                        hintText: 'Ex. 100 pour 100€/mois',
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (recurringAmountController.text.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.repeat),
                        title: const Text('Début de la récurrence (optionnel)'),
                        subtitle: Text(
                          selectedRecurringStartDate != null
                              ? DateFormat('dd/MM/yyyy').format(selectedRecurringStartDate!)
                              : 'Mois prochain',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedRecurringStartDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedRecurringStartDate = picked;
                            });
                          }
                        },
                      ),

                    const SizedBox(height: 16),
                    const Text(
                      'Étapes (jalons) : 25%, 50%, 75%, 100%',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final target = double.tryParse(targetController.text.replaceAll(',', '.'));
                    final saved = double.tryParse(savedController.text.replaceAll(',', '.'));

                    if (name.isEmpty || target == null || target <= 0 || saved == null || saved < 0) {
                      return;
                    }

                    double? recurringAmount;
                    if (recurringAmountController.text.isNotEmpty) {
                      recurringAmount = double.tryParse(recurringAmountController.text.replaceAll(',', '.'));
                      if (recurringAmount == null || recurringAmount <= 0) {
                        return;
                      }
                    }

                    Navigator.pop(
                      dialogContext,
                      _GoalFormResult(
                        name: name,
                        targetEuros: target,
                        savedEuros: saved,
                        category: selectedCategory,
                        targetDate: selectedTargetDate,
                        recurringAmountEuros: recurringAmount,
                        recurringStartDate: selectedRecurringStartDate,
                        milestones: selectedMilestones,
                      ),
                    );
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objectifs d'épargne'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        child: const Icon(Icons.add),
      ),
      body: _goals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun objectif pour l'instant',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crée ton premier objectif pour commencer à suivre ton épargne.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._goals.map((goal) {
                  final progress = goal.progress;
                  final remainingCents = goal.targetCents - goal.savedCents;
                  final remainingEuros = remainingCents / 100;
                  final daysLeft = goal.daysRemaining;
                  final requiredMonthly = goal.requiredMonthlyEuros;
                  final nextMilestone = goal.nextMilestone;
                  final prevMilestone = goal.previousMilestone;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  goal.category.icon,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      goal.category.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _editGoal(goal),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deleteGoal(goal),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _money(goal.savedEuros),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('/ ${_money(goal.targetEuros)}'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: progress, minHeight: 10),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              if (remainingEuros > 0)
                                Text(
                                  'Il reste ${_money(remainingEuros)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                )
                              else
                                const Text(
                                  'Objectif atteint 🎉',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (daysLeft != null && daysLeft > 0)
                                Text('📅 $daysLeft j'),
                              if (requiredMonthly != null && requiredMonthly > 0)
                                Text('💰 ${_money(requiredMonthly)}/mois'),
                              if (nextMilestone != null)
                                Text('🎯 Prochain: $nextMilestone%'),
                              if (prevMilestone != null)
                                Text('✅ $prevMilestone% atteint'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _GoalFormResult {
  final String name;
  final double targetEuros;
  final double savedEuros;
  final GoalCategory category;
  final DateTime? targetDate;
  final double? recurringAmountEuros;
  final DateTime? recurringStartDate;
  final List<int> milestones;

  const _GoalFormResult({
    required this.name,
    required this.targetEuros,
    required this.savedEuros,
    required this.category,
    this.targetDate,
    this.recurringAmountEuros,
    this.recurringStartDate,
    required this.milestones,
  });
}
