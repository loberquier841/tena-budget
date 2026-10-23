import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/models/backup_models.dart';
import 'package:tena_budget/services/backup_service.dart';

class _MemoryKeyStore implements CryptoService.SecretKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String keyBase64) async {
    value = keyBase64;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  CryptoService.useKeyStore(_MemoryKeyStore());

  test('includes current SQLite category budgets in a backup', () async {
    final category = 'backup-test-'
        + DateTime.now().microsecondsSinceEpoch.toString();
    await DatabaseService.instance.setCategoryBudget(category, 321);

    final backup = await BackupService.collectData();
    final categories = backup.budgets['categories'] as Map<String, dynamic>;

    expect(categories[category], 321);
  });

  group('Backup restore conflict detection', () {
    test('reports existing transactions, budgets, goals and profile', () {
      const data = BackupData(
        profile: {'name': 'Local profile'},
        transactions: [
          {'id': 'transaction-1'},
        ],
        budgets: {
          'global': 1200,
          'categories': {'Courses': 250},
        },
        goals: [
          {'id': 'goal-1'},
        ],
      );

      final conflicts = BackupService.findRestoreConflicts(
        data,
        transactionIds: {'transaction-1'},
        budgetIds: {'global', 'Courses'},
        goalIds: {'goal-1'},
        hasProfile: true,
      );

      expect(
        conflicts,
        [
          'budget:Courses',
          'budget:global',
          'goal:goal-1',
          'profile',
          'transaction:transaction-1',
        ],
      );
    });

    test('detects duplicate identifiers inside the backup itself', () {
      const data = BackupData(
        transactions: [
          {'id': 'duplicate'},
          {'id': 'duplicate'},
        ],
        budgets: {},
        goals: [
          {'id': 'same-goal'},
          {'id': 'same-goal'},
        ],
      );

      final conflicts = BackupService.findRestoreConflicts(
        data,
        transactionIds: const {},
        budgetIds: const {},
        goalIds: const {},
        hasProfile: false,
      );

      expect(conflicts, ['goal:same-goal', 'transaction:duplicate']);
    });

    test('ignores empty budgets that restoration will not write', () {
      const data = BackupData(
        budgets: {
          'global': 0,
          'categories': {'Transport': 0},
        },
        transactions: [],
        goals: [],
      );

      final conflicts = BackupService.findRestoreConflicts(
        data,
        transactionIds: const {},
        budgetIds: {'global', 'Transport'},
        goalIds: const {},
        hasProfile: false,
      );

      expect(conflicts, isEmpty);
    });

    test('allows a restore when no identifiers overlap', () {
      const data = BackupData(
        transactions: [
          {'id': 'new-transaction'},
        ],
        budgets: {
          'global': 800,
          'categories': {'Transport': 90},
        },
        goals: [
          {'id': 'new-goal'},
        ],
      );

      final conflicts = BackupService.findRestoreConflicts(
        data,
        transactionIds: {'existing-transaction'},
        budgetIds: {'Food'},
        goalIds: {'existing-goal'},
        hasProfile: false,
      );

      expect(conflicts, isEmpty);
    });
  });
}
