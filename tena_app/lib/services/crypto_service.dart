import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

/// Source de la clé maîtresse de chiffrement.
///
/// Cette interface isole le chiffrement de tout mécanisme de stockage : la
/// couche SQLite appelle [CryptoService] sans savoir d'où vient la clé. Cela
/// évite que l'ouverture de la base dépende d'un composant Flutter, et permet
/// de brancher un keystore système sans toucher au reste du code.
abstract class SecretKeyStore {
  /// Renvoie la clé au format base64, ou `null` si aucune clé n'existe encore.
  Future<String?> read();

  /// Conserve la clé au format base64.
  Future<void> write(String keyBase64);

  /// Supprime définitivement la clé.
  Future<void> delete();
}

/// Chiffrement des données sensibles au repos.
///
/// Le fichier SQLite est une base en clair : n'importe quelle application
/// pouvant le lire (sauvegarde, déverrouillage de l'appareil, extraction du
/// stockage) donne accès aux montants et aux libellés. Ce service chiffre les
/// champs sensibles (montant, description, note) en AES-GCM avant écriture et
/// les déchiffre à la lecture.
///
/// GCM (et non CBC) car il est authentifié : toute altération du contenu
/// chiffré est détectée au déchiffrement au lieu de produire des données
/// silencieusement corrompues.
class CryptoService {
  static const int _keyLength = 32; // AES-256

  /// Préfixe permettant de distinguer une valeur chiffrée d'une valeur en
  /// clair, donc de migrer les données existantes sans les altérer.
  static const String _marker = 'tena1:';

  static final AesGcm _algorithm = AesGcm.with256bits();

  static final Random _random = Random.secure();

  static SecretKeyStore? _store;

  /// Clé résolue pour la session courante, et la promesse correspondante.
  ///
  /// La clé n'est lue qu'une seule fois : sans cette mémorisation, chaque
  /// ligne relue ou écrite déclencherait un accès au keystore.
  static String? _cachedKeyBase64;
  static Future<String>? _pendingKey;

  /// Clé utilisée lorsqu'aucune source n'est configurée.
  ///
  /// Elle n'est écrite nulle part : elle existe pour que le chiffrement reste
  /// utilisable dans un contexte sans stockage. En production, [useKeyStore]
  /// installe une source persistante.
  static final String _ephemeralKey = _generateKey();

  /// Remplace la source de la clé.
  static void useKeyStore(SecretKeyStore store) {
    _store = store;
    invalidate();
  }

  /// Oublie la clé mémorisée : la prochaine opération la relit depuis la
  /// source configurée.
  static void invalidate() {
    _cachedKeyBase64 = null;
    _pendingKey = null;
  }

  static String _generateKey() {
    final bytes = List<int>.generate(_keyLength, (_) => _random.nextInt(256));

    return base64Encode(bytes);
  }

  /// Clé maîtresse, résolue une seule fois puis réutilisée.
  static Future<String> _masterKey() {
    final cached = _cachedKeyBase64;

    if (cached != null) return Future<String>.value(cached);

    return _pendingKey ??= _resolveKey();
  }

  static Future<String> _resolveKey() async {
    final store = _store;

    // Sans source configurée, on utilise une clé de session : le chiffrement
    // fonctionne mais ne survit pas au redémarrage, ce qui vaut mieux qu'une
    // exception pour une base qui vient d'être ouverte.
    if (store == null) return _ephemeralKey;

    final existing = await store.read();

    if (existing != null && existing.isNotEmpty) return existing;

    final created = _generateKey();

    await store.write(created);

    return created;
  }

  static bool _isEncrypted(String value) => value.startsWith(_marker);

  /// Chiffre une valeur. Les valeurs déjà chiffrées sont renvoyées telles
  /// quelles pour rendre l'opération idempotente.
  static Future<String> encrypt(String plainText) async {
    // Garde d'idempotence : sans elle, une valeur déjà chiffrée (par exemple
    // lors d'une seconde migration) serait chiffrée une seconde fois et ne
    // pourrait plus être relue.
    if (_isEncrypted(plainText)) return plainText;

    final keyBase64 = await _masterKey();

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: SecretKey(base64Decode(keyBase64)),
    );

    return '$_marker${base64Encode(secretBox.concatenation())}';
  }

  /// Déchiffre une valeur.
  ///
  /// Les données écrites avant la mise en place du chiffrement ne portent pas
  /// le préfixe : elles sont renvoyées en clair, ce qui rend la migration
  /// progressive et sans risque.
  static Future<String> decrypt(String value) async {
    if (!_isEncrypted(value)) return value;

    final keyBase64 = await _masterKey();

    final payload = base64Decode(value.substring(_marker.length));

    final secretBox = SecretBox.fromConcatenation(
      payload,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );

    final clear = await _algorithm.decrypt(
      secretBox,
      secretKey: SecretKey(base64Decode(keyBase64)),
    );

    return utf8.decode(clear);
  }

  /// Chiffre un nombre en le représentant sous forme de texte.
  static Future<String> encryptNumber(double value) {
    return encrypt(value.toString());
  }

  /// Déchiffre un nombre. Une valeur illisible ne fait pas échouer la lecture
  /// de toute la base : elle vaut zéro et le contenu fautif est ignoré.
  static Future<double> decryptNumber(String value) async {
    if (!_isEncrypted(value)) return double.tryParse(value) ?? 0;

    try {
      return double.tryParse(await decrypt(value)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Supprime la clé persistée, rendant les données chiffrées illisibles.
  ///
  /// Réservé à la réinitialisation complète de l'application.
  static Future<void> reset() async {
    final store = _store;

    if (store != null) {
      await store.delete();
    }

    invalidate();
  }

  /// Impose une clé connue. Réservé aux tests.
  @visibleForTesting
  static void debugSetKey(String? keyBase64) {
    _cachedKeyBase64 = keyBase64;
    _pendingKey = keyBase64 == null ? null : Future<String>.value(keyBase64);
  }
}

/// Source de clé conservée dans les préférences de l'application.
///
/// `SharedPreferences` n'est protégé par aucun keystore système : sur un
/// appareil déverrouillé, un attaquant capable de lire le stockage lit aussi
/// cette clé. Elle protège donc de l'extraction isolée du fichier SQLite, pas
/// d'une compromission complète du stockage. Voir [SecretKeyStore] pour la
/// remplacer par un keystore matériel.
class PreferencesKeyStore implements SecretKeyStore {
  static const String keyName = 'tena_budget_master_key';

  /// Résout les préférences à la demande plutôt qu'au moment de la
  /// construction : la base peut être ouverte avant que le binding Flutter
  /// ne soit prêt.
  final Future<dynamic> Function() _prefsFactory;

  const PreferencesKeyStore(this._prefsFactory);

  @override
  Future<String?> read() async {
    final prefs = await _prefsFactory();

    return prefs.getString(keyName) as String?;
  }

  @override
  Future<void> write(String keyBase64) async {
    final prefs = await _prefsFactory();

    await prefs.setString(keyName, keyBase64);
  }

  @override
  Future<void> delete() async {
    final prefs = await _prefsFactory();

    await prefs.remove(keyName);
  }
}
