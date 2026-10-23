import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:csv/csv.dart';

import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/models/transaction.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  final keyStore = _TestKeyStore();
  late DatabaseService db;

  setUpAll(() {
    sqfliteFfiInit();
    CryptoService.useKeyStore(keyStore);
  });

  setUp(() async {
    db = DatabaseService.instance;
    await db.resetForTesting();
    final database = await db.database;
    await database.delete('transactions');
  });

  group('CSV Export/Import — Edge Cases', () {
    test('export then import round-trip preserves all fields', () async {
      await db.insertTransaction(Transaction(
        id: 't1',
        amount: 123.45,
        category: 'Courses',
        description: 'Supermarché',
        date: DateTime(2026, 1, 15),
        type: TransactionType.expense,
        notes: 'Note avec accents éàù',
        isDeleted: false,
      ));
      await db.insertTransaction(Transaction(
        id: 't2',
        amount: 2500.00,
        category: 'Salaire',
        description: 'Salaire janvier',
        date: DateTime(2026, 1, 1),
        type: TransactionType.income,
        notes: '',
        isDeleted: false,
      ));

      final csv = await db.exportTransactionsToCsv(includeDeleted: false);
      expect(csv, isNotEmpty);

      final lines = csv.trim().split('
');
      expect(lines.length, 3);
      expect(lines[0], 'id,amount,category,description,date,type,isDeleted,notes');

      await db.resetForTesting();
      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 2);

      final txs = await db.getTransactions();
      expect(txs.length, 2);
      
      final t1 = txs.firstWhere((t) => t.id == 't1');
      expect(t1.amount, 123.45);
      expect(t1.category, 'Courses');
      expect(t1.description, 'Supermarché');
      expect(t1.date, DateTime(2026, 1, 15));
      expect(t1.type, TransactionType.expense);
      expect(t1.notes, 'Note avec accents éàù');
      expect(t1.isDeleted, false);

      final t2 = txs.firstWhere((t) => t.id == 't2');
      expect(t2.amount, 2500.00);
      expect(t2.type, TransactionType.income);
    });

    test('import handles UTF-8 accents in category and description', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,100.50,Déjeuner,Restaurant "Le Café",2026-01-15,expense,0,Note avec accents éàùç
'
          't2,200,00,Transport,Métro ligne 1,2026-01-16,expense,0,"Note avec guillemets et, virgule"
';

      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 2);

      final txs = await db.getTransactions();
      final t1 = txs.firstWhere((t) => t.id == 't1');
      expect(t1.category, 'Déjeuner');
      expect(t1.description, 'Restaurant "Le Café"');
      expect(t1.notes, 'Note avec accents éàùç');

      final t2 = txs.firstWhere((t) => t.id == 't2');
      expect(t2.amount, 200.00);
      expect(t2.category, 'Transport');
      expect(t2.notes, 'Note avec guillemets et, virgule');
    });

    test('import handles newlines in quoted fields', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,50.00,Test,"Description avec
retour à la ligne",2026-01-15,expense,0,Note normale
';

      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 1);

      final txs = await db.getTransactions();
      expect(txs.length, 1);
      expect(txs[0].description, contains('retour à la ligne'));
    });

    test('import handles negative amounts correctly', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,-100.00,Remboursement,Remboursement achat,2026-01-15,expense,0,
'
          't2,-50.50,Autre,Autre remboursement,2026-01-16,income,0,
';

      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 2);

      final txs = await db.getTransactions();
      final t1 = txs.firstWhere((t) => t.id == 't1');
      expect(t1.amount, -100.00);
      expect(t1.type, TransactionType.expense);

      final t2 = txs.firstWhere((t) => t.id == 't2');
      expect(t2.amount, -50.50);
      expect(t2.type, TransactionType.income);
    });

    test('import handles transfer type', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,500.00,Transfert,Virement compte épargne,2026-01-15,transfer,0,
';

      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 1);

      final txs = await db.getTransactions();
      expect(txs.length, 1);
      expect(txs[0].type, TransactionType.transfer);
      expect(txs[0].amount, 500.00);
    });

    test('import ignores invalid lines gracefully', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,100.00,Valid,Valid desc,2026-01-15,expense,0,
'
          'invalid,line,with,few,fields
'
          't2,200.00,AlsoValid,Another desc,2026-01-16,income,0,
'
          ',t3,300.00,MissingID,Desc,2026-01-17,expense,0,
'
          't4,not-a-number,BadAmount,Desc,2026-01-18,expense,0,
'
          't5,400.00,BadDate,Desc,invalid-date,expense,0,
'
          't6,500.00,BadType,Desc,2026-01-19,unknown,0,
';

      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 2);

      final txs = await db.getTransactions();
      expect(txs.length, 2);
      expect(txs.any((t) => t.id == 't1'), true);
      expect(txs.any((t) => t.id == 't2'), true);
    });

    test('import handles isDeleted flag', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,100.00,Test,Normal,2026-01-15,expense,0,
'
          't2,200.00,Test,Deleted,2026-01-16,expense,1,
';

      final imported = await db.importTransactionsFromCsv(csv);
      expect(imported, 2);

      final txs = await db.getTransactions(includeDeleted: false);
      expect(txs.length, 1);
      expect(txs[0].id, 't1');

      final allTxs = await db.getTransactions(includeDeleted: true);
      expect(allTxs.length, 2);
      final t2 = allTxs.firstWhere((t) => t.id == 't2');
      expect(t2.isDeleted, true);
    });

    test('import with duplicate IDs updates existing (INSERT OR REPLACE)', () async {
      const csv1 = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,100.00,Original,First import,2026-01-15,expense,0,
';
      await db.importTransactionsFromCsv(csv1);

      const csv2 = 'id,amount,category,description,date,type,isDeleted,notes
'
          't1,999.99,Mise à jour,Second import,2026-01-20,income,0,Updated note
';
      final imported = await db.importTransactionsFromCsv(csv2);
      expect(imported, 1);

      final txs = await db.getTransactions();
      expect(txs.length, 1);
      expect(txs[0].amount, 999.99);
      expect(txs[0].category, 'Mise à jour');
      expect(txs[0].description, 'Second import');
      expect(txs[0].type, TransactionType.income);
      expect(txs[0].notes, 'Updated note');
      expect(txs[0].date, DateTime(2026, 1, 20));
    });

    test('export includes deleted transactions when requested', () async {
      await db.insertTransaction(Transaction(
        id: 'active',
        amount: 100,
        category: 'Test',
        description: 'Active',
        date: DateTime(2026, 1, 1),
        type: TransactionType.expense,
        isDeleted: false,
      ));
      await db.insertTransaction(Transaction(
        id: 'deleted',
        amount: 200,
        category: 'Test',
        description: 'Deleted',
        date: DateTime(2026, 1, 2),
        type: TransactionType.expense,
        isDeleted: true,
      ));

      final csvExclude = await db.exportTransactionsToCsv(includeDeleted: false);
      final linesExclude = csvExclude.trim().split('
');
      expect(linesExclude.length, 2);

      final csvInclude = await db.exportTransactionsToCsv(includeDeleted: true);
      final linesInclude = csvInclude.trim().split('
');
      expect(linesInclude.length, 3);
    });

    test('empty CSV import returns 0', () async {
      expect(await db.importTransactionsFromCsv(''), 0);
      expect(await db.importTransactionsFromCsv('id,amount,category,description,date,type,isDeleted,notes
'), 0);
    });

    test('CSV with only headers returns 0', () async {
      const csv = 'id,amount,category,description,date,type,isDeleted,notes
';
      expect(await db.importTransactionsFromCsv(csv), 0);
    });
  });
}
