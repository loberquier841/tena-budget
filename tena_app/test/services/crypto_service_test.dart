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

    test('un nombre illisible vaut zéro sans faire échouer la lecture', () async {
      expect(await CryptoService.decryptNumber('tena1:corrompu'), 0);
      expect(await CryptoService.decryptNumber('pas un nombre'), 0);
    });

    test('la clé est générée puis conservée par le keystore', () async {
      expect(store.value, isNull);

      final chiffre = await CryptoService.encrypt('A');

      expect(store.value, isNotNull);

      // Une clé déjà existante est réutilisée, jamais remplacée : sinon les
      // données déjà écrites deviendraient indéchiffrables.
      final avant = store.value;

      await CryptoService.encrypt('B');

      expect(store.value, avant);
      expect(await CryptoService.decrypt(chiffre), 'A');
    });

    test('la clé n’est lue qu’une fois par session', () async {
      await CryptoService.encrypt('A');
      final lecturesApresPremier = store.reads;

      await CryptoService.encrypt('B');
      await CryptoService.encrypt('C');

      // Sans mémorisation, chaque écriture relirait le keystore.
      expect(store.reads, lecturesApresPremier);
    });

    test('invalidate relit la clé depuis le keystore', () async {
      final chiffre = await CryptoService.encrypt('Avant');

      CryptoService.invalidate();

      expect(await CryptoService.decrypt(chiffre), 'Avant');
    });

    test('un contenu altéré est refusé au lieu d’être devolvu', () async {
      final chiffre = await CryptoService.encrypt('Sensible');

      // On inverse les deux derniers caractères du corps chiffré.
      final corps = chiffre.substring('tena1:'.length);
      final altere =
          'tena1:${corps.substring(0, corps.length - 2)}'
          '${corps[corps.length - 1]}${corps[corps.length - 2]}';

      await expectLater(
        () => CryptoService.decrypt(altere),
        throwsA(isA<Object>()),
      );
    });

    test('reset supprime la clé persistée', () async {
      await CryptoService.encrypt('A');

      expect(store.value, isNotNull);

      await CryptoService.reset();

      expect(store.value, isNull);
    });
  });

  group('PreferencesKeyStore', () {
    test('conserve la clé dans les préférences de l’application', () async {
      SharedPreferences.setMockInitialValues({});

      final prefsStore = PreferencesKeyStore(
        SharedPreferences.getInstance,
      );

      expect(await prefsStore.read(), isNull);

      await prefsStore.write('clé-de-test');

      expect(await prefsStore.read(), 'clé-de-test');

      await prefsStore.delete();

      expect(await prefsStore.read(), isNull);
    });
  });
}
