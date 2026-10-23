import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';

/// Source de clé adossée au keystore du système.
///
/// - Android : Keystore (stockage `EncryptedSharedPreferences`)
/// - iOS / macOS : Keychain, avec synchronisation iCloud désactivée pour que la
///   clé ne quitte jamais l'appareil
/// - Windows : DPAPI
/// - Linux : relieset (libsecret), avec repli documenté
///
/// Contrairement aux préférences, la clé est protégée par le système et n'est
/// pas lisible par une simple extraction du stockage de l'application.
class SecureStorageKeyStore implements SecretKeyStore {
  static const String _keyName = 'tena_budget_master_key';

  /// Options par défaut de `flutter_secure_storage` :
  /// - Android : Keystore avec enveloppement de clé RSA-OAEP et AES-GCM, qui est
  ///   désormais le comportement par défaut (l'ancien
  ///   `encryptedSharedPreferences` n'existe plus en 11.x) ;
  /// - iOS / macOS : Keychain, avec synchronisation iCloud désactivée pour que
  ///   la clé ne quitte jamais l'appareil ;
  /// - Windows : DPAPI.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  /// Préférences utilisées si le keystore est indisponible sur la plateforme.
  final SecretKeyStore _fallback;

  const SecureStorageKeyStore({SecretKeyStore? fallback})
    : _fallback = fallback ?? const _FallbackKeyStore();

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _keyName);
    } catch (_) {
      // Plateforme sans keystore utilisable, ou Keychain inaccessible : on
      // retombe sur les préférences plutôt que de perdre les données.
      return _fallback.read();
    }
  }

  @override
  Future<void> write(String keyBase64) async {
    try {
      await _storage.write(key: _keyName, value: keyBase64);
    } catch (_) {
      await _fallback.write(keyBase64);
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {
      // Rien à supprimer dans le keystore : on poursuit vers le repli.
    }

    await _fallback.delete();
  }
}

/// Repli explicite lorsque la plateforme ne fournit aucun keystore.
///
/// Sans ce repli, une erreur « clé absente » ferait porter à l'utilisateur la
/// perte de ses données chiffrées. Ce magasin ne fonctionne pas : il rend
/// l'échec visible et testable plutôt que silencieux.
class _FallbackKeyStore implements SecretKeyStore {
  const _FallbackKeyStore();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String keyBase64) async {
    throw StateError(
      "Aucun keystore disponible : la clé de chiffrement ne peut pas être "
      "conservée, les données chiffrées seraient perdues au redémarrage.",
    );
  }

  @override
  Future<void> delete() async {}
}
