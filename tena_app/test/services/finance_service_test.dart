import 'package:flutter_test/flutter_test.dart';
// `Transaction` existe aussi dans sqflite_common : on le masque pour garder
// le modèle de l'application (mêmes raison que database_service.dart).
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
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

/// Keystore stable pour toute la suite : la clé doit survivre d'un test à
/// l'autre, sinon les lignes écrites par un test deviendraient indéchiffrables
/// au test suivant.
class _TestKeyStore implements SecretKeyStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String keyBase64) async {
    _value = keyBase64;
  }

  @override
  Future<void> delete() async {
    _value = null;
  }
}

void main() {
  // Le chiffrement v3 s'appuie sur une source de clé injectée : le binding doit
  // être initialisé avant tout accès au stockage.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ces tests s'exécutent sur la vraie base SQLite : la factory FFI est la
  // même que celle utilisée par l'application sur Linux, Windows et macOS.
  final database = DatabaseService.instance;
  final keyStore = _TestKeyStore();

  setUpAll(() {
    sqfliteFfiInit();
    CryptoService.useKeyStore(keyStore);
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

  group('DatabaseService - suppression logique (schéma v2)', () {
    test('les notes sont enregistrées et relues', () async {
      await database.insertTransaction(
        _transaction(
          id: 'n1',
          amount: 42,
          date: DateTime(2026, 5, 2),
        ).copyWith(notes: 'Facture F-2026-014'),
      );

      final all = await database.getTransactions();

      expect(all.single.notes, 'Facture F-2026-014');
    });

    test('une note absente prend la valeur vide', () async {
      await database.insertTransaction(
        _transaction(id: 'n2', amount: 10, date: DateTime(2026, 5, 2)),
      );

      final all = await database.getTransactions();

      expect(all.single.notes, isEmpty);
      expect(all.single.isDeleted, isFalse);
    });

    test('supprimer masque la transaction sans l’effacer', () async {
      await database.insertTransaction(
        _transaction(id: 's1', amount: 80, date: DateTime(2026, 5, 3)),
      );

      await database.deleteTransaction('s1');

      // Invisible par défaut...
      expect(await database.getTransactions(), isEmpty);

      // ... mais toujours présente en base et marquée is_deleted.
      final withDeleted = await database.getTransactions(includeDeleted: true);

      expect(withDeleted.length, 1);
      expect(withDeleted.single.id, 's1');
      expect(withDeleted.single.isDeleted, isTrue);
    });

    test('restaurer remet la transaction dans les résultats', () async {
      await database.insertTransaction(
        _transaction(id: 's2', amount: 80, date: DateTime(2026, 5, 3)),
      );

      await database.deleteTransaction('s2');
      await database.restoreTransaction('s2');

      final all = await database.getTransactions();

      expect(all.length, 1);
      expect(all.single.isDeleted, isFalse);
    });

    test('purger efface définitivement', () async {
      await database.insertTransaction(
        _transaction(id: 's3', amount: 80, date: DateTime(2026, 5, 3)),
      );

      await database.deleteTransaction('s3');
      await database.purgeTransaction('s3');

      expect(await database.getTransactions(includeDeleted: true), isEmpty);
    });

    test('les notes et l’état survivent à une mise à jour', () async {
      await database.insertTransaction(
        _transaction(id: 's4', amount: 10, date: DateTime(2026, 5, 3)),
      );

      await database.updateTransaction(
        _transaction(id: 's4', amount: 25, date: DateTime(2026, 5, 3))
            .copyWith(notes: 'Ajustement'),
      );

      final all = await database.getTransactions();

      expect(all.single.amount, 25);
      expect(all.single.notes, 'Ajustement');
      expect(all.single.isDeleted, isFalse);
    });

    test('une transaction supprimée reste exclue des totaux', () async {
      await database.insertTransaction(
        _transaction(
          id: 't1',
          amount: 100,
          date: DateTime(2026, 6, 1),
          type: TransactionType.expense,
        ),
      );

      await database.deleteTransaction('t1');

      final summary = await FinanceService.getSummaryForMonth(
        DateTime(2026, 6),
      );

      expect(summary.expenses, 0);
      expect(summary.balance, 0);
      expect(summary.allTransactions, isEmpty);
    });
  });

  group('Chiffrement au repos (schéma v3)', () {
    test('les montants et libellés sont chiffrés dans la table', () async {
      await database.insertTransaction(
        _transaction(id: 'c1', amount: 987.65, date: DateTime(2026, 7, 1))
            .copyWith(notes: 'Compte 1234567890'),
      );

      // Lecture directe de la table, sans passer par le service : c'est
      // exactement ce que verrait un attaquant ayant le fichier de base.
      final db = await database.database;
      final rows = await db.query('transactions');

      expect(rows.single['amount'].toString(), isNot(contains('987.65')));
      expect(rows.single['notes'].toString(), isNot(contains('1234567890')));
      expect('${rows.single['amount']}'.startsWith('tena1:'), isTrue);

      // ... et l'application relit bien la valeur d'origine.
      final all = await database.getTransactions();

      expect(all.single.amount, 987.65);
      expect(all.single.notes, 'Compte 1234567890');
    });

    test('les totaux restent exacts malgré le chiffrement', () async {
      await database.insertTransaction(
        _transaction(
          id: 'c2',
          amount: 300,
          date: DateTime(2026, 8, 1),
          type: TransactionType.income,
        ),
      );
      await database.insertTransaction(
        _transaction(id: 'c3', amount: 125.5, date: DateTime(2026, 8, 2)),
      );

      final summary = await FinanceService.getSummaryForMonth(
        DateTime(2026, 8),
      );

      expect(summary.income, 300);
      expect(summary.expenses, 125.5);
      expect(summary.balance, 174.5);
    });

    test('la catégorie reste en clair pour le regroupement', () async {
      await database.insertTransaction(
        _transaction(id: 'c4', amount: 10, date: DateTime(2026, 9, 1)),
      );

      final db = await database.database;
      final rows = await db.query('transactions');

      // La catégorie sert de clé de regroupement : elle reste interrogeable.
      expect(rows.single['category'], 'Test');
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
