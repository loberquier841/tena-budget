# Rapport d'audit C24 — Gestion des clés et récupération des données

**Mission** : Examen des risques de sécurité liés au chiffrement, au stockage des clés et à la migration des données dans TENΛ Budget.

**Date** : 2025-10-22

**Environnement** : Analyse statique sur codebase Flutter/Dart. environnement Flutter non disponible ; seuls les lectures de code sont possibles.
---
## 1. Composants examinés

### 1.1 `crypto_service.dart`

| Ligne | Élément | Description |
|------|---------|-------------|
| 56 | `static SecretKeyStore? _store` | Source de clé maître configurable |
| 62 | `static String? _cachedKeyBase64` | Cache de la clé lue |
| 63 | `static Future<String>? _pendingKey` | Promesse de clé en cours de résolution |
| 70 | `static final String _ephemeralKey = _generateKey()` | Clé éphémère générée aléatoirement au démarrage |
| 73 | `static void useKeyStore(SecretKeyStore store)` | Remplace la source de clé par une source persistante |
| 78 | `static void invalidate()` | Efface le cache de clé en mémoire |
| 85 | `static String _generateKey()` | Génère une nouvelle clé aléatoire en base64 (32 octets = AES-256) |
| 92 | `static Future<String> _masterKey()` | Résout la clé maître : cache → pending → store → éphémère |
| 115 | `static Future<String> decrypt(String value)` | Déchiffrement AES-256 GCM avec préfixe `tena1:` |
| 166 | `static Future<String> encryptNumber(double value)` | Encapsule `encrypt(value.toString())` |
| 176 | `static Future<double> decryptNumber(String value)` | Déchiffre un montant ; lève `CryptoException` au lieu de retourner `0` |
| 193 | `static Future<void> reset()` | Supprime la clé persistée → rend toutes les données chiffrées irrecoverables |
| 208 | `static void debugSetKey(String? keyBase64)` | Définit une clé connue (réservé aux tests) |
| 221 | `class PreferencesKeyStore implements SecretKeyStore` | Stocke la clé dans `SharedPreferences` sous `tena_budget_master_key` |
| 232 | `Future<String?> read()` | Lit la clé depuis SharedPreferences |
| 239 | `Future<void> write(String keyBase64)` | Écrit la clé dans SharedPreferences |
| 246 | `Future<void> delete()` | Supprime la clé de SharedPreferences |
---
## 1.2 `database_service.dart`

| Ligne | Élément | Description |
|------|---------|-------------|
| 76 | `static const int _schemaVersion = 5` | Version actuelle du schéma SQLite |
| 78 | `Future<Database> _initDatabase()` | Initialise la base ; enchaîne les migrations v1→v5 |
| 96 | `if (oldVersion < 2) await _migrateToV2(db)` | Migration v1→v2 : ajoute `notes` et `is_deleted` |
| 100 | `if (oldVersion < 3) await _migrateToV3(db)` | Migration v2→v3 : chiffre toutes les données existantes |
| 104 | `if (oldVersion < 4) await _createUserProfileSchema(db)` | Création du schéma utilisateur v4 |
| 108 | `if (oldVersion < 5) { await _createBudgetsSchema(db); await _createGoalsSchema(db) }` | Migration v4→v5 : tables budgets et objectifs chiffrés |
| 210 | `Future<Map<String, Object?>> _toRow(model.Transaction transaction)` | Convertit le modèle en ligne ; chiffre `amount`, `description`, `notes` |
| 268 | `Future<model.Transaction> _toTransaction(Map<String, Object?> row)` | Convertit la ligne en modèle ; déchiffre les champs sensibles |
| 346 | `Future<model.BudgetEntry> _budgetFromRow(Map<String, Object?> row)` | Extrait un budget ; déchiffre `amount_cents` |
| 388 | `Future<model.GoalEntry> _goalFromRow(Map<String, Object?> row)` | Extrait un objectif ; déchiffre `target_cents` et `saved_cents` |
| 419 | `Future<void> _migrateToV3(Database db)` | Pour chaque ligne : lit → chiffre → réécrit dans la même table |
---
## 1.3 `secure_key_store.dart`

| Ligne | Élément | Description |
|------|---------|-------------|
| 15 | `class SecureStorageKeyStore implements SecretKeyStore` | Adossé au keystore système (Android Keystore, iOS Keychain) |
| 25 | `static const FlutterSecureStorage _storage` | Stockage sécurisé Flutter avec options plateforme |
| 33 | `final SecretKeyStore _fallback` | Stockage de repli si keystore unavailable |
| 35 | `const SecureStorageKeyStore({SecretKeyStore? fallback})` | Constructeur avec clé optional de repli |
| 39 | `Future<String?> read()` | Essaye d'abord le keystore, retombe sur les préférences |
| 42 | `catch (_) { return _fallback.read(); }` | Gestion d'erreur : keystore inaccessible → préférences |
| 49 | `Future<void> write(String keyBase64)` | Écrit dans le keystore ; retombe sur préférences |
| 58 | `Future<void> delete()` | Supprime du keystore ; appelle toujours le fallback |
---
## 1.4 `category_service.dart`

| Ligne | Élément | Description |
|------|---------|-------------|
| 24 | `static Future<List<String>> getCategories()` | Lit les catégories depuis SharedPreferences ; gère retrocompatibilité clair/chiffré |
| 34 | `try { final decrypted = await CryptoService.decrypt(raw); ... } catch (_) { ... données en clair ... }` | Si le déchiffrement échoue, lit en clair pour compatibilité descendante |
| 49 | `static Future<void> saveCategories(...)` | Enregistre les catégories chiffrées |
---
## 1.5 Fichiers et lignes de test

- `tena_app/test/services/crypto_service_test.dart` — test C06 : "un nombre illisible lève une erreur au lieu de retourner zéro"
- `tena_app/lib/services/database_service.dart.backup` — sauvegarde de la base de données (non à supprimer)
- `tena_app/lib/services/database_service.dart.backup_transactions_v2` — sauvegarde transactions v2
---

## 2. Scénarios étudiés et risques confirmés

### 2.1 Redémarrage normal de l'application

- **Si `useKeyStore()` a été appelé avec `PreferencesKeyStore` ou `SecureStorageKeyStore`** : La clé est persistée et rétablie au prochain lancement. Les données chiffrées restent **déverrouillables**.
- **Si aucune source persistante n'est configurée** (usage par défaut de `_ephemeralKey`) : Une nouvelle clé est générée au démarrage. **Toutes les données chiffrées précédentes deviennent irrecoverables**, car la clé originale n'est plus nulle part.
- **Si `PreferencesKeyStore` est utilisé sans keystore système** : La clé est stockée dans `SharedPreferences`. Au redémarrage, elle est rechargée et les données restent déverrouillables, mais la clé n'est pas protégée par le système exploitable.
### 2.2 Clé éphémère par défaut

| Sévérité | Description |
|----------|-------------|
| **Élevée** | `_ephemeralKey` générée aléatoirement au démarrage. Si elle change, **toutes** les données chiffrées deviennent irrecoverables. Non résolu si `useKeyStore()` n'est pas appelé en production. |
| **Référence** | Lignes 70 et 92 du `crypto_service.dart`. |
### 2.3 Stockage clé dans SharedPreferences

| Sévérité | Description |
|----------|-------------|
| **Élevée** | `PreferencesKeyStore` stocke la clé dans `SharedPreferences`, protégée contre l'extraction isolée du fichier SQLite mais pas contre une compromission complète du stockage appareil déverrouillé. |
| **Référence** | Lignes 221-246 du `crypto_service.dart`. |
### 2.4 Perte de clé via `reset()`

| Sévérité | Description |
|----------|-------------|
| **Critique** | Si la clé maîtresse est supprimée via `CryptoService.reset()` ou autrement : `reset()` appelle `store.delete()` puis `invalidate()`. La clé en mémoire est effacée. Si `PreferencesKeyStore` était utilisé → La clé est supprimée de SharedPreferences. **Toutes les données financières chiffrées deviennent illisibles indéfiniment.** Si `SecureStorageKeyStore` était utilisé → La clé est supprimée du keystore, mais le fallback retourne `null`. **Aucune procédure de récupération/clé de secours n'existe actuellement.** |
| **Référence** | Lignes 193 et 208 du `crypto_service.dart`. |
### 2.5 Échec de migration

| Sévérité | Description |
|----------|-------------|
| **Moyenne** | Le schéma migre v1 → v2 → v3 → v4 → v5 par étapes successives. **Risque** : Si un utilisateur est resté sur v1 ou v2 (ex. installation ancienne non mise à jour), les données peuvent être en clair ou partiellement protégées. La migration v2→v3 chiffre les données existantes en lisant chaque ligne et réécrivant chiffrée. La migration v4→v5 ajoute les tables budgets et objectifs chiffrés. **Point de risque** : Une migration manquée ou interrompue laisserait certains champs en clair non protégés par le chiffrement AES-GCM. Vérification : Aucune vérification de version de schéma au démarrage n'existe dans le code lu ; la version `_schemaVersion = 5` est définie mais non comparée à la version stockée en base. |
| **Référence** | Lignes 76, 78, 96-108 et 210-268 du `database_service.dart`. |
### 2.6 Stockage des catégories via SharedPreferences
---

## 3. Plan de correction priorisé

### 3.1 Priorité Critique (à mettre en production impérativement)

1. **Remplacer `PreferencesKeyStore` par `SecureStorageKeyStore` par défaut**
   - Modifier le point d'entrée de l'application pour appeler `CryptoService.useKeyStore(SecureStorageKeyStore())` au lieu de ou en complément de toute clé par défaut éphémère.
   - `SecureStorageKeyStore` adosse la clé au keystore système (Android Keystore, iOS Keychain avec synchronisation iCloud désactivée).
   - La clé n'est plus stockée dans `SharedPreferences` vulnérable.

2. **Ajouter une vérification de version de schéma au démarrage**
   - Lire la version du schéma depuis la base de données (table de métadonnées ou fichier de préférences).
   - Si la version < 5, forcer/migrer ou alerter l'utilisateur.
   - Cela prévient le risque de données partiellement migrées (risque n°4).

3. **Ne jamais appeler `CryptoService.reset()` en conditions normales**
   - Documenter que `reset()` est réservé à la réinitialisation complète de l'application (support/utilisateur avancé).
   - S'assurer qu'aucun chemin de code normal n'y conduit accidentellement.

### 3.2 Priorité Élevée (améliorations de sécurité)

4. **Mécanisme d'exportation/importation de la clé maître en tant que procédure de secours**
   - Prévoir un mécanisme d'exportation/importation de la clé maîtresse chiffrée protégée par mot de passe utilisateur.
   - Cela permettrait la récupération si l'appareil est perdu mais que l'utilisateur se souvient de son mot de passe de récupération.

5. **Ajouter une alerte au premier lancement si aucune clé persistante n'est configurée**
   - Informer l'utilisateur que les données seront perdues si l'application est réinstallée.
   - Proposer d'activer le stockage dans le Keychain/Keystore système.

### 3.3 Priorité Moyenne (robustesse et compatibilité)

6. **Ajouter une migration de sécurité pour les anciennes données en clair**
   - Si des données en clair (schéma v1/v2) sont détectées au démarrage, les chiffrer automatiquement avec la clé courante.
   - Cela élimine progressivement le stock de données non protégées.

7. **Améliorer la gestion des catégories stockées en clair**
   - Dans `CategoryService.getCategories()`, ajouter une étape de migration chiffrée si les données sont en clair et qu'une clé maîtresse est disponible.

### 3.4 Priorité Facultative (expérience utilisateur)

8. **Interface de backup/restore de la clé maître**
   - Bien que le sujet C18 existe déjà, envisager une intégration où l'utilisateur peut exporter/restaurer sa clé maîtresse (chiffrée par son mot de passe) avant une réinstallation ou changement d'appareil.

9. **Ajouter des tests unitaires pour les scénarios de perte de clé et de migration**
   - Bien que l'environnement Flutter ne soit pas disponible ici, prévoir des tests pour valider que `CryptoException` est levé plutôt que zéro silencieux dans tous les cas.

| Sévérité | Description |
|----------|-------------|
| **Moyenne** | La clé maître et les catégories sont stockées dans `SharedPreferences`. Accessibles si l'appareil est rooté/jailbreaké ou si le fichier de préférences est extrait. `SharedPreferences` n'est **pas** un keystore système ; elle protège de l'extraction isolée du fichier SQLite, mais pas d'une compromission complète de l'appareil. |
| **Référence** | Lignes 24 et 34 du `category_service.dart`. |
---

## 4. Méthode de validation adaptée

Pour valider les corrections dans un environnement Flutter :

1. **Test de redémarrage avec clé persistante** :
   - Configurer `PreferencesKeyStore` ou `SecureStorageKeyStore`.
   - Chiffrer des données, redémarrer l'application, vérifier que le déchiffrement réussit.

2. **Test de perte de clé** :
   - Appeler `CryptoService.reset()`, puis tenter de déchiffrer des données existantes.
   - S'attendre à ce que `CryptoException` soit levé (et non zéro silencieux).

3. **Test de migration de schéma** :
   - Simuler une base de données en version v1 ou v2.
   - Vérifier que la migration vers v5 réussit et que toutes les données sont chiffrées.

4. **Test de compatibilité catégories clair/chiffré** :
   - Avec `CategoryService.getCategories()` :
     - Première lecture : données en clair → doit basculer vers chiffré.
     - Deuxième lecture avec nouvelle clé → doit déchiffrer puis re-chiffrer.

5. **Vérification statique du code** :
   - S'assurer que `CryptoService.reset()` n'est appelé que dans les chemins de test/reinitialisation.
   - S'assurer que `useKeyStore()` est appelé au démarrage dans la configuration de production.
---

## 5. Conclusion

L'audit confirme que les principales risques tournent autour du **stockage de la clé maîtresse** et de sa **persistance**. Le passage de `PreferencesKeyStore` (SharedPreferences) à `SecureStorageKeyStore` (keystore système) est la correction la plus critique. Sans cette changement, la clé peut être perdue à tout moment lors de manipulations de l'utilisateur ou de réinstallation, entraînant une perte définitive de toutes les données financières chiffrées.

De plus, l'ajout d'une vérification de version de schéma au démarrage et d'une procédure de migration de sécurité pour les anciennes données en clair compléteraient une défense en profondeur contre la perte ou l'inaccessibilité des données.

**Prochaine correction minimale** : Forcer l'utilisation de `SecureStorageKeyStore` (ou au moins rendre `PreferencesKeyStore` optionnel avec alerte utilisateur) et ajouter la vérification de version de schéma au démarrage de la base de données.