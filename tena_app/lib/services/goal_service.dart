import 'dart:convert';

import 'database_service.dart' as database_service;

/// Catégorie d'objectif d'épargne
enum GoalCategory {
  emergency('Fonds d\'urgence', Icons.security),
  vacation('Vacances', Icons.beach_access),
  vehicle('Véhicule', Icons.directions_car),
  housing('Logement', Icons.home),
  education('Éducation', Icons.school),
  technology('Technologie', Icons.computer),
  health('Santé', Icons.local_hospital),
  leisure('Loisirs', Icons.sports_esports),
  other('Autre', Icons.category);

  const GoalCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static GoalCategory fromString(String value) {
    return GoalCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => GoalCategory.other,
    );
  }
}

/// Modèle d'objectif d'épargne enrichi
class Goal {
  final String id;
  final String name;
  final int targetCents;
  final int savedCents;
  final GoalCategory category;
  final DateTime? targetDate;
  final int? recurringAmountCents; // Contribution mensuelle automatique (en centimes)
  final DateTime? recurringStartDate;
  final List<int> milestones; // Pourcentages d'étapes (ex: [25, 50, 75])
  final DateTime createdAt;
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.savedCents,
    this.category = GoalCategory.other,
    this.targetDate,
    this.recurringAmountCents,
    this.recurringStartDate,
    this.milestones = const [25, 50, 75, 100],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Montant cible en euros (pour l'affichage)
  double get targetEuros => targetCents / 100;

  /// Montant épargné en euros (pour l'affichage)
  double get savedEuros => savedCents / 100;

  /// Progression en pourcentage (0.0 à 1.0)
  double get progress => targetCents > 0 ? savedCents / targetCents : 0.0;

  /// Montant restant en euros
  double get remainingEuros => (targetCents - savedCents) / 100;

  /// Montant restant en centimes
  int get remainingCents => targetCents - savedCents;

  /// Vérifie si l'objectif est atteint
  bool get isCompleted => savedCents >= targetCents;

  /// Vérifie si l'objectif a une contribution récurrente
  bool get hasRecurring => recurringAmountCents != null && recurringAmountCents! > 0;

  /// Contribution récurrente en euros
  double get recurringEuros => (recurringAmountCents ?? 0) / 100;

  /// Jours restants jusqu'à la date cible
  int? get daysRemaining {
    if (targetDate == null) return null;
    return targetDate!.difference(DateTime.now()).inDays;
  }

  /// Montant mensuel nécessaire pour atteindre l'objectif à la date cible
  double? get requiredMonthlyEuros {
    if (targetDate == null || isCompleted) return null;
    final days = daysRemaining;
    if (days == null || days <= 0) return remainingEuros;
    final months = days / 30.44;
    return remainingEuros / months;
  }

  /// Prochaine étape (milestone) à atteindre
  int? get nextMilestone {
    for (final m in milestones) {
      if (progress * 100 < m) return m;
    }
    return null;
  }

  /// Étape précédente atteinte
  int? get previousMilestone {
    int? prev;
    for (final m in milestones) {
      if (progress * 100 >= m) {
        prev = m;
      } else {
        break;
      }
    }
    return prev;
  }

  Goal copyWith({
    String? name,
    int? targetCents,
    int? savedCents,
    GoalCategory? category,
    DateTime? targetDate,
    int? recurringAmountCents,
    DateTime? recurringStartDate,
    List<int>? milestones,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id,
      name: name ?? this.name,
      targetCents: targetCents ?? this.targetCents,
      savedCents: savedCents ?? this.savedCents,
      category: category ?? this.category,
      targetDate: targetDate ?? this.targetDate,
      recurringAmountCents: recurringAmountCents ?? this.recurringAmountCents,
      recurringStartDate: recurringStartDate ?? this.recurringStartDate,
      milestones: milestones ?? this.milestones,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetCents': targetCents,
    'savedCents': savedCents,
    'category': category.name,
    'targetDate': targetDate?.toIso8601String(),
    'recurringAmountCents': recurringAmountCents,
    'recurringStartDate': recurringStartDate?.toIso8601String(),
    'milestones': milestones,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetCents: (json['targetCents'] as num).toInt(),
      savedCents: (json['savedCents'] as num).toInt(),
      category: GoalCategory.fromString(json['category'] as String? ?? 'other'),
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'] as String)
          : null,
      recurringAmountCents: (json['recurringAmountCents'] as num?)?.toInt(),
      recurringStartDate: json['recurringStartDate'] != null
          ? DateTime.parse(json['recurringStartDate'] as String)
          : null,
      milestones: (json['milestones'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [25, 50, 75, 100],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convertit une [GoalEntry] de la base en [Goal] pour l'interface.
  factory Goal.fromEntry(database_service.GoalEntry entry) {
    List<int> parsedMilestones;
    try {
      parsedMilestones = (jsonDecode(entry.milestones) as List).map((e) => (e as num).toInt()).toList();
    } catch (_) {
      parsedMilestones = [25, 50, 75, 100];
    }

    return Goal(
      id: entry.id,
      name: entry.name,
      targetCents: entry.targetCents,
      savedCents: entry.savedCents,
      category: GoalCategory.fromString(entry.category),
      targetDate: entry.targetDate != null ? DateTime.tryParse(entry.targetDate!) : null,
      recurringAmountCents: entry.recurringAmountCents,
      recurringStartDate: entry.recurringStartDate != null ? DateTime.tryParse(entry.recurringStartDate!) : null,
      milestones: parsedMilestones,
      createdAt: DateTime.tryParse(entry.createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(entry.updatedAt) ?? DateTime.now(),
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
        category: goal.category.name,
        targetDate: goal.targetDate?.toIso8601String(),
        recurringAmountCents: goal.recurringAmountCents,
        recurringStartDate: goal.recurringStartDate?.toIso8601String(),
        milestones: jsonEncode(goal.milestones),
        createdAt: goal.createdAt.toIso8601String(),
        updatedAt: goal.updatedAt.toIso8601String(),
      ));
    }
  }

  static Future<void> addGoal({
    required String name,
    required double targetEuros,
    double savedEuros = 0,
    GoalCategory category = GoalCategory.other,
    DateTime? targetDate,
    double? recurringAmountEuros,
    DateTime? recurringStartDate,
    List<int>? milestones,
  }) async {
    final goals = await getGoals();
    final now = DateTime.now();

    goals.add(
      Goal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        targetCents: (targetEuros * 100).round(),
        savedCents: (savedEuros * 100).round(),
        category: category,
        targetDate: targetDate,
        recurringAmountCents: recurringAmountEuros != null ? (recurringAmountEuros * 100).round() : null,
        recurringStartDate: recurringStartDate,
        milestones: milestones ?? [25, 50, 75, 100],
        createdAt: now,
        updatedAt: now,
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
      category: updatedGoal.category.name,
      targetDate: updatedGoal.targetDate?.toIso8601String(),
      recurringAmountCents: updatedGoal.recurringAmountCents,
      recurringStartDate: updatedGoal.recurringStartDate?.toIso8601String(),
      milestones: jsonEncode(updatedGoal.milestones),
      createdAt: updatedGoal.createdAt.toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    ));
  }

  static Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
  }
}
