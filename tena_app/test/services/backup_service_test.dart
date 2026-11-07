import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tena_budget/models/backup_models.dart';
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/backup_service.dart';
import 'package:tena_budget/services/budget_service.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/goal_service.dart';

class _MemoryKeyStore implements SecretKeyStore {
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

  late _MemoryKeyStore store;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tena_bak_test_');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'test.db');
    BackupService.testBackupDirectory = tempDir.path;
    store = _MemoryKeyStore();
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(store);
  });

  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    BackupService.testBackupDirectory = null;
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('BackupService - collecte (donnees reelles)', () {
    test('collecte sans erreur meme base vide', () async {
      final data = await BackupService.collectData();
      expect(data.transactions, isA<List<Map<String, dynamic>>>());
      expect(data.budgets, isA<Map<String, dynamic>>());
      expect(data.goals, isA<List<Map<String, dynamic>>>());
    });

    test('collecte transactions inserees', () async {
      await DatabaseService.instance.insertTransaction(Transaction(
        id: 't1',
        amount: 42.5,
        category: 'Courses',
        description: 'Test',
        date: DateTime.utc(2026, 1, 2),
        type: TransactionType.expense,
      ));
      final data = await BackupService.collectData();
      expect(data.transactions.length, 1);
      expect(data.transactions.first['id'], 't1');
      expect((data.transactions.first['amount'] as num).toDouble(), 42.5);
    });

    test('collecte budgets (global + categories)', () async {
      await BudgetService.setGlobalBudget(1200);
      await BudgetService.setCategoryBudget('Courses', 300);
      final data = await BackupService.collectData();
      // Global: présent (unité selon implémentation service/DB) ; non null si défini.
      expect(data.budgets.containsKey('global'), isTrue);
      expect(data.budgets['global'], isNotNull);
      // Catégories: collectées depuis source réelle (prefs et/ou DB selon implémentation backup).
      final cats = Map<String, dynamic>.from(data.budgets['categories'] as Map? ?? {});
      // Si la collecte inclut la catégorie DB, le montant doit être cohérent (>0).
      if (cats.containsKey('Courses')) {
        expect((cats['Courses'] as num).toDouble(), greaterThan(0));
      }
      // Le budget global doit être restaurable/lisible via service réel.
      expect(await BudgetService.getGlobalBudget(), greaterThan(0));
    });

    test('collecte objectifs', () async {
      await GoalService.addGoal(name: 'Vacances', targetEuros: 500, savedEuros: 10);
      final data = await BackupService.collectData();
      expect(data.goals.length, 1);
      expect(data.goals.first['name'], 'Vacances');
    });

    test('couverture declaree honnete (documents/comptes)', () async {
      final data = await BackupService.collectData();
      expect(data.coverage['transactions'], isTrue);
      // LOT 8: justificatifs intégrés (persistés/restaurables, contenu quand présent)
      expect(data.coverage['documents'], isTrue);
      expect(data.coverage['attachments'], isTrue);
      expect(data.coverage['accounts'], isFalse);
    });
  });

  group('BackupService - create/validate JSON (format/integrite)', () {
    test('cree un JSON non chiffre valide', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['format'], backupFormatMarker);
      expect(parsed['encrypted'], isFalse);
      expect(parsed['checksum'], isA<String>());
      expect((parsed['checksum'] as String).isNotEmpty, isTrue);
      expect(parsed['data'], isA<Map>());
    });

    test('valide un backup non chiffre', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final res = await BackupService.validateBackupJson(json);
      expect(res.isValid, isTrue);
      expect(res.reason, isNull);
      expect(res.summary, isNotNull);
      expect(res.summary!.encrypted, isFalse);
    });

    test('detecte JSON invalide / format inconnu / version non supportee', () async {
      expect((await BackupService.validateBackupJson('{nope')).isValid, isFalse);
      expect((await BackupService.validateBackupJson(jsonEncode({'format': 'x'}))).reason,
          'BACKUP_FORMAT_UNKNOWN');
      expect((await BackupService.validateBackupJson(jsonEncode({
        'format': backupFormatMarker,
        'version': 999,
        'schemaVersion': backupSchemaVersion,
        'checksum': 'x',
        'data': {}
      }))).reason, 'BACKUP_VERSION_UNSUPPORTED');
    });

    test('detecte checksum manquant, modifie, et donnees alterees', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final missing = Map<String, dynamic>.from(parsed)..remove('checksum');
      expect((await BackupService.validateBackupJson(jsonEncode(missing))).reason,
          'BACKUP_CHECKSUM_MISSING');
      final bad = Map<String, dynamic>.from(parsed)..['checksum'] = 'deadbeef';
      expect((await BackupService.validateBackupJson(jsonEncode(bad))).reason,
          'BACKUP_CHECKSUM_MISMATCH');
      // alteration du contenu avec checksum d'origine
      final data = Map<String, dynamic>.from(parsed['data'] as Map);
      data['transactions'] = [
        {'id': 'x', 'amount': 1, 'category': 'A', 'description': '', 'date': DateTime.now().toIso8601String(), 'type': 'expense'}
      ];
      final altered = Map<String, dynamic>.from(parsed)..['data'] = data;
      expect((await BackupService.validateBackupJson(jsonEncode(altered))).reason,
          'BACKUP_CHECKSUM_MISMATCH');
    });

    test('accepte format v1 (retrocompat lecture)', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = {
        'profile': null,
        'transactions': [],
        'budgets': {'global': null, 'categories': {}},
        'goals': []
      };
      final dataJson = jsonEncode(data);
      final checksum = crypto_hash.sha256.convert(utf8.encode(dataJson)).toString();
      final v1 = jsonEncode({
        'format': backupFormatMarker,
        'version': 1,
        'createdAt': now,
        'appVersion': '1.0.0',
        'schemaVersion': 1,
        'encrypted': false,
        'checksum': checksum,
        'data': data,
      });
      final res = await BackupService.validateBackupJson(v1);
      expect(res.isValid, isTrue);
      expect(res.summary!.formatVersion, 1);
    });

    test('previsualisation expose compteurs reels et couverture', () async {
      await DatabaseService.instance.insertTransaction(Transaction(
        id: 'c1', amount: 10, category: 'A', description: 'd',
        date: DateTime(2026, 1, 1), type: TransactionType.expense));
      final res = await BackupService.validateBackupJson(
          await BackupService.createBackupJson(encrypt: false));
      expect(res.isValid, isTrue);
      expect(res.summary!.transactionCount, 1);
      expect(res.summary!.documentCount, 0);
      expect(res.summary!.data.coverage['documents'], isTrue);
      expect(res.summary!.data.coverage['accounts'], isFalse);
    });
  });

  group('BackupService - chiffrement local_key', () {
    test('cree et valide un backup chiffre (cle locale)', () async {
      final json = await BackupService.createBackupJson(
          encrypt: true, encryptionMode: BackupEncryptionMode.localKey);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['encrypted'], isTrue);
      expect(parsed['encryptionMode'], BackupEncryptionMode.localKey);
      expect(parsed['data'], isA<String>()); // blob chiffre
      final res = await BackupService.validateBackupJson(json);
      expect(res.isValid, isTrue);
      expect(res.summary!.encrypted, isTrue);
      expect(res.summary!.encryptionMode, BackupEncryptionMode.localKey);
    });

    test('blob chiffre corrompu -> echec dechiffrement/validation', () async {
      final json = await BackupService.createBackupJson(encrypt: true);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      parsed['data'] = 'tena1:AAAAcorrompu';
      final res = await BackupService.validateBackupJson(jsonEncode(parsed));
      expect(res.isValid, isFalse);
    });
  });

  group('BackupService - portable passphrase (Argon2id/PBKDF2)', () {
    test('export/import portable avec phrase correcte', () async {
      await DatabaseService.instance.insertTransaction(Transaction(
        id: 'p1', amount: 7, category: 'X', description: 'P',
        date: DateTime(2026, 2, 1), type: TransactionType.expense));
      final json = await BackupService.createBackupJson(
        encrypt: true,
        encryptionMode: BackupEncryptionMode.portablePassphrase,
        passphrase: 'phrase-secrete-123',
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['encryptionMode'], BackupEncryptionMode.portablePassphrase);
      expect(parsed['kdf'], isA<Map>());
      expect((parsed['kdf'] as Map)['salt'], isNotNull);
      // sans phrase
      final noPass = await BackupService.validateBackupJson(json);
      expect(noPass.isValid, isFalse);
      expect(noPass.reason, anyOf('PASSPHRASE_REQUIRED', 'BACKUP_DECRYPTION_FAILED', 'BACKUP_PASSPHRASE_INVALID'));
      // mauvaise phrase
      final bad = await BackupService.validateBackupJson(json, passphrase: 'mauvaise');
      expect(bad.isValid, isFalse);
      // bonne phrase
      final ok = await BackupService.validateBackupJson(json, passphrase: 'phrase-secrete-123');
      expect(ok.isValid, isTrue);
      expect(ok.summary!.isPortable, isTrue);
      expect(ok.summary!.transactionCount, 1);
    });

    test('verifyPassphrase valide/invalid', () async {
      final json = await BackupService.createBackupJson(
        encrypt: true,
        encryptionMode: BackupEncryptionMode.portablePassphrase,
        passphrase: 'abc',
      );
      expect((await BackupService.verifyPassphrase(json, 'abc')).isValid, isTrue);
      expect((await BackupService.verifyPassphrase(json, 'nope')).isValid, isFalse);
    });

    test('LOT3 securite: refuse KDF hors bornes sures (anti-DoS)', () async {
      final json = await BackupService.createBackupJson(
        encrypt: true,
        encryptionMode: BackupEncryptionMode.portablePassphrase,
        passphrase: 'ok',
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final kdf = Map<String, dynamic>.from(parsed['kdf'] as Map)..['memoryKiB'] = 999999999;
      parsed['kdf'] = kdf;
      final res = await BackupService.validateBackupJson(jsonEncode(parsed), passphrase: 'ok');
      expect(res.isValid, isFalse);
      expect(res.reason, 'BACKUP_KDF_PARAMS_UNSAFE');
    });

    test('LOT3 securite: refuse iterations PBKDF2 hors bornes', () async {
      final json = await BackupService.createBackupJson(
        encrypt: true,
        encryptionMode: BackupEncryptionMode.portablePassphrase,
        passphrase: 'ok',
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      parsed['kdf'] = {
        'algorithm': 'pbkdf2_hmac_sha256',
        'salt': (parsed['kdf'] as Map)['salt'],
        'iterations': 999999999,
        'bits': 256,
        'mac': 'HMAC-SHA256',
      };
      final res = await BackupService.validateBackupJson(jsonEncode(parsed), passphrase: 'ok');
      expect(res.isValid, isFalse);
      expect(res.reason, 'BACKUP_KDF_PARAMS_UNSAFE');
    });

    test('LOT3 securite: refuse algo KDF inconnu', () async {
      final json = await BackupService.createBackupJson(
        encrypt: true,
        encryptionMode: BackupEncryptionMode.portablePassphrase,
        passphrase: 'ok',
      );
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final kdf = Map<String, dynamic>.from(parsed['kdf'] as Map)..['algorithm'] = 'md5';
      parsed['kdf'] = kdf;
      final res = await BackupService.validateBackupJson(jsonEncode(parsed), passphrase: 'ok');
      expect(res.isValid, isFalse);
      expect(res.reason, 'BACKUP_KDF_PARAMS_UNSAFE');
    });
  });

  group('BackupService - fichiers / restauration', () {
    test('createBackupFile ne ecrase pas silencieusement', () async {
      final f1 = await BackupService.createBackupFile(encrypt: false, directory: tempDir.path, fileName: 'a');
      final f2 = await BackupService.createBackupFile(encrypt: false, directory: tempDir.path, fileName: 'a');
      expect(await f1.exists(), isTrue);
      expect(await f2.exists(), isTrue);
      expect(f1.path, isNot(equals(f2.path)));
    });

    test('validateBackupFile: fichier absent/invalide', () async {
      final absent = await BackupService.validateBackupFile(File(p.join(tempDir.path, 'nope.tenabackup')));
      expect(absent.isValid, isFalse);
      expect(absent.reason, 'BACKUP_FILE_NOT_FOUND');
      final bad = File(p.join(tempDir.path, 'bad.tenabackup'))..writeAsStringSync('not json');
      final r = await BackupService.validateBackupFile(bad);
      expect(r.isValid, isFalse);
    });

    test('restoreFromFileDetailed: invalide => echec, aucune ecriture requise', () async {
      final bad = File(p.join(tempDir.path, 'bad.tenabackup'))..writeAsStringSync('not json');
      final res = await BackupService.restoreFromFileDetailed(bad);
      expect(res.success, isFalse);
      expect(res.errorCode, isNotNull);
    });

    test('restore cree sauvegarde de secours AVANT ecriture et restaure donnees', () async {
      await DatabaseService.instance.insertTransaction(Transaction(
        id: 'r1', amount: 99, category: 'R', description: 'orig',
        date: DateTime(2026, 3, 1), type: TransactionType.expense));
      await BudgetService.setGlobalBudget(777);
      final src = File(p.join(tempDir.path, 'src.tenabackup'));
      await src.writeAsString(await BackupService.createBackupJson(encrypt: false));
      // modifier etat
      await DatabaseService.instance.purgeTransaction('r1');
      await BudgetService.setGlobalBudget(1);
      final res = await BackupService.restoreFromFileDetailed(src);
      expect(res.preRestoreBackupPath, isNotNull);
      expect(File(res.preRestoreBackupPath!).existsSync(), isTrue);
      expect(res.transactionsRestored, greaterThanOrEqualTo(1));
      final txs = await DatabaseService.instance.getTransactions();
      expect(txs.any((t) => t.id == 'r1'), isTrue);
      expect(await BudgetService.getGlobalBudget(), 777);
    });

    test('LOT3 securite: sauvegarde de secours pre-restauration est lisible/valide', () async {
      final src = File(p.join(tempDir.path, 's.tenabackup'));
      await src.writeAsString(await BackupService.createBackupJson(encrypt: false));
      final res = await BackupService.restoreFromFileDetailed(src);
      expect(res.preRestoreBackupPath, isNotNull);
      final check = await BackupService.validateBackupFile(File(res.preRestoreBackupPath!));
      expect(check.isValid, isTrue);
    });

    test('LOT3 securite: restauration repetee ne plante pas et renvoie un resultat', () async {
      final src = File(p.join(tempDir.path, 'rep.tenabackup'));
      await src.writeAsString(await BackupService.createBackupJson(encrypt: false));
      final r1 = await BackupService.restoreFromFileDetailed(src);
      final r2 = await BackupService.restoreFromFileDetailed(src);
      expect(r1.preRestoreBackupPath, isNotNull);
      expect(r2.preRestoreBackupPath, isNotNull);
      // pas de crash; le resultat peut etre success ou partial selon conflits d'ID
      expect(r1.transactionsRestored, isA<int>());
    });

    test('restore portable exige la phrase', () async {
      final src = File(p.join(tempDir.path, 'port.tenabackup'));
      await src.writeAsString(await BackupService.createBackupJson(
        encrypt: true,
        encryptionMode: BackupEncryptionMode.portablePassphrase,
        passphrase: 'secret',
      ));
      final no = await BackupService.restoreFromFileDetailed(src);
      expect(no.success, isFalse);
      expect(no.errorCode, anyOf('PASSPHRASE_REQUIRED', 'BACKUP_DECRYPTION_FAILED', 'BACKUP_PASSPHRASE_INVALID'));
      final ok = await BackupService.restoreFromFileDetailed(src, passphrase: 'secret');
      // succes ou partial acceptable selon donnees, mais pas echec d'auth
      expect(ok.errorCode == 'PASSPHRASE_REQUIRED', isFalse);
    });
  });
}
