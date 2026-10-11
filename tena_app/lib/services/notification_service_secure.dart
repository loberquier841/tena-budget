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
  final DateTime createdAt;
  final int pageIndex;
  final bool isRead;
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

  static String money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
}
