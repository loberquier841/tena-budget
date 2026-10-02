import 'package:flutter/material.dart';

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
      target: result.target,
      saved: result.saved,
    );

    await _load();
  }

  Future<void> _editGoal(Goal goal) async {
    final result = await _showGoalDialog(goal: goal);

    if (result == null) return;

    await GoalService.updateGoal(
      goal.copyWith(
        name: result.name,
        target: result.target,
        saved: result.saved,
      ),
    );

    await _load();
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l’objectif ?'),
          content: Text('L’objectif « ${goal.name} » sera supprimé.'),
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
              : goal.target.toStringAsFixed(2).replaceAll('.', ','),
        );
        final savedController = TextEditingController(
          text: goal == null
              ? '0'
              : goal.saved.toStringAsFixed(2).replaceAll('.', ','),
        );

        return AlertDialog(
          title: Text(goal == null ? 'Nouvel objectif' : 'Modifier l’objectif'),
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
                TextField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant cible',
                    suffixText: '€',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Déjà épargné',
                    suffixText: '€',
                    border: OutlineInputBorder(),
                  ),
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
                final target = double.tryParse(
                  targetController.text.replaceAll(',', '.'),
                );
                final saved = double.tryParse(
                  savedController.text.replaceAll(',', '.'),
                );

                if (name.isEmpty ||
                    target == null ||
                    target <= 0 ||
                    saved == null ||
                    saved < 0) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _GoalFormResult(name: name, target: target, saved: saved),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
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
                        'Objectifs',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('Prépare et suis tes projets financiers.'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addGoal,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvel objectif'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_goals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.track_changes_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun objectif',
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
                ),
              )
            else
              ..._goals.map((goal) {
                final progress = goal.target <= 0
                    ? 0.0
                    : (goal.saved / goal.target).clamp(0.0, 1.0);

                final remaining = goal.target - goal.saved;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.name,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
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
                              _money(goal.saved),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('/ ${_money(goal.target)}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: progress, minHeight: 10),
                        const SizedBox(height: 10),
                        Text(
                          remaining > 0
                              ? 'Il reste ${_money(remaining)}'
                              : 'Objectif atteint 🎉',
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

class _GoalFormResult {
  final String name;
  final double target;
  final double saved;

  const _GoalFormResult({
    required this.name,
    required this.target,
    required this.saved,
  });
}
