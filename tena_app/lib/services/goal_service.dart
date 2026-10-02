import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
}

class GoalService {
  static const String _key = 'tena_budget_goals';

  static Future<List<Goal>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(data) as List;

      return list
          .map((item) => Goal.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveGoals(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _key,
      jsonEncode(goals.map((goal) => goal.toJson()).toList()),
    );
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
    final goals = await getGoals();

    final index = goals.indexWhere((goal) => goal.id == updatedGoal.id);

    if (index == -1) return;

    goals[index] = updatedGoal;

    await saveGoals(goals);
  }

  static Future<void> deleteGoal(String id) async {
    final goals = await getGoals();

    goals.removeWhere((goal) => goal.id == id);

    await saveGoals(goals);
  }
}
