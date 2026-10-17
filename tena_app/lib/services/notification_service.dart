import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/crypto_service.dart';


enum NotificationSeverity {
  info,
  warning,
  critical;

  String get label {
    switch (this) {
      case NotificationSeverity.info:
        return 'Info';
      case NotificationSeverity.warning:
        return 'Vigilance';
      case NotificationSeverity.critical:
        return 'Urgent';
    }
  }
}

/// Alerte produite par les règles de gestion.
class BudgetNotification {
  final String id;
  final String title;
  final String message;
  final NotificationSeverity severity;

  /// Date de création : sert au tri, les plus récentes en premier.
  final DateTime createdAt;

  /// Page à ouvrir dans la navigation principale.
  final int pageIndex;

  /// Indique si la notification a été lue par l'utilisateur.
  final bool isRead;

  /// Date à laquelle la notification a été marquée comme lue.
  final DateTime? readAt;

  const BudgetNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.pageIndex,
    this.isRead = false,
    this.readAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'severity': severity.name,
    'createdAt': createdAt.toIso8601String(),
    'pageIndex': pageIndex,
    'isRead': isRead,
    'readAt': readAt?.toIso8601String(),
  };

  factory BudgetNotification.fromJson(Map<String, dynamic> json) {
    return BudgetNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: NotificationSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => NotificationSeverity.info,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      pageIndex: json['pageIndex'] as int? ?? 0,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
    );
  }
  BudgetNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationSeverity? severity,
    DateTime? createdAt,
    int? pageIndex,
    bool? isRead,
    DateTime? readAt,
  }) {
    return BudgetNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      pageIndex: pageIndex ?? this.pageIndex,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

}

/// Moteur de règles produisant les notifications d'application.
///
/// Chaque notification est calculée à partir de données réelles (transactions,
/// budgets, objectifs) : rien n'est affiché sans motif vérifiable.
class NotificationService {
  static const String _key = 'tena_budget_notifications';

  /// Au-delà de ce nombre, les plus anciennes sont purgées : la liste doit
  /// rester lisible et ne pas croître indéfiniment.
  static const int _maxStored = 50;

  // Index des pages de la navigation (cf. `pages` dans main.dart).
  static const int pageBudget = 1;
  static const int pageTransactions = 2;
  static const int pageGoals = 4;
  static const int pageAssistant = 6;

  static Future<SharedPreferences> _prefs() {
    return SharedPreferences.getInstance();
  }

  static Future<List<BudgetNotification>> getNotifications() async {
    final prefs = await _prefs();

    final raw = prefs.getStringList(_key) ?? const <String>[];

    final result = <BudgetNotification>[];

    for (final item in raw) {
      try {
        result.add(
          BudgetNotification.fromJson(
            Map<String, dynamic>.from(jsonDecode(item) as Map),
          ),
        );
      } catch (_) {
        // Une entrée illisible est ignorée plutôt que de faire échouer toute
        // la lecture des notifications.
      }
    }

    return result;
  }

  static Future<void> _save(List<BudgetNotification> notifications) async {
    final prefs = await _prefs();

    await prefs.setStringList(
      _key,
      notifications.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  /// Ajoute les notifications dont l'identifiant n'existe pas encore.
  ///
  /// L'identifiant stable de la règle sert de garde-fou : sans lui, la même
  /// alerte réapparaîtrait à chaque évaluation et saturerait l'écran.
  static Future<void> pushNew(List<BudgetNotification> incoming) async {
    if (incoming.isEmpty) return;

    final existing = await getNotifications();
    final known = existing.map((n) => n.id).toSet();

    final fresh = incoming.where((n) => !known.contains(n.id)).toList();

    if (fresh.isEmpty) return;

    final merged = [...fresh, ...existing]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _save(merged.take(_maxStored).toList());
  }

  /// Vide la liste des notifications.
  static Future<void> markAllRead() async {
    final prefs = await _prefs();

    await prefs.remove(_key);
  }

  static Future<void> remove(String id) async {
    final notifications = await getNotifications();

    await _save(notifications.where((n) => n.id != id).toList());
  }

  static String money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}

/// Règles de gestion, exposées séparément pour être testées sans passer par le
/// stockage des notifications.
class NotificationRules {
  /// Évalue les dépassements de budget par catégorie.
  ///
  /// Une catégorie sans budget défini (0) ne produit aucune alerte : on ne peut
  /// pas comparer une dépense à une limite inexistante.
  static List<BudgetNotification> checkBudgets({
    required Map<String, double> spentByCategory,
    required Map<String, double> budgetByCategory,
    required DateTime now,
  }) {
    final notifications = <BudgetNotification>[];

    for (final entry in spentByCategory.entries) {
      final budget = budgetByCategory[entry.key] ?? 0;

      if (budget <= 0) continue;

      final ratio = entry.value / budget;

      if (ratio >= 1) {
        notifications.add(
          BudgetNotification(
            id: 'budget_depense_${entry.key}',
            title: 'Budget dépassé : ${entry.key}',
            message:
                'Tu as dépensé ${NotificationService.money(entry.value)} pour '
                'un budget de ${NotificationService.money(budget)}. '
                'Dépense excédentaire : '
                '${NotificationService.money(entry.value - budget)}.',
            severity: NotificationSeverity.critical,
            createdAt: now,
            pageIndex: NotificationService.pageBudget,
          ),
        );
      } else if (ratio >= 0.9) {
        notifications.add(
          BudgetNotification(
            id: 'budget_proche_${entry.key}',
            title: 'Budget bientôt atteint : ${entry.key}',
            message:
                'Tu as utilisé ${(ratio * 100).round()} % du budget '
                '${entry.key} '
                '(${NotificationService.money(entry.value)} / '
                '${NotificationService.money(budget)}).',
            severity: NotificationSeverity.warning,
            createdAt: now,
            pageIndex: NotificationService.pageBudget,
          ),
        );
      }
    }

    return notifications;
  }

  /// Alerte sur un solde mensuel négatif.
  ///
  /// Sans revenu déclaré, le solde est mécaniquement négatif et l'alerte
  /// n'aurait aucun sens : la règle est donc muette.
  static List<BudgetNotification> checkNegativeBalance({
    required double income,
    required double expenses,
    required DateTime now,
  }) {
    if (income <= 0 || expenses <= income) return const [];

    return [
      BudgetNotification(
        id: 'solde_negatif',
        title: 'Solde négatif ce mois-ci',
        message:
            'Tes dépenses (${NotificationService.money(expenses)}) dépassent '
            'tes revenus (${NotificationService.money(income)}) de '
            '${NotificationService.money(expenses - income)}.',
        severity: NotificationSeverity.critical,
        createdAt: now,
        pageIndex: NotificationService.pageAssistant,
      ),
    ];
  }

  /// Signale les objectifs atteints ou presque atteints.
  static List<BudgetNotification> checkGoals({
    required List<({String name, double target, double saved})> goals,
    required DateTime now,
  }) {
    final notifications = <BudgetNotification>[];

    for (final goal in goals) {
      if (goal.target <= 0) continue;

      final ratio = goal.saved / goal.target;

      if (ratio >= 1) {
        notifications.add(
          BudgetNotification(
            id: 'objectif_atteint_${goal.name}',
            title: 'Objectif atteint : ${goal.name}',
            message:
                'Tu as épargné les ${NotificationService.money(goal.target)} '
                'pour « ${goal.name} ».',
            severity: NotificationSeverity.info,
            createdAt: now,
            pageIndex: NotificationService.pageGoals,
          ),
        );
      } else if (ratio >= 0.8) {
        notifications.add(
          BudgetNotification(
            id: 'objectif_proche_${goal.name}',
            title: 'Objectif presque atteint : ${goal.name}',
            message:
                '${(ratio * 100).round()} % de « ${goal.name} » épargnés '
                '(${NotificationService.money(goal.saved)} / '
                '${NotificationService.money(goal.target)}).',
            severity: NotificationSeverity.warning,
            createdAt: now,
            pageIndex: NotificationService.pageGoals,
          ),
        );
      }
    }

    return notifications;
  }
}
