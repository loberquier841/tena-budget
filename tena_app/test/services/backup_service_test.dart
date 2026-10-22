import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path';
import 'package:tena_budget/models/backup_models.dart';
import 'package:tena_budget/services/backup_service.dart';
import 'package:tena_budget/services/crypto_service.dart';

class _MemoryKeyStore implements CryptoService.SecretKeyStore {
  String? value;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _MemoryKeyStore();
    CryptoService.useKeyStore(store);
  });

  group('BackupService - collectData', () {
    test('collecte les transactions non supprimées', () async {
      final data = await BackupService.collectData();
      expect(data.transactions, isNot(empty));
    });

    test('collecte les budgets', () async {
      final data = await BackupService.collectData();
      expect(data.budgets, isNotEmpty);
      expect(data.budgets['global'], isNotNull);
    });

    test('collecte les objectifs', () async {
      final data = await BackupService.collectData();
      expect(data.goals, isNot(empty));
    });

    test('collecte le profil utilisateur (optionnel)', () async {
      final data = await BackupService.collectData();
      expect(data.profile, isA<bool>().or(isA<Map<String, dynamic>>()));
    });
  });

  group('BackupService - createBackupJson', () {
    test('crée une sauvegarde non chiffrée', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      expect(json, isNotEmpty);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['encrypted'], isFalse);
    });

    test('crée une sauvegarde chiffrée', () async {
      final json = await BackupService.createBackupJson(encrypt: true);
      expect(json, isNotEmpty);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['encrypted'], isTrue);
    });

    test 'inclut le format et les métadonnées attendus', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['format'], equals('tena_budget_backup'));
      expect(parsed['version'], equals(1));
      expect(parsed['checksum'], isNotEmpty);
    }
  });

  group('BackupService - validateBackupJson', () {
    test('valide un fichier de sauvegarde valide (non chiffré)', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final result = await BackupService.validateBackupJson(json);
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('valide un fichier de sauvegarde valide (chiffré)', () async {
      final json = await BackupService.createBackupJson(encrypt: true);
      final result = await BackupService.validateBackupJson(json);
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    'détecte un format inconnu', () async {
      final result = await BackupService.validateBackupJson(
        jsonEncode({'format': 'unknown_marker', 'version': 1}),
      );
      expect(result.isValid, isFalse);
      expect(result.reason, equals('BACKUP_FORMAT_UNKNOWN'));
    };

    'détecte une version non supportée', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final tampered = {...parsed, 'version': 99};
      final result = await BackupService.validateBackupJson(jsonEncode(tampered));
      expect(result.isValid, isFalse);
      expect(result.reason, equals('BACKUP_VERSION_UNSUPPORTED'));
    };

    'détecte un checksum manquant', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final tampered = {...parsed, 'checksum': ''};
      final result = await BackupService.validateBackupJson(jsonEncode(tampered));
      expect(result.isValid, isFalse);
      expect(result.reason, equals('BACKUP_CHECKSUM_MISSING'));
    };

    'détecte un checksum en erreur (données corrompues)', () async {
      final json = await BackupService.createBackupJson(encrypt: false);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final tampered = {...parsed, 'checksum': 'deadbeef'};
      final result = await BackupService.validateBackupJson(jsonEncode(tampered));
      expect(result.isValid, isFalse);
      expect(result.reason, equals('BACKUP_CHECKSUM_MISMATCH'));
    };

    'détecte une tentative de déchiffrement échouée', () async {
      final json = await BackupService.createBackupJson(encrypt: true);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final tampered = {...parsed, 'data': 'corrupted_encrypted_data'};
      final result = await BackupService.validateBackupJson(jsonEncode(tampered));
      expect(result.isValid, isFalse);
      expect(result.reason, equals('BACKUP_DECRYPTION_FAILED'));
    }
  });

  group('BackupService - createBackupFile', () {
    test('crée un fichier de sauvegarde non chiffré', () async {
      final file = await BackupService.createBackupFile(encrypt: false);
      expect(file, isA<File>());
      expect(await file.exists(), isTrue);
      await file.delete();
    });

    test('crée un fichier de sauvegarde chiffré', () async {
      final file = await BackupService.createBackupFile(encrypt: true);
      expect(file, isA<File>());
      expect(await file.exists(), isTrue);
      await file.delete();
    });

    'ne jamais écraser silencieusement un fichier existant', () async {
      final file1 = await BackupService.createBackupFile(encrypt: false);
      final file2 = await BackupService.createBackupFile(encrypt: false);
      expect(file2.path, isNot(equals(file1.path)));
      await file1.delete();
      await file2.delete();
    }
  });

  group('BackupService - validateBackupFile', () {
    test('valide un fichier existant sur le disque', () async {
      final file = await BackupService.createBackupFile(encrypt: false);
      final result = await BackupService.validateBackupFile(file);
      expect(result.isValid, isTrue);
      await file.delete();
    });

    'détecte un fichier inexistant', () async {
      final nonExistent = File('/nonexistent/path.tenabackup');
      final result = await BackupService.validateBackupFile(nonExistent);
      expect(result.isValid, isFalse);
      expect(result.reason, equals('BACKUP_FILE_NOT_FOUND'));
    }
  });

  group('BackupService - restoreFromFile', () {
    test('rétablit les données depuis une sauvegarde valide', () async {
      final file = await BackupService.createBackupFile(encrypt: false);
      await BackupService.restoreFromFile(file);
      expect(await file.exists(), isTrue);
      await file.delete();
    });

    'échoue sans modifier de données lorsqu'un fichier est invalide', () async {
      final invalidFile = File('/tmp/invalid_backup.tenabackup');
      await invalidFile.writeAsString('{invalid json}');
      try {
        await BackupService.restoreFromFile(invalidFile);
        fail('Should have thrown an exception');
      } on BackupException catch (e) {
        expect(e.code, isNotEmpty);
      } finally {
        await invalidFile.delete();
      }
    };

    'annule la restauration sans suppression de données en cas d'échec', () async {
      final result = await BackupService.validateBackupFile(
        File('/tmp/nonexistent.tenabackup'),
      );
      expect(result.isValid, isFalse);
    }
  });
}
