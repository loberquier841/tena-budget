# Rapport d'audit technique C01 — TENΛ Budget

## 1. État de l'environnement d'exécution

| Outil | Disponibilité | Notes |
|-------|---------------|-------|
| **Flutter** | Non installé | Toutes les commandes `flutter test` sont reportées à un environnement disposant du SDK |
| **Dart** | Non installé | Version du SDK non vérifiable |
| **Analyse statique** | Disponible | Via `grep`, `awk`, `cat` sur les fichiers source ; `flutter analyze` non exécutable |

**Note** : L'ensemble des rapports C16, C18, C19, C24 confirme que l'environnement d'exécution ne dispose pas de Flutter/Dart. Toutes les validations reposent sur la lecture et la compréhension du code source.

---

## 2. Aperçu de l'architecture

Le projet TENΛ Budget est une application Flutter de gestion budgétaire locale-first (hors ligne) avec les caractéristiques suivantes :

- **Stockage persistant** : Base de données SQLite via `sqflite_common_ffi` (FFI, multi-plateforme dont Linux)
- **Chiffrement au repos** : AES-GCM via `cryptography` dart package ; champs sensibles (montants, libellés) chiffrés avant écriture
- **Gestion des clés** : Chaîne `SecureStorageKeyStore` → `libsecret` (système) ; repli vers `SharedPreferences` si keystore absent
- **Services principaux** :
  - `CryptoService` — chiffrement/déchiffrement, `CryptoException` (jamais de zéro silencieux)
  - `DatabaseService` — SQLite, schémas v1→v5, migrations, budgets/objectifs avec chiffrement
  - `CategoryService` — catégories via `SharedPreferences`, chiffrement avec rétrocompatibilité
  - `BudgetService` / `GoalService` — services de haut niveau s'appuyant sur `DatabaseService`
  - `SecureStorageKeyStore` — interface d'abstraction pour le stockage sécurisé des clés

---

## 3. Examen des services clés

### 3.1 `crypto_service.dart`

| Aspect | État | Observations |
|--------|------|--------------|
| `decryptNumber()` | ✅ Corrigé | Ne retourne plus silencieusement `0` en cas d'échec ; lève `CryptoException` |
| Comportement zéro silencieux | ✅ Résolu | Toute erreur de déchiffrement lève maintenant une exception explicite |
| `_ephemeralKey` | ⚠️ Risque élevé | Clé générée aléatoirement au démarrage ; changement de clé rend toutes les données chiffrées irrecoverables |
| `CryptoException` | ✅ Bien défini | Code `DECRYPT_FAILED`, `DECRYPT_PARSE_FAILED` ; héritage de `Exception` |
| Gestion des valeurs en clair | ✅ Correct | Si pas de préfixe `tena1:` → `double.tryParse`, garde `0` seulement si chaîne non numérique |

**Preuve code** (extrait `crypto_service.dart:176-191`) :
```dart
// Échec de déchiffrement -> erreur explicite, pas de valeur zéro silencieuse
throw CryptoException('DECRYPT_FAILED', 'Échec du déchiffrement du montant');
```

### 3.2 `database_service.dart`

| Aspect | État | Observations |
|--------|------|--------------|
| Schéma SQLite v5 | ✅ Documenté | v1→v2→v3→v4→v5, migrations successives |
| `resetForTesting()` | ✅ Présent | Remet `_database = null` ; les tests doivent gérer le singleton |
| Chiffrement des budgets/objectifs | ✅ Intégré | Schéma v5 ajoute tables `budgets` et `goals` chiffrés |
| Suppression logique | ✅ `is_deleted` | `1` = supprimé, les requêtes `WHERE is_deleted = 0` filtrent |
| `_budgetFromRow()` / `_goalFromRow()` | ✅ Propagation d'erreur | `catch CryptoException` → `rethrow` avec contexte |

**Migrations clés** :
- v2 : ajout `notes`, `is_deleted`, index date
- v3 : chiffrement AES-GCM des transactions existantes
- v4 : profil/questionnaire local chiffré (additive)
- v5 : tables budgets et objectives chiffrées (cohérente avec v3)

### 3.3 `category_service.dart`

| Aspect | État | Observations |
|--------|------|--------------|
| Rétrocompatibilité | ✅ Gérée | Données en clair (version antérieure) lues telles quelles, puis migrées |
| Chiffrement des catégories | ✅ Via `CryptoService` | `CryptoService.encrypt(jsonEncode(...))` / `CryptoService.decrypt()` |
| `addCategory / renameCategory / deleteCategory` | ✅ Correct | Vérifie les doublons (case-insensitive) |
| Préfixe `_key = 'tena_budget_categories'` | ✅ Constant | Partagé entre `getCategories()` / `saveCategories()` |

### 3.4 `secure_key_store.dart`

| Aspect | État | Observations |
|--------|------|--------------|
| `SecureStorageKeyStore` | ✅ Interface complète | `read()`, `write()`, `delete()` |
| `libsecret` (Linux) | ⚠️ Dépendance | `flutter_secure_storage` with `libsecret` ; repli `SharedPreferences` |
| `PreferencesKeyStore` | ✅ Repli | Stockage dans `SharedPreferences`, clé en clair (protection extractionisolée seulement) |
| `_UnavailableKeyStore` | ✅ Explicite | Lance `StateError` si pas de keystore disponible, pas de silence |

**Consequence du repli SharedPreferences** :
- La clé de chiffrement n'est pas protégée par le keystore système
- Sur un appareil déverrouillé, un attaquant lisant le stockage peut extraire la clé
- Protège de l'extraction isolée du fichier SQLite, pas d'une compromission complète

---

## 4. État des tests unitaires

| Fichier | Groupes de tests | Tests réels | Exécutabilité |
|---------|-----------------|-------------|----------------|
| `database_service_test.dart` | 4 groupes (budgets, objectifs, SQLite persistance, BudgetService/GoalSQLite) | 18 tests | Non exécutés (Flutter absent) |
| `preferences_services_test.dart` | 1 groupe (CategoryService) | 7 tests | Non exécutés (Flutter absent) |
| `analysis_services_test.dart` | Services divers | Vérifiable statique | Non exécuté |
| `crypto_service_test.dart` | Tests C06 (décryptNumber) | Vérifié par analyse statique | Non exécuté |

**Total** : 25 tests unitaires écrits mais non exécutés dans cet environnement.

**Détail par groupe** (depuis `database_service_test.dart`) :
- `DatabaseService — budgets` : 6 tests (création globale, création catégorie, écrasement, suppression, liste, chiffrement au repos)
- `DatabaseService — objectifs` : 4 tests (création/lecture, mise à jour ID, suppression logique, chiffrement au repos)
- `BudgetService — persistance SQLite` : 4 tests (défaut 0, catégories indépendantes, survie reset, erreur lecture)
- `GoalService — persistance SQLite` : 4 tests (vide départ, add/update/delete, survie reset, erreur lecture)
- `CategoryService` (préférences) : 7 tests (défaut, persistance, ajout sans doublon, renommer, pas doublon, suppression)

**Rapport C19** confirme : "❌ NON EXÉCUTÉS — Flutter/Dart non disponibles dans cet environnement."

---

## 5. Sécurité des montants financiers (référence C06 / C16)

| Contrôle | Résultat | Preuve |
|----------|----------|--------|
| `decryptNumber()` lève `CryptoException` en cas d'échec | ✅ RÉUSSI | `crypto_service.dart:189` |
| Transactions/budgets/objectifs ne retournent pas zéro silencieux | ✅ RÉUSSI | `_budgetFromRow()` et `_goalFromRow()` propagent les exceptions |
| Pas de transformation silencieuse montant → zéro | ✅ RÉUSSI | Logique corrigée `decryptNumber()` (l. 176-191) |
| Compatibilité anciennes catégories en clair ↔ nouvelles chiffrées | ✅ RÉUSSI | `CategoryService.getCategories()` gère les deux cas |
| Tests Flutter exécutés | ❌ NON TESTÉ | Environnement indisponible |
| Aucune régression de sécurité détectée | ✅ RÉUSSI | Toutes les ouvertures C06/C16 correctement implémentées |

**Risques identifiés** (rapport C16) :
- Clés de chiffrement éphémères → niveau ⚠️ Élevé (changement de clé = données irrecoverables)
- `PreferencesKeyStore` → niveau ⚠️ Élevé (stockage en clair dans SharedPreferences)
- Perte de clé → niveau ❌ Critique
- Données partiellement migrées → niveau ⚠️ Moyen

---

## 6. Problèmes corrigés ou en cours (périmètre C01-C24)

| Mission | Statut | Description |
|---------|--------|-------------|
| **C01** | ✅ Non créé | Rapport d'audit technique inexistant ; créé à la présente exécution |
| **C03** | ✅ Termulé | Linux compatibility ; build CMake, runner GTK, plugins enregistrés ; rapport `RAPPORT_C03_LINUX.md` |
| **C06** | ✅ Validé | `decryptNumber()` ne retourne plus 0 silencieusement ; exceptions lever systematically |
| **C16** | ✅ Validé | Sécurité des montants ; récapitulatif des contrôles C06 |
| **C18** | ⚠️ Voir rapport | Backup/Restore à examiner séparément |
| **C19** | ✅ Documenté | Tests SQLite ; 25 tests écrits, non exécutés ; aucune régression détectée |
| **C24** | ⚠️ Voir rapport | Gestion des clés ; SecureStorageKeyStore / PreferencesKeyStore / libsecret |

**Corrections effectuées dans le cadre des missions précédentes** :
- `decryptNumber()` : modification pour lever `CryptoException` à la place de retourner `0`
- `CategoryService` : gestion de la rétrocompatibilité données en clair → chiffrées
- `DatabaseService` : schémas de migration v1→v5, suppression logique `is_deleted`
- `SecureStorageKeyStore` : interface d'abstraction avec repli documenté vers `SharedPreferences`

Aucune de ces corrections n'a été effectuée par réécriture de l'application ; elles sont ciblées sur les points de sécurité et de compatibilité identifiés par les audits.

---

## 7. Risques restants et recommandations

| Risque | Niveau | Description | Recommandation |
|--------|--------|-------------|----------------|
| Clé éphémère `_ephemeralKey` | ⚠️ Élevé | Générée au démarrage, changement = données irrecoverables | Utiliser `useKeyStore()` avec `SecureStorageKeyStore` en production ; éviter les changements de clé en production |
| `PreferencesKeyStore` (repli) | ⚠️ Élevée | Clé stockée dans `SharedPreferences`, pas de protection keystore système | Remplacer par `SecureStorageKeyStore` avec `libsecret` sur les plateformes supportées |
| Perte de clé via `reset()` | ❌ Critique | `DatabaseService.resetForTesting()` / appel en production efface la clé | Prévoir procédure de récupération/clé de secours ; éviter `reset()` en production |
| Données partiellement migrées | ⚠️ Moyen | Installations en v1-v4 non migrées vers v5 ; champs en clair non protégés | Vérifier que toutes les installations sont en v5 ; ajouter vérificateur de schéma au démarrage |
| Tests non exécutables | ⚠️ Moyen | Flutter/Dart absents ; 25 tests écrits mais non validés runtime | Mettre à disposition un environnement Flutter pour `flutter test` et `flutter analyze` |
| Analyse statique Linux exclue | ⚠️ Faible | `analysis_options.yaml` exclude `linux/**` | Retirer `linux/**` si CI Linux disponible ; garder en l'attente d'un environnement cible |

---

## 8. Fichiers examinés

| Type | Chemin | Lignes |
|------|--------|--------|
| Rapport qualité | `docs/quality/RAPPORT_C01_AUDIT_TECHNIQUE.md` | Nouveau (créé lors de cette exécution) |
| Services | `lib/services/crypto_service.dart` | ~200 lignes |
| Services | `lib/services/database_service.dart` | ~200 lignes |
| Services | `lib/services/category_service.dart` | ~150 lignes |
| Services | `lib/services/secure_key_store.dart` | ~80 lignes |
| Tests | `test/services/database_service_test.dart` | ~280 lignes |
| Tests | `test/services/preferences_services_test.dart` | ~80 lignes |
| Autre | `analysis_options.yaml` | 12 lignes |
| Autre | `pubspec.yaml` / `pubspec.lock` | Dépendances |

---

## 9. Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `tena_app/docs/quality/RAPPORT_C01_AUDIT_TECHNIQUE.md` | Nouveau fichier créé (cet audit technique C01) |
| Aucune modification de code métier partagé | Toutes les corrections C06/C16 antérieures sont conservées ; aucun nouveau commit/push |

**Contrainte respectée** : Aucun fichier `.backup` supprimé, aucun code partagé écrasé, aucun GitHub commit/push effectué.

---

## 10. Conclusion

L'audit technique C01 de TENΛ Budget révèle une base de code saine sur les points de sécurité et d'architecture identifiés :

- **Points forts** : Gestion structurée des clés (`SecretKeyStore` / `SecureStorageKeyStore`), migrations SQLite progressives v1→v5, correction du zéro silencieux dans `decryptNumber()`, rétrocompatibilité catégories, propagation d'exceptions plutôt que valeurs par défaut masque.
- **Points d'attention** : Dépendance au keystore système (`libsecret`) avec repli `SharedPreferences`, clé éphémère risquée, tests non exécutables dans l'environnement courant, analyse statique excluant Linux.
- **Chiffrement** : AES-GCM avec authentification, pas de transformation silencieuse montant → zéro (depuis C06/C16).
- **Compatibilité Linux** : Infrastructure CMake/GTK fonctionnelle ; dépendances `sqflite_common_ffi`, `flutter_secure_storage_linux` enregistrées ; rapport C3 fait le point détaillé.

**Prochaines étapes** (si environnement Flutter disponible) :
1. `flutter analyze --platform linux` (retirer `linux/**` de `analysis_options.yaml`)
2. `flutter test test/services/` (valider les 25 tests unitaires)
3. Vérifier `libsecret-1-0` dispo sur la cible Linux
4. S'assurer que la clé maître utilise `SecureStorageKeyStore` et non le fallback `PreferencesKeyStore` en production

*Rapport généré dans le cadre de la Mission C01 — TENΛ Budget Audit Technique. Toutes les constatations sont vérifiables dans le code source et les rapports existants (C03, C06, C16, C19, C24).*
