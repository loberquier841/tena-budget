import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/models/backup_models.dart';
import 'package:tena_budget/services/backup_service.dart';

void main() {
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
