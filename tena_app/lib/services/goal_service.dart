import 'dart:convert';

import 'database_service.dart' as database_service;

class Goal {
  final String id;
  final String name;
  final int targetCents;
  final int savedCents;

  const Goal({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.savedCents,
  });

  /// Montant cible en euros (pour l'affichage)
  double get targetEuros => targetCents / 100;

  /// Montant épargné en euros (pour l'affichage)
  double get savedEuros => savedCents / 100;

  /// Progression en pourcentage (0.0 à 1.0)
  double get progress => targetCents > 0 ? savedCents / targetCents : 0.0;

  Goal copyWith({String? name, int? targetCents, int? savedCents}) {
    return Goal(
      id: id,
      name: name ?? this.name,
      targetCents: targetCents ?? this.targetCents,
      savedCents: savedCents ?? this.savedCents,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetCents': targetCents,
    'savedCents': savedCents,
  };

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetCents: (json['targetCents'] as num).toInt(),
      savedCents: (json['savedCents'] as num).toInt(),
    );
  }

  /// Convertit une [GoalEntry] de la base en [Goal] pour l'interface.
  factory Goal.fromEntry(database_service.GoalEntry entry) {
    return Goal(
      id: entry.id,
      name: entry.name,
      targetCents: entry.targetCents,
      savedCents: entry.savedCents,
    );
  }
}

class GoalService {
  static final DatabaseService _db = DatabaseService.instance;

  static Future<List<Goal>> getGoals() async {
    final entries = await _db.getGoals();
    return entries.map((e) => Goal.fromEntry(e)).toList();
  }

  static Future<void> saveGoals(List<Goal> goals) async {
    for (final goal in goals) {
      await _db.insertGoal(database_service.GoalEntry(
        id: goal.id,
        name: goal.name,
        targetCents: goal.targetCents,
        savedCents: goal.savedCents,
      ));
    }
  }

  static Future<void> addGoal({
    required String name,
    required double targetEuros,
    double savedEuros = 0,
  }) async {
    final goals = await getGoals();

    goals.add(
      Goal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        targetCents: (targetEuros * 100).round(),
        savedCents: (savedEuros * 100).round(),
      ),
    );

    await saveGoals(goals);
  }

  static Future<void> updateGoal(Goal updatedGoal) async {
    await _db.insertGoal(database_service.GoalEntry(
      id: updatedGoal.id,
      name: updatedGoal.name,
      targetCents: updatedGoal.targetCents,
      savedCents: updatedGoal.savedCents,
    ));
  }

  static Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
  }
}
