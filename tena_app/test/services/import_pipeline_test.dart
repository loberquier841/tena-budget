import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/import_service.dart';

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

  late Directory tempDir;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ImportService — pipeline unique (LOT 2)', () {
    test('détecte séparateur point-virgule, virgule et tabulation', () {
      expect(
        ImportService.detectSeparator('date;libellé;montant\n01/01/2026;A;10'),
        ';',
      );
      expect(
        ImportService.detectSeparator('date,libellé,montant\n01/01/2026,A,10'),
        ',',
      );
      expect(
        ImportService.detectSeparator('date\tlibellé\tmontant\n01/01/2026\tA\t10'),
        '\t',
      );
    });

    test('parse montants FR/internationaux en centimes entiers', () {
      expect(ImportService.parseAmountToCents('12,50'), 1250);
      expect(ImportService.parseAmountToCents('1 234,56 €'), 123456);
      expect(ImportService.parseAmountToCents('1.234,56'), 123456);
      expect(ImportService.parseAmountToCents('1234.56'), 123456);
      expect(ImportService.parseAmountToCents('-45,99'), -4599);
      expect(ImportService.parseAmountToCents('(45,00)'), -4500);
      expect(ImportService.parseAmountToCents('+10,00'), 1000);
      expect(ImportService.parseAmountToCents('0'), 0);
    });

    test('parse dates FR et ISO', () {
      expect(ImportService.parseFrenchDate('15/01/2026'), DateTime(2026, 1, 15));
      expect(ImportService.parseFrenchDate('15-01-2026'), DateTime(2026, 1, 15));
      expect(ImportService.parseFrenchDate('15.01.26'), DateTime(2026, 1, 15));
      expect(ImportService.parseFrenchDate('2026-01-15'), DateTime(2026, 1, 15));
      expect(ImportService.parseFrenchDate('not-a-date'), isNull);
    });

    test('analyse CSV FR avec mapping auto (date/libellé/montant/catégorie)', () {
      const csv = 'date;libellé;montant;catégorie\n'
          '15/01/2026;Courses Monoprix;-45,50;Alimentation\n'
          '01/02/2026;Salaire;3200,00;Revenus\n';
      final a = ImportService.analyzeCsv(csv);
      expect(a.separator, ';');
      expect(a.mapping.dateIndex, 0);
      expect(a.mapping.labelIndex, 1);
      expect(a.mapping.amountIndex, 2);
      expect(a.mapping.categoryIndex, 3);
      expect(a.report.errors, 0);
      expect(a.report.ready, 2);
      final p0 = a.rows[0].prepared!;
      expect(p0.amountCentsSigned, -4550);
      expect(p0.type, TransactionType.expense);
      expect(p0.category, 'Alimentation');
      final p1 = a.rows[1].prepared!;
      expect(p1.amountCentsSigned, 320000);
      expect(p1.type, TransactionType.income);
    });

    test('débit/crédit séparés: une seule colonne renseignée OK', () {
      const csv = 'date,description,debit,credit\n'
          '2026-01-10,Courses,45.50,\n'
          '2026-01-11,Salaire,,3200.00\n';
      final a = ImportService.analyzeCsv(csv);
      expect(a.report.errors, 0);
      expect(a.rows[0].prepared!.amountCentsSigned, -4550);
      expect(a.rows[0].prepared!.type, TransactionType.expense);
      expect(a.rows[1].prepared!.amountCentsSigned, 320000);
      expect(a.rows[1].prepared!.type, TransactionType.income);
    });

    test('débit/crédit tous deux non nuls => ambiguïté, pas de calcul net (Q4)', () {
      const csv = 'date,description,debit,credit\n'
          '2026-01-10,Ambigu,10.00,20.00\n';
      final a = ImportService.analyzeCsv(csv);
      expect(a.rows.first.status, ImportRowStatus.error);
      expect(a.rows.first.errors.any((e) => e.contains('Ambiguïté')), isTrue);
      expect(a.rows.first.prepared, isNull);
    });

    test('aperçu fidèle: preparedTransactions reflète exactement les lignes committables', () {
      const csv = 'date;libellé;montant\n15/01/2026;A;-10,00\n15/01/2026;B;bad\n';
      final a = ImportService.analyzeCsv(csv);
      final prepared = a.preparedTransactions();
      expect(prepared.length, 1);
      expect(prepared.first.description, 'A');
      expect(prepared.first.amountCentsSigned, -1000);
      expect(a.report.errors, 1);
    });

    test('doublons probables (2C): exclus par défaut, réactivables, ID unique si inclus', () {
      const csv = 'date;libellé;montant\n15/01/2026;Courses;-10,00\n15/01/2026;Courses;-10,00\n';
      final a = ImportService.analyzeCsv(csv);
      expect(a.report.duplicateProbable, 1);
      final def = a.preparedTransactions();
      expect(def.length, 1);
      final all = a.preparedTransactions(includeProbableDuplicates: true);
      expect(all.length, 2);
      expect(all[0].id, isNot(all[1].id), reason: 'pas d’écrasement, ID distinct');
    });

    test('détection doublon contre empreintes existantes', () {
      const csv = 'date;libellé;montant\n15/01/2026;Courses;-10,00\n';
      final fp = ImportService.fingerprintFor(
        date: DateTime(2026, 1, 15),
        amountEuros: -10.0,
        description: 'Courses',
        category: 'Autre',
        includeCategory: false,
      );
      final a = ImportService.analyzeCsv(csv, existingFingerprints: {fp});
      expect(a.rows.first.status, ImportRowStatus.duplicateProbable);
      expect(a.preparedTransactions(), isEmpty);
    });

    test('format canonique TENΛ détecté et mapping correct', () {
      const csv =
          'id,amount,category,description,date,type,isDeleted,notes\n'
          'tx1,12.50,Food,Lunch,2026-01-01,expense,0,n\n';
      final a = ImportService.analyzeCsv(csv);
      expect(a.mapping.isCanonicalTenA, isTrue);
      expect(a.rows.first.prepared!.id, 'tx1');
      expect(a.rows.first.prepared!.amountCentsSigned, 1250);
    });
  });

  group('DatabaseService — commit pipeline (LOT 2, Q5/Q6/Q8)', () {
    late DatabaseService db;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tena_imp_test_');
      await DatabaseService.resetAndDeleteTestDatabase();
      DatabaseService.testDatabasePath = p.join(tempDir.path, 'test.db');
      CryptoService.debugSetKey(null);
      CryptoService.useKeyStore(keyStore);
      db = DatabaseService.instance;
    });
    tearDown(() async {
      await DatabaseService.resetAndDeleteTestDatabase();
      DatabaseService.testDatabasePath = null;
      if (tempDir.existsSync()) {
        try { await tempDir.delete(recursive: true); } catch (_) {}
      }
    });

    test('commit insère via chemins chiffrés et round-trip lisible', () async {
      const csv = 'date;libellé;montant;catégorie\n15/01/2026;Courses;-45,50;Alimentation\n';
      final ctx = await db.getImportContext();
      final a = ImportService.analyzeCsv(csv,
          existingFingerprints: ctx.fingerprints, existingIds: ctx.existingIds);
      final res = await db.commitImportPlan(a.preparedTransactions());
      expect(res.imported, 1);
      expect(res.conflicts, isEmpty);
      final txs = await db.getTransactions();
      expect(txs.length, 1);
      expect(txs.first.description, 'Courses');
      expect(txs.first.amount, 45.50);
      expect(txs.first.type, TransactionType.expense);
      final raw = await (await db.database)
          .query('transactions', where: 'id = ?', whereArgs: [txs.first.id]);
      expect((raw.first['amount'] as String), startsWith('tena1:'));
      expect((raw.first['description'] as String), startsWith('tena1:'));
    });

    test('MAJ par ID canonique uniquement si ID connu pour userId (Q5)', () async {
      await db.insertTransaction(Transaction(
        id: 'keep',
        amount: 10,
        category: 'A',
        description: 'Old',
        date: DateTime(2026, 1, 1),
        type: TransactionType.expense,
      ));
      const csv =
          'id,amount,category,description,date,type,isDeleted,notes\n'
          'keep,99.00,A,New,2026-01-02,expense,0,\n'
          'unknown,5.00,A,X,2026-01-03,expense,0,\n';
      final ctx = await db.getImportContext();
      final a = ImportService.analyzeCsv(csv,
          existingFingerprints: ctx.fingerprints, existingIds: ctx.existingIds);
      final res = await db.commitImportPlan(a.preparedTransactions());
      expect(res.updated, 1);
      expect(res.updated, 1);
      expect(res.imported, 2);
      expect(res.conflicts, isEmpty);
      final txs = await db.getTransactions();
      final keep = txs.firstWhere((t) => t.id == 'keep');
      expect(keep.description, 'New');
      expect(keep.amount, 99.00);
      expect(txs.any((t) => t.id == 'unknown'), isTrue,
          reason: "ID canonique explicite absent: insertion sûre, aucun remplacement d'une autre transaction");
    });

    test('collision ID sûre: aucun écrasement', () async {
      await db.insertTransaction(Transaction(
        id: 'same',
        amount: 10,
        category: 'A',
        description: 'Orig',
        date: DateTime(2026, 1, 1),
        type: TransactionType.expense,
      ));
      final prepared = [
        PreparedTransaction(
          id: 'same',
          amountCentsSigned: -5000,
          category: 'A',
          description: 'Intrus',
          date: DateTime(2026, 2, 1),
          type: TransactionType.expense,
          notes: '',
          isDeleted: false,
          canonicalIdUpdate: false,
          preserveSignedAmount: false,
          fingerprint: 'fp|x',
        ),
      ];
      final res = await db.commitImportPlan(prepared);
      expect(res.skipped, 1);
      expect(res.conflicts.any((c) => c.contains('Collision')), isTrue);
      final tx = (await db.getTransactions()).single;
      expect(tx.description, 'Orig');
      expect(tx.amount, 10);
    });
  });
}
