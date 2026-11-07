/// Périmètre utilisateur actif (local-first, mono-profil sécurisé).
///
/// L'architecture DB/services supporte `userId`; le produit actuel est
/// mono-profil explicite (`primary`) pour éviter toute fuite/collision.
/// Aucune donnée n'est partagée entre scopes : tout accès passe par ce scope.
class AppScope {
  const AppScope._();

  /// Identifiant local du profil actif. Ne jamais deviner/partager entre profils.
  static const String activeUserId = 'primary';
}
