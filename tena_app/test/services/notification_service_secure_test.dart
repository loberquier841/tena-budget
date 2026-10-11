import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/notification_service_secure.dart';
import 'package:tena_budget/services/crypto_service.dart';

import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String testKey = 'tena_budget_notifications_test';

  // Override the _key used by the service for isolation.
  // We'll use a wrapper or we can just rely on the fact that we clear before each test.
  // Since the service uses a hardcoded _key, we need to clear it before each test.

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  test('encrypt and decrypt roundtrip', () async {
    final notification = BudgetNotification(
      id: 'test1',
      title: 'Test',
      message: 'Test message',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1, 12, 0),
      pageIndex: 0,
    );

    final encrypted = await NotificationService.encrypt(notification);
    expect(encrypted, startsWith('tena1:'));

    final decrypted = await NotificationService.decode(encrypted);
    expect(decrypted.id, notification.id);
    expect(decrypted.title, notification.title);
    expect(decrypted.message, notification.message);
    expect(decrypted.severity, notification.severity);
    expect(decrypted.createdAt, notification.createdAt);
    expect(decrypted.pageIndex, notification.pageIndex);
    expect(decrypted.isRead, notification.isRead);
    expect(decrypted.readAt, notification.readAt);
  });

  test('getNotifications returns empty list initially', () async {
    final list = await NotificationService.getNotifications();
    expect(list, isEmpty);
  });

  test('addNotification stores and retrieves', () async {
    final n1 = BudgetNotification(
      id: 'id1',
      title: 'First',
      message: 'First msg',
      severity: NotificationSeverity.warning,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 1,
    );
    await NotificationService.addNotification(n1);

    final list = await NotificationService.getNotifications();
    expect(list.length, 1);
    expect(list.first.id, 'id1');
    expect(list.first.isRead, false);
  });

  test('addNotification prevents duplicates (upsert)', () async {
    final n1 = BudgetNotification(
      id: 'same',
      title: 'First',
      message: 'First',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1, 0, 0),
      pageIndex: 0,
    );
    final n2 = BudgetNotification(
      id: 'same',
      title: 'Updated',
      message: 'Updated msg',
      severity: NotificationSeverity.critical,
      createdAt: DateTime(2026, 1, 2, 0, 0),
      pageIndex: 2,
    );
    await NotificationService.addNotification(n1);
    await NotificationService.addNotification(n2);

    final list = await NotificationService.getNotifications();
    expect(list.length, 1);
    expect(list.first.title, 'Updated');
    expect(list.first.severity, NotificationSeverity.critical);
    expect(list.first.createdAt, equals(DateTime(2026, 1, 2, 0, 0)));
    expect(list.first.isRead, false); // default
  });

  test('markAsRead sets isRead and readAt', () async {
    final n = BudgetNotification(
      id: 'mark',
      title: 'To mark',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 0,
    );
    await NotificationService.addNotification(n);

    await NotificationService.markAsRead('mark');

    final list = await NotificationService.getNotifications();
    expect(list.length, 1);
    expect(list.first.isRead, true);
    expect(list.first.readAt, isNotNull);
  });

  test('getUnreadNotifications filters correctly', () async {
    final n1 = BudgetNotification(
      id: 'u1',
      title: 'Unread',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 0,
    );
    final n2 = BudgetNotification(
      id: 'u2',
      title: 'Read',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 2),
      pageIndex: 0,
      isRead: true,
      readAt: DateTime(2026, 1, 2, 12, 0),
    );
    await NotificationService.addNotification(n1);
    await NotificationService.addNotification(n2);

    final unread = await NotificationService.getUnreadNotifications();
    expect(unread.length, 1);
    expect(unread.first.id, 'u1');
  });

  test('markAllAsRead sets all to read', () async {
    final n1 = BudgetNotification(
      id: 'a1',
      title: 'A1',
      message: 'm',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 0,
    );
    final n2 = BudgetNotification(
      id: 'a2',
      title: 'A2',
      message: 'm',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 2),
      pageIndex: 0,
    );
    await NotificationService.addNotification(n1);
    await NotificationService.addNotification(n2);

    await NotificationService.markAllAsRead();

    final list = await NotificationService.getNotifications();
    expect(list.every((n) => n.isRead), isTrue);
    list.forEach((n) => expect(n.readAt, isNotNull));
  });

  test('clearAll removes all notifications', () async {
    final n = BudgetNotification(
      id: 'clear',
      title: 'Clear',
      message: 'm',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 0,
    );
    await NotificationService.addNotification(n);
    await NotificationService.clearAll();

    final list = await NotificationService.getNotifications();
    expect(list, isEmpty);
  });

  test('handles legacy plaintext notifications', () async {
    // Simulate a legacy entry (plain JSON) stored under the key.
    final prefs = await SharedPreferences.getInstance();
    final legacy = BudgetNotification(
      id: 'legacy',
      title: 'Legacy',
      message: 'Legacy msg',
      severity: NotificationSeverity.warning,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 0,
    );
    final legacyJson = jsonEncode(legacy.toJson());
    await prefs.setStringList('tena_budget_notifications', [legacyJson]);

    final list = await NotificationService.getNotifications();
    expect(list.length, 1);
    expect(list.first.id, 'legacy');
    expect(list.first.title, 'Legacy');
    // Should be decrypted as plaintext (not encrypted)
    expect(list.first.isRead, false);
  });

  test('encrypted storage obscures plaintext', () async {
    final n = BudgetNotification(
      id: 'enc',
      title: 'Enc',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: DateTime(2026, 1, 1),
      pageIndex: 0,
    );
    await NotificationService.addNotification(n);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('tena_budget_notifications');
    expect(stored, isNotNull);
    expect(stored?.length, 1);
    final encoded = stored!.first;
    // Should start with the marker
    expect(encoded, startsWith('tena1:'));
    // Should not be plain JSON
    expect(
      encoded,
      isNot(
        equals(
          '{\"id\":\"enc\",\"title\":\"Enc\",\"message\":\"msg\",\"severity\":\"info\",\"createdAt\":\"2026-01-01T00:00:00.000Z\",\"pageIndex\":0,\"isRead\":false}',
        ),
      ),
    ); // approximate
  });

  test('shouldNotify returns true when no existing notification', () async {
    final result = await NotificationService.shouldNotify('new-id');
    expect(result, isTrue);
  });

  test(
    'shouldNotify returns false when recent notification with same id',
    () async {
      final recent = BudgetNotification(
        id: 'same-id',
        title: 'Recent',
        message: 'msg',
        severity: NotificationSeverity.info,
        createdAt: DateTime.now(),
        pageIndex: 0,
      );
      await NotificationService.addNotification(recent);
      final result = await NotificationService.shouldNotify(
        'same-id',
        minInterval: const Duration(hours: 1),
      );
      expect(result, isFalse);
    },
  );

  test(
    'shouldNotify returns true when old notification beyond interval',
    () async {
      final old = BudgetNotification(
        id: 'old-id',
        title: 'Old',
        message: 'msg',
        severity: NotificationSeverity.info,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        pageIndex: 0,
      );
      await NotificationService.addNotification(old);
      final result = await NotificationService.shouldNotify(
        'old-id',
        minInterval: const Duration(hours: 1),
      );
      expect(result, isTrue);
    },
  );

  test('shouldNotify returns true when different id', () async {
    final n1 = BudgetNotification(
      id: 'id1',
      title: 'One',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: DateTime.now(),
      pageIndex: 0,
    );
    await NotificationService.addNotification(n1);
    final result = await NotificationService.shouldNotify(
      'id2',
      minInterval: const Duration(hours: 1),
    );
    expect(result, isTrue);
  });

  test('shouldNotify respects custom interval', () async {
    final now = DateTime.now();
    final recent = BudgetNotification(
      id: 'interval',
      title: 'Interval',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: now.subtract(const Duration(minutes: 20)),
      pageIndex: 0,
    );
    await NotificationService.addNotification(recent);
    // With interval 15 minutes, elapsed 20 >= 15 -> allowed
    final result1 = await NotificationService.shouldNotify(
      'interval',
      minInterval: const Duration(minutes: 15),
    );
    expect(result1, isTrue);
    // With interval 45 minutes, elapsed 20 < 45 -> blocked
    final result2 = await NotificationService.shouldNotify(
      'interval',
      minInterval: const Duration(minutes: 45),
    );
    expect(result2, isFalse);
  });

  test('shouldNotify treats future date as recent (returns false)', () async {
    final future = BudgetNotification(
      id: 'future',
      title: 'Future',
      message: 'msg',
      severity: NotificationSeverity.info,
      createdAt: DateTime.now().add(const Duration(hours: 1)),
      pageIndex: 0,
    );
    await NotificationService.addNotification(future);
    final result = await NotificationService.shouldNotify(
      'future',
      minInterval: const Duration(hours: 1),
    );
    expect(result, isFalse);
  });

  test('shouldNotify works with legacy plaintext entries', () async {
    final legacy = BudgetNotification(
      id: 'legacy-id',
      title: 'Legacy',
      message: 'msg',
      severity: NotificationSeverity.warning,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      pageIndex: 0,
    );
    final legacyJson = jsonEncode(legacy.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tena_budget_notifications', [legacyJson]);
    final result = await NotificationService.shouldNotify(
      'legacy-id',
      minInterval: const Duration(hours: 1),
    );
    expect(result, isTrue);
    final newNotif = BudgetNotification(
      id: 'legacy-id',
      title: 'Updated Legacy',
      message: 'updated',
      severity: NotificationSeverity.critical,
      createdAt: DateTime.now(),
      pageIndex: 1,
    );
    await NotificationService.addNotification(newNotif);
    final list = await NotificationService.getNotifications();
    expect(list.length, 1);
    expect(list.first.title, 'Updated Legacy');
    expect(list.first.severity, NotificationSeverity.critical);
  });

  test(
    'addNotification respects shouldNotify (does not add when recent)',
    () async {
      final id = 'rep-id';
      final first = BudgetNotification(
        id: id,
        title: 'First',
        message: 'msg',
        severity: NotificationSeverity.info,
        createdAt: DateTime.now(),
        pageIndex: 0,
      );
      await NotificationService.addNotification(first);
      final second = BudgetNotification(
        id: id,
        title: 'Second',
        message: 'msg2',
        severity: NotificationSeverity.warning,
        createdAt: DateTime.now(),
        pageIndex: 1,
      );
      await NotificationService.addNotification(second);
      final list = await NotificationService.getNotifications();
      expect(list.length, 1);
      expect(list.first.id, id);
      expect(list.first.title, 'First');
      expect(list.first.severity, NotificationSeverity.info);
    },
  );

  test(
    'addNotification adds when old enough (respects shouldNotify)',
    () async {
      final id = 'old-rep';
      final old = BudgetNotification(
        id: id,
        title: 'Old',
        message: 'msg',
        severity: NotificationSeverity.info,
        createdAt: DateTime.now().subtract(const Duration(hours: 7)),
        pageIndex: 0,
      );
      await NotificationService.addNotification(old);
      final newNotif = BudgetNotification(
        id: id,
        title: 'New',
        message: 'msg2',
        severity: NotificationSeverity.warning,
        createdAt: DateTime.now(),
        pageIndex: 1,
      );
      await NotificationService.addNotification(newNotif);
      final list = await NotificationService.getNotifications();
      expect(list.length, 1);
      expect(list.first.id, id);
      // Should have upserted to the newer notification (since allowed)
      expect(list.first.title, 'New');
      expect(list.first.severity, NotificationSeverity.warning);
    },
  );
  test('shouldNotify blocks when any matching notification is recent', () async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Old notification (outside interval)
    final old = BudgetNotification(
      id: 'mixed-id',
      title: 'Old',
      message: 'old msg',
      severity: NotificationSeverity.info,
      createdAt: now.subtract(const Duration(days: 1)),
      pageIndex: 0,
    );
    // Recent notification (inside interval)
    final recent = BudgetNotification(
      id: 'mixed-id',
      title: 'Recent',
      message: 'recent msg',
      severity: NotificationSeverity.warning,
      createdAt: now.subtract(const Duration(minutes: 30)),
      pageIndex: 0,
    );

    // Store both as plaintext (legacy format)
    final oldJson = jsonEncode(old.toJson());
    final recentJson = jsonEncode(recent.toJson());
    await prefs.setStringList('tena_budget_notifications', [oldJson, recentJson]);

    // Should be blocked because recent notification exists
    final result = await NotificationService.shouldNotify('mixed-id',
        minInterval: const Duration(hours: 1));
    expect(result, isFalse);

    // Storage should still contain exactly the two original entries
    final stored = await prefs.getStringList('tena_budget_notifications');
    expect(stored, isNotNull);
    expect(stored?.length, 2);
    final decodedOld = BudgetNotification.fromJson(jsonDecode(stored![0]));
    final decodedRecent = BudgetNotification.fromJson(jsonDecode(stored[1]));
    // Order may vary; check that we have one old and one recent
    final titles = {decodedOld.title, decodedRecent.title};
    expect(titles, contains('Old'));
    expect(titles, contains('Recent'));
    // Both notifications have the same id
    expect(decodedOld.id, equals('mixed-id'));
    expect(decodedRecent.id, equals('mixed-id'));

    // Attempt to add a new notification with same id (should be blocked)
    final newNotif = BudgetNotification(
      id: 'mixed-id',
      title: 'Should not be added',
      message: 'blocked',
      severity: NotificationSeverity.critical,
      createdAt: now,
      pageIndex: 2,
    );
    await NotificationService.addNotification(newNotif);

    // Storage should remain unchanged
    final storedAfter = await prefs.getStringList('tena_budget_notifications');
    expect(storedAfter, isNotNull);
    expect(storedAfter?.length, 2);
    final decodedAfterOld = BudgetNotification.fromJson(jsonDecode(storedAfter![0]));
    final decodedAfterRecent = BudgetNotification.fromJson(jsonDecode(storedAfter[1]));
    final titlesAfter = {decodedAfterOld.title, decodedAfterRecent.title};
    expect(titlesAfter, contains('Old'));
    expect(titlesAfter, contains('Recent'));
    expect(titlesAfter, isNot(contains('Should not be added')));
    // IDs unchanged
    expect(decodedAfterOld.id, equals('mixed-id'));
    expect(decodedAfterRecent.id, equals('mixed-id'));
  });
}
