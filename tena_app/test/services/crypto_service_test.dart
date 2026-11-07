import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/crypto_service.dart';

/// Keystore en mémoire : permet de contrôler la clé sans dépendre du
/// keystore du système, qui n'existe pas dans un test unitaire.
class _MemoryKeyStore implements SecretKeyStore {
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

  group('CryptoService', () {
    test('un texte chiffré se relit à l’identique', () async {
      const clair = 'Facture F-2026-014 — 1 250,00 €';

      final chiffre = await CryptoService.encrypt(clair);

      expect(await CryptoService.decrypt(chiffre), clair);
    });

    test('le texte chiffré ne contient plus le contenu en clair', () async {
      final chiffre = await CryptoService.encrypt('MotDePasseBancaire');

      expect(chiffre, isNot(contains('MotDePasseBancaire')));
      expect(chiffre.startsWith('tena1:'), isTrue);
    });

    test('deux chiffrements du même texte diffèrent', () async {
      // Un vecteur d'initialisation aléatoire par chiffrement évite qu'une base
      // divulguant deux lignes identiques révèle leur contenu.
      final a = await CryptoService.encrypt('Même valeur');
      final b = await CryptoService.encrypt('Même valeur');

      expect(a, isNot(b));
      expect(await CryptoService.decrypt(a), await CryptoService.decrypt(b));
    });

    test('une valeur déjà chiffrée n’est pas chiffrée deux fois', () async {
      final uneFois = await CryptoService.encrypt('Note');
      final deuxFois = await CryptoService.encrypt(uneFois);

      expect(deuxFois, uneFois);
      expect(await CryptoService.decrypt(deuxFois), 'Note');
    });

    test('une valeur en clair est renvoyée telle quelle', () async {
      // Donnée écrite avant la mise en place du chiffrement.
      expect(await CryptoService.decrypt('Ancienne note'), 'Ancienne note');
    });

    test('les nombres alleront et venir conservent leur valeur', () async {
      for (final value in [0.0, 12.5, 1999.99, -45.25]) {
        expect(
          await CryptoService.decryptNumber(
            await CryptoService.encryptNumber(value),
          ),
          value,
        );
      }
    });

    test('un nombre illisible lève une erreur au lieu de retourner zéro', () async {
      // Ce test vérifie que le correctif C06 empêche le déchiffrement
      // silencieux en zéro, qui pouvait fausser les finances de l'utilisateur.
      // Désormais, toute erreur de déchiffrement lève une CryptoException.
      await expectLater(
        () => CryptoService.decryptNumber('tena1:corrompu'),
        throwsA(isA<CryptoException>()),
      );
      await expectLater(
        () => CryptoService.decryptNumber('pas un nombre'),
        throwsA(isA<CryptoException>()),
      );
    });

    test('la clé est générée puis conservée par le keystore', () async {
      // La clé est générée à la première opération cryptographique puis persistée.
      await CryptoService.encrypt('probe');
      final key = await store.read();
      expect(key, isNotNull);
      expect(key, isNotEmpty);
    });
  });
}
