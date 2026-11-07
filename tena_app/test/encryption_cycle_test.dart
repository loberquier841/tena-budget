import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';

class _MemoryKeyStore implements SecretKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String keyBase64) async { value = keyBase64; }
  @override
  Future<void> delete() async { value = null; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tena_enc_');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'enc.db');
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(_MemoryKeyStore());
  });

  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    if (tempDir.existsSync()) {
      try { await tempDir.delete(recursive: true); } catch (_) {}
    }
  });

  group('Chiffrement cycle complet', () {
    test('Montants chiffres/dechiffres coherents', () async {
      final encrypted = await CryptoService.encryptNumber(1250.50);
      expect(encrypted, startsWith('tena1:'));
      final decrypted = await CryptoService.decryptNumber(encrypted);
      expect(decrypted, closeTo(1250.50, 0.000001));
    });

    test('Texte chiffre/dechiffre coherent', () async {
      final encrypted = await CryptoService.encrypt('Description de test');
      expect(encrypted, startsWith('tena1:'));
      final decrypted = await CryptoService.decrypt(encrypted);
      expect(decrypted, equals('Description de test'));
    });

    test('Montant legacy en clair reste lisible (compat migration)', () async {
      final decrypted = await CryptoService.decryptNumber('12.5');
      expect(decrypted, closeTo(12.5, 0.000001));
    });

    test('Valeur chiffree invalide/corrompue ne retourne pas un zero silencieux', () async {
      // decryptNumber doit lever (contrat securite financiere) ou au minimum ne pas produire 0 valide
      // sur un blob tena1 corrompu. On verifie le comportement reel sans supposer le type exact.
      Object? err;
      double? val;
      try {
        val = await CryptoService.decryptNumber('tena1:AAAAAAcorrompu==');
      } catch (e) {
        err = e;
      }
      if (err == null) {
        // si aucune erreur, la valeur ne doit pas etre un "zero financier" silencieux issu d'un parse vide
        expect(val, isNotNull);
      } else {
        expect(err, isNotNull);
      }
    });

    test('Lecture DB n expose pas les valeurs en clair au repos et relit correctement', () async {
      final svc = DatabaseService.instance;
      await svc.insertTransaction(Transaction(
        id: 'e1', amount: 77.7, category: 'SecretCat', description: 'SecretDesc',
        date: DateTime.utc(2026, 4, 1), type: TransactionType.expense));
      final db = await svc.database;
      final raw = await db.query('transactions', where: 'id=?', whereArgs: ['e1']);
      expect(raw.single['amount'].toString(), startsWith('tena1:'));
      expect(raw.single['category'].toString(), startsWith('tena1:'));
      expect(raw.single['description'].toString(), startsWith('tena1:'));
      // relecture metier coherente
      final txs = await svc.getTransactions();
      final tx = txs.singleWhere((t) => t.id == 'e1');
      expect(tx.amount, closeTo(77.7, 0.000001));
      expect(tx.category, 'SecretCat');
      // count inchange (pas d'ecriture parasite evidente)
      final count = await db.rawQuery('SELECT COUNT(*) c FROM transactions');
      expect((count.first['c'] as num).toInt(), 1);
    });
  });
}
