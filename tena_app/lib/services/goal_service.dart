import 'dart:convert';

import 'database_service.dart' as database_service;

class Goal {
  final String id;
  final String name;
  final double target;
  final double saved;

  const Goal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
  });

  Goal copyWith({String? name, double? target, double? saved}) {
    return Goal(
      id: id,
      name: name ?? this.name,
      target: target ?? this.target,
      saved: saved ?? this.saved,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'saved': saved,
  };

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      name: json['name'] as String,
      target: (json['target'] as num).toDouble(),
      saved: (json['saved'] as num).toDouble(),
    );
  }

  /// Convertit une [GoalEntry] de la base en [Goal] pour l'interface.
  factory Goal.fromEntry(database_service.GoalEntry entry) {
    return Goal(
      id: entry.id,
      name: entry.name,
      target: entry.targetCents,
      saved: entry.savedCents,
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
        targetCents: goal.target,
        savedCents: goal.saved,
      ));
    }
  }

  static Future<void> addGoal({
    required String name,
    required double target,
    double saved = 0,
  }) async {
    final goals = await getGoals();

    goals.add(
      Goal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        target: target,
        saved: saved,
      ),
    );

    await saveGoals(goals);
  }

  static Future<void> updateGoal(Goal updatedGoal) async {
    await _db.insertGoal(database_service.GoalEntry(
      id: updatedGoal.id,
      name: updatedGoal.name,
      targetCents: updatedGoal.target,
      savedCents: updatedGoal.saved,
    ));
  }

  static Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
  }
}
