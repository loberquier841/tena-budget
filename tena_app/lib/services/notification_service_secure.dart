import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/crypto_service.dart';

import 'package:tena_budget/services/budget_service.dart';
import 'package:tena_budget/services/goal_service.dart';
import 'package:tena_budget/services/finance_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/models/transaction.dart';

import 'package:tena_budget/services/notification_service.dart';
export 'package:tena_budget/services/notification_service.dart';
class NotificationService {
  static const String _key = 'tena_budget_notifications';
  static const int _maxStored = 50;
  static const int pageBudget = 1;
  static const int pageTransactions = 2;
  static const int pageGoals = 4;
  static const int pageAssistant = 6;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Determines whether a new notification with [id] should be shown,
  /// based on the time elapsed since any existing notification with the same [id].
  /// Returns true if no prior notification exists or if all prior notifications
  /// are at least [minInterval] old (or in the past). Returns false if any
  /// existing notification with the same [id] is too recent or has a future timestamp.
  static Future<bool> shouldNotify(String id,
      {Duration minInterval = const Duration(hours: 6)}) async {
    final list = await getNotifications();
    final now = DateTime.now();
    for (final n in list) {
      if (n.id == id) {
        // Treat future timestamps as recent to avoid spamming.
        if (n.createdAt.isAfter(now)) {
          return false;
        }
        final elapsed = now.difference(n.createdAt);
        if (elapsed < minInterval) {
          return false;
        }
        // This particular entry is old enough; continue checking others.
      }
    }
    // No recent/future notification found with this id.
    return true;
  }



  static Future<String> encrypt(BudgetNotification n) async {
    final json = jsonEncode(n.toJson());
    final encrypted = await CryptoService.encrypt(json);
    return 'tena1:$encrypted';
  }

  static Future<BudgetNotification> decode(String stored) async {
    if (stored.startsWith('tena1:')) {
      final plain = await CryptoService.decrypt(stored.substring(6));
      return BudgetNotification.fromJson(jsonDecode(plain));
    }
    // Legacy plaintext notification (pre‑encryption)
    return BudgetNotification.fromJson(jsonDecode(stored));
  }

  static Future<List<BudgetNotification>> getNotifications() async {
    final prefs = await _prefs();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final result = <BudgetNotification>[];
    for (final item in raw) {
      try {
        result.add(await decode(item));
      } catch (_) {
        // Corrupted entry – ignore to avoid losing the whole list.
      }
    }
    // Sort newest first
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static Future<void> _save(List<BudgetNotification> notifications) async {
    final prefs = await _prefs();
    final encrypted = await Future.wait(
      notifications.map((n) => encrypt(n)).toList(),
    );
    await prefs.setStringList(_key, encrypted);
  }

  /// Add or update a notification (upsert by id) only if allowed by shouldNotify.
  static Future<void> addNotification(BudgetNotification notification) async {
    // Check repetitiveness
    if (!await shouldNotify(notification.id)) {
      return;
    }
    final current = await getNotifications();
    final withoutDup = current.where((n) => n.id != notification.id).toList();
    final toAdd = notification.isRead
        ? notification
        : notification.copyWith(isRead: false);
    final all = <BudgetNotification>[]
      ..addAll(withoutDup)
      ..addAll([toAdd]);
    if (all.length > _maxStored) {
      all.removeRange(0, all.length - _maxStored);
    }
    await _save(all);
  }

  /// Mark a notification as read.
  static Future<void> markAsRead(String id) async {
    final list = await getNotifications();
    final updated = list.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }
      return n;
    }).toList();
    await _save(updated);
  }

  /// Get only unread notifications.
  static Future<List<BudgetNotification>> getUnreadNotifications() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).toList();
  }

  /// Mark all notifications as read.
  static Future<void> markAllAsRead() async {
    final list = await getNotifications();
    final updated = list
        .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();
    await _save(updated);
  }

  /// Clear all notifications (used for tests or reset).
  static Future<void> clearAll() async {
    final prefs = await _prefs();
    await prefs.remove(_key);
  }

  /// Existing methods preserved for compatibility.
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

  /// Vide la liste des notifications (efface le stockage).
  static Future<void> markAllRead() async {
    final prefs = await _prefs();
    await prefs.remove(_key);
  }

  static Future<void> remove(String id) async {
    final notifications = await getNotifications();
    await _save(notifications.where((n) => n.id != id).toList());
  }

  static Future<Map<String, double>> _getCategoryBudgets() async {
    final prefs = await _prefs();
    final Map<String, double> spent = await _getSpentByCategory(DateTime.now());
    final Map<String, double> budgets = <String, double>{};
    for (final category in spent.keys) {
      final budget = await BudgetService.getCategoryBudget(category);
      if (budget > 0) {
        budgets[category] = budget;
      }
    }
    return budgets;
  }

  static Future<Map<String, double>> _getSpentByCategory(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = month.month == 12
        ? DateTime(month.year + 1, 1, 1)
        : DateTime(month.year, month.month + 1, 1);
    final transactions = await DatabaseService.instance.getTransactions(
      startDate: start,
      endDate: end,
    );
    final Map<String, double> spent = <String, double>{};
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        spent[t.category] = (spent[t.category] ?? 0) + t.amount;
      }
    }
    return spent;
  }

  static Future<void> updateNotifications() async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final finance = await FinanceService.getSummaryForMonth(month);
    final spentByCategory = await _getSpentByCategory(month);
    final budgetByCategory = await _getCategoryBudgets();
    final goals = await GoalService.getGoals();

    // Budget alerts
    final budgetAlerts = NotificationRules.checkBudgets(
      spentByCategory: spentByCategory,
      budgetByCategory: budgetByCategory,
      now: now,
    );
    for (final alert in budgetAlerts) {
      await addNotification(alert);
    }

    // Negative balance alert
    final balanceAlert = NotificationRules.checkNegativeBalance(
      income: finance.income,
      expenses: finance.expenses,
      now: now,
    );
    for (final alert in balanceAlert) {
      await addNotification(alert);
    }

    // Goal alerts
    final goalAlerts = NotificationRules.checkGoals(
      goals: goals
          .map((g) => (name: g.name, target: g.target, saved: g.saved))
          .toList(),
      now: now,
    );
    for (final alert in goalAlerts) {
      await addNotification(alert);
    }
  }

  static String money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}
