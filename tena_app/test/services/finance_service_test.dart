import 'package:flutter_test/flutter_test.dart';
// `Transaction` existe aussi dans sqflite_common : on le masque pour garder
// le modèle de l'application (mêmes raison que database_service.dart).
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/finance_service.dart';

Transaction _transaction({
  required String id,
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: 'Test',
    description: 'Description',
    date: date,
    type: type,
  );
}

void main() {
  // Ces tests s'exécutent sur la vraie base SQLite : la factory FFI est la
  // même que celle utilisée par l'application sur Linux, Windows et macOS.
  final database = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final db = await database.database;

    await db.delete('transactions');
  });

  group('DatabaseService', () {
    test('insère puis relit trié par date décroissante', () async {
      await database.insertTransaction(
        _transaction(id: 'a', amount: 10, date: DateTime(2026, 1, 5)),
      );
      await database.insertTransaction(
        _transaction(id: 'b', amount: 20, date: DateTime(2026, 1, 20)),
      );

      final all = await database.getTransactions();

      expect(all.length, 2);
      expect(all.first.id, 'b');
      expect(all.last.id, 'a');
    });

    test('conserve type, montant et date', () async {
      await database.insertTransaction(
        _transaction(
          id: 'c',
          amount: 12.5,
          date: DateTime(2026, 1, 1),
          type: TransactionType.income,
        ),
      );

      final all = await database.getTransactions();

      expect(all.single.amount, 12.5);
      expect(all.single.type, TransactionType.income);
      expect(all.single.date, DateTime(2026, 1, 1));
    });

    test('met à jour puis supprime', () async {
      await database.insertTransaction(
        _transaction(id: 'd', amount: 10, date: DateTime(2026, 1, 5)),
      );

      await database.updateTransaction(
        _transaction(id: 'd', amount: 99, date: DateTime(2026, 1, 5)),
      );

      var all = await database.getTransactions();
      expect(all.single.amount, 99);

      await database.deleteTransaction('d');

      all = await database.getTransactions();
      expect(all, isEmpty);
    });

    test('un identifiant existant est remplacé et non dupliqué', () async {
      await database.insertTransaction(
        _transaction(id: 'e', amount: 10, date: DateTime(2026, 1, 5)),
      );
      await database.insertTransaction(
        _transaction(id: 'e', amount: 30, date: DateTime(2026, 1, 5)),
      );

      final all = await database.getTransactions();

      expect(all.length, 1);
      expect(all.single.amount, 30);
    });
  });

  group('FinanceService.getSummaryForMonth', () {
    test('ignore les transactions des autres mois', () async {
      await database.insertTransaction(
        _transaction(id: 'm1', amount: 100, date: DateTime(2026, 1, 10)),
      );
      await database.insertTransaction(
        _transaction(id: 'm2', amount: 50, date: DateTime(2026, 2, 10)),
      );

      final summary = await FinanceService.getSummaryForMonth(
        DateTime(2026, 1),
      );

      expect(summary.allTransactions.length, 1);
      expect(summary.expenses, 100);
    });

    test('calcule revenus, dépenses et solde', () async {
      await database.insertTransaction(
        _transaction(
          id: 's1',
          amount: 3000,
          date: DateTime(2026, 3, 1),
          type: TransactionType.income,
        ),
      );
      await database.insertTransaction(
        _transaction(id: 's2', amount: 500, date: DateTime(2026, 3, 2)),
      );
      await database.insertTransaction(
        _transaction(id: 's3', amount: 250, date: DateTime(2026, 3, 3)),
      );

      final summary = await FinanceService.getSummaryForMonth(
        DateTime(2026, 3),
      );

      expect(summary.income, 3000);
      expect(summary.expenses, 750);
      expect(summary.balance, 2250);
    });

    test('ne conserve que les 5 transactions les plus récentes', () async {
      for (var day = 1; day <= 8; day++) {
        await database.insertTransaction(
          _transaction(id: 'r$day', amount: 10, date: DateTime(2026, 4, day)),
        );
      }

      final summary = await FinanceService.getSummaryForMonth(
        DateTime(2026, 4),
      );

      expect(summary.allTransactions.length, 8);
      expect(summary.recentTransactions.length, 5);
    });

    test('un mois sans donnée renvoie des totaux à zéro', () async {
      final summary = await FinanceService.getSummaryForMonth(
        DateTime(2030, 9),
      );

      expect(summary.income, 0);
      expect(summary.expenses, 0);
      expect(summary.balance, 0);
      expect(summary.allTransactions, isEmpty);
    });
  });

  group('FinanceService.getSummary', () {
    test('couvre tous les mois confondus', () async {
      await database.insertTransaction(
        _transaction(id: 'y1', amount: 100, date: DateTime(2025, 12, 31)),
      );
      await database.insertTransaction(
        _transaction(id: 'y2', amount: 200, date: DateTime(2026, 1, 1)),
      );
      await database.insertTransaction(
        _transaction(id: 'y3', amount: 400, date: DateTime(2026, 1, 2)),
      );

      final summary = await FinanceService.getSummary();

      expect(summary.expenses, 700);
      expect(summary.allTransactions.length, 3);
    });
  });
}
