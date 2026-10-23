# RAPPORT DÉVELOPPEMENT APPLICATION WEB LOCALE — TENΛ Budget

## 1. Résumé

Cette mission vise à développer la véritable application web financière TENΛ Budget, permettant à un utilisateur de démarrer le questionnaire, remplir son profil, consulter son tableau de bord, créer et gérer transactions, budgets, objectifs d'épargne, importer/exporter des données, et utiliser les fonctions hors ligne.

L'application est une application **local-first** stockant les données dans IndexedDB via Dexie, avec chiffrement AES-GCM 256 des données sensibles. Tous les calculs financiers utilisent des entiers en centimes (pas de float) pour éviter les erreurs d'arrondi.

## 2. Architecture

L'application suit une architecture en couches claire :

- **Présentation** : Composants React Next.js (pages d'onboarding, transactions, budgets, objectifs, import, export, sauvegardes, dashboard)
- **Logique métier** : Fonctions pures dans `packages/core/src/` (validations, calculs financiers, création de données)
- **Persistance** : Dexie Database (IndexedDB) avec chiffrement via `localVault` (AES-GCM, PBKDF2 SHA-256)
- **Validation** : Fonctions de validation métier dans `packages/core/src/budget/`, `packages/core/src/product/`
- **Calculs financiers** : Toutes valeurs internes en Int centimes, aucun Float, isDeleted exclu, simulations exclues
- **Import/Export** : Pipeline 11 étapes pour CSV/XLSX, exports CSV/Excel/PDF

### Flux de données principaux :

1. **Onboarding → Vault → Profile → Dashboard** :
   - Utilisateur crée un passphrase de chiffrement local
   - Coffre AES-GCM créé et activé
   - Profil utilisateur chiffré persisté dans Dexie `userProfiles` table
   - Au chargement, le profil est lu, décrypté et affiché sur le dashboard
   - Les transactions, budgets, objectifs sont lus depuis leurs tables respectives

2. **Création transaction** :
   - Formulaire validé (libellé, personne, montant non nul)
   - `createTransaction()` appelé avec validation `validateTransactionAmount()`
   - Montant converti en entiers centimes via `toCents()`
   - Seuil 500€ nécessite confirmation propriétaire
   - Soft delete obligatoire (pas de suppression physique)

3. **Création budget** :
   - Formulaire validé (montant entier, mois requis pour budget mensuel)
   - `createBudget()` appelé avec validation `validateBudgetAmount()`
   - Seuil 500€ nécessite confirmation propriétaire
   - Pas de doublon (vérification par familyId + type + year + month + categoryId + personId)

4. **Création objectif d'épargne** :
   - Nom requis, cible positive entiere en centimes
   - `createSavingGoal()` appelé avec validation `validateSavingTarget()`
   - Seuil 500€ nécessite confirmation propriétaire
   - Contributions : `addContribution()` refuse 0, refuse passage négatif

5. **Import CSV/Excel** :
   - Pipeline 11 étapes via `import-engine` package
   - Détection colonnes, confiance 0-100, EUR + dates FR
   - Mapping doublons, prévisualisation, validation requise
   - Persistance vers Dexie via `createTransaction`, `createBudget`, `createSavingGoal`
   - Rapport détaillé à la fin

6. **Export des données** :
   - CSV : `prepareCsvExport()` avec conversion euros → centimes
   - Excel : `prepareExcelExport()` avec multiples sheets
   - PDF : `preparePdfExport()` avec résumé
   - Vérification des totaux avec `verifyExportTotals()`

7. **Sauvegardes et restauration** :
   - Export: exportation base de données + chiffrement AES-GCM + checksum SHA-256
   - Import: vérification checksum avant restauration, pas d'écrasement silencieux
   - Intégrité: checksum comparé avant toute restauration
   - Conflits: détection si override=false, confirmation avant remplacement

## 3. Fonctionnalités Développées

### Questionnaire et Profil (Priority 2)

- **8 étapes d'onboarding** : coffre/vault, mode foyer, pattern revenus, expérience budget, priorités, fonctions souhaitées, préférences notifications, récapitulatif
- Création passphrase locale (minimum 12 caractères)
- Chiffrement AES-GCM 256 des données sensibles
- Création profil utilisateur avec `createUserProfile()`
- Recommandations d'offre produit via `recommendForProfile()`
- Sauvegarde progression intermédiaire (`saveLocalOnboardingProgress`)
- Reprise après rechargement navigateur

### Transactions (Priority 2)

- Création de transactions avec validation complète :
  - Libellé obligatoire
  - Personne obligatoire (obligatoire en Étape 3)
  - Montant non nul, entier centimes
  - Seuil 500€ confirmation propriétaire
  - Source : manuel / import / banque
- Consultation avec filtres (personne, catégorie, source, date, montant)
- Tri (date, montant, libellé)
- Pagination
- Filtres de recherche
- Soft delete (obligatoire) avec restauration
- Réservation personId par transaction

### Budgets (Priority 3)

- Création budgets annuels/mensuels
- Validation : montant entier, mois requis pour mensuel, pas de doublon
- Seuil 500€ confirmation propriétaire
- Calcul restant via `calculateRemaining()` (transactions non supprimées filtrées par catégorie/budgetId)
- Liste budgets avec affichage montant restant et pourcentage consommé
- Archivage soft des budgets
- Personne séparée (global vs individuel, jamais mélangé)

### Objectifs d'épargne (Priority 3)

- Création objectifs avec nom et cible en centimes entiers
- Validation cible positive, entier uniquement
- Seuil 500€ confirmation propriétaire
- Contributions : validation entière positive, refus 0, refus négatif actuel
- Progression sans float : `percentInt = floor(current*100/target)`
- Dépassement possible (currentCents > targetCents)
- Archivage et suppression logique des objectifs

### Personnalisation et Isolement

- Profil unique `primary` avec `userId` tracking dans Dexie v5
- Toutes les tables (transactions, budgets, objectifs) incluent `userId = 'primary'` par défaut
- Isolation des données via `userId` dans les requêtes Dexie
- Migration additive v5 → ajoute `userId` sans perdre données existantes

## 4. Améliorations Apportées dans cette Session

### 4.1 Fonctions `toCents` et `fromCents` (packages/shared/src/index.ts)

**Avant** : `toCents = (euros) => Math.round(euros * 100)` sans validation

**Après** :
- `toCents` lance des erreurs pour `NaN` et valeurs non finies
- `fromCents` lance des erreurs pour `NaN` et valeurs non finies
- Validation stricte des entrées avant conversion
- Documentation des erreurs potentielles

### 4.2 Validation `validateBudgetAmount` (packages/core/src/budget/budget.ts)

**Avant** : Vérifiait seulement `!Number.isInteger()` et `amountCents < 0`

**Après** :
- Ajout vérification explicite `amountCents === 0` → erreur `BUDGET_ZERO_FORBIDDEN`
- Message d'erreur clair: "le montant ne peut pas être zéro"
- Validation identique dans les fonctions `createBudget` et `updateBudget`

### 4.3 Migration Dexie schéma v5 (packages/core/src/sync/dexie.ts)

**Avant** : Schéma versions 1-4, pas de colonne `userId`

**Après** :
- **Version 5** ajoute la colonne `userId TEXT NOT NULL DEFAULT 'primary'` à toutes les tables :
  - `transactions` table
  - `budgets` table
  - `savingGoals` table
  - `savingContributions` table
- Interfaces mises à jour : `LocalTransaction`, `LocalBudget`, `LocalSavingGoal`, `LocalSavingContribution` incluent maintenant `userId: string`
- Tous les nouveaux enregistrements reçoivent `userId = 'primary'` par défaut
- Migration additive - les données existantes conservent leur fonctionnement
- Fonctions `saveLocalBudget`, `getLocalBudgets` mis à jour pour inclure `userId` dans les requêtes

### 4.4 Chiffrement et Validation des Champs Sensibles

- `userId` ajouté aux `encryptedFields` pour transactions, budgets, et savingGoals
- Cela garantie que l'isolateur `userId` est également chiffré au repos dans IndexedDB
- Cohérence avec le service Dart `database_service.dart` qui utilise déjà `userId`

### 4.5 Export Total Verification

- Fonction `verifyExportTotals()` vérifie que les totaux exportés correspondent aux totaux réels
- Utilisée dans les pages d'export pour garantir l'intégrité des données

## 5. État des Migrations

| Version | Changement |
|---------|------------|
| v1 → v2 | Ajout champs de suivi (isDeleted, createdAt, etc.) |
| v2 → v3 | Ajout isArchived, isDeleted sur goals |
| v3 → v4 | Ajout userProfiles table, vaultMetadata |
| **v4 → v5** | **AJOUT: colonne `userId` sur transactions, budgets, goals** |

Aucune migration destructive n'a été effectuée. Le schéma Dexie a évolué naturellement via des versions successives permettant la montée en charge.

La fonction `migrateLocalDatabase()` existe pour migrer les données non chiffrées vers le coffre chiffré, mais n'a pas été automatiquement déclenchée dans cette session - l'utilisateur doit créer un coffre vault pendant l'onboarding.

## 6. Corrections

- Validation montant transaction : entière centimes uniquement avec gestion d'erreurs
- Validation montant budget : entière, non négatif, non zéro, mois requis pour mensuel
- Soft delete obligatoire pour transactions avec restauration
- Passage Montant flottant → entier dans imports avec validation
- Gestion erreurs ouverture vault sans passphrase
- Checksum intégrité sauvegardes ajouté
- Transactions persistées après import avec hashDedup
- Colonnes `userId` ajoutées au schéma Dexie v5
- Fonctions de sauvegarde Dexie complètes pour tous les types de données

## 7. Tests Exécutés et Résultats

Les tests existants dans `packages/core/src/` couvrent :
- `budget.test.ts` : validations budget, calculateRemaining
- `budget.step5.test.ts` : tests étape 5
- `step6.test.ts` : tests analytics step 6
- `onboarding.test.ts` : questionnaire → profil → persistance chiffrée
- `product/profile.test.ts` : création profile, recommandation
- `product/onboarding.test.ts` : onboarding complet
- `savings.step7.test.ts` : tests objectifs étape 7
- `import-engine/pipeline.test.ts` : pipeline d'import

**Résultat** : Tous les tests unitaires existants portent sur la logique métier sans environnement d'exécution (pas de Node.js/pnpm disponible dans cet environnement). Le code a été examiné statiquement et suit les patterns établis.

**Tests non exécutés** :
- Tests d'intégration complète (navigateur réel)
- Tests e2e bout en bout
- Tests de performance
- Tests de compatibilité navigateur
- Tests de chargement offline

## 8. Limites de Sécurité

- **Chiffrement navigateur** : Le chiffrement AES-GCM dans le navigateur n'est pas inviolable. Une clé accessible à l'application ne protège pas contre toutes les attaques, notamment lorsque l'appareil ou la session est compromis.
- **Stockage local** : Les données sont stockées en local dans IndexedDB. Si l'appareil est perdu ou le navigateur efface ses données locales, les données sont perdues sans sauvegarde externe.
- **Passphrase** : Le passphrase est saisi par l'utilisateur et stocké en mémoire seulement. S'il est perdu, toutes les données sont inaccessibles.
- **AES-GCM** : Offre confidentialité et intégrité, mais pas d'authentification de l'expéditeur. Les données altérées silencieusement ne sont pas détectées par le déchiffrement.
- **Isolation profils** : Le `userId` est respecté dans les requêtes Dexie, mais un seul profil local 'primary' est supporté. Sur appareils partagés, les données ne sont pas isolées entre utilisateurs différents sans mécanisme de connexion multi-compte.
- **Aucune connexion serveur** : Toutes les données restent sur l'appareil. Aucune donnée n'est envoyée à un serveur durant l'onboarding ou l'utilisation normale.

## 9. Problèmes Restants et Prochaines Étapes

- [ ] **Environnement d'exécution** : Node.js ≥20.9 et pnpm ≥8 requis pour exécuter tests, builds et audits
- [ ] **Icônes PWA manquantes** : Le manifest référence des icônes qui n'existent pas en `/public/icons/`
- [ ] **Tests en navigateur réel** : Validation offline mode, import/export cycle, backup cycle
- [ ] **Build de production** : `pnpm build` non exécuté
- [ ] **Validation offline** : Confirmer que PWA caching permet le dashboard/transaction viewing après première visite
- [ ] **Tests e2e** : Parcours complet onboarding → transactions → backup → restore

### Cartographie des URLs d'intégration

- Application : `/tenabudget` ou `/finance`
- Onboarding : `/onboarding`
- Dashboard : `/dashboard`

### Priorités avant production

1. Installer Node.js ≥20.9 et pnpm ≥8
2. Ajouter les icônes PWA dans `/public/icons/`
3. Exécuter `pnpm typecheck` et `pnpm lint`
4. Tester les cycles complets (import, backup/restore, offline)
5. Valider les calculs financiers avec des valeurs limites (0, négatif, très grand)
6. Vérifier l'isolation des données via `userId` dans les requêtes Dexie

---

*Rapport généré dans le cadre de la mission B — TENΛ Budget Application Web Locale*
*Phase 3 ajoutée : environnement non disponible, vérifications statiques réalisées*
*Phase 4 ajoutée : environnement réel bloqué, rapport honnête des limitations*
*Dernière mise à jour complète : corrections sécurité, migrations Dexie v5, validations renforcées, rapport Phase 3+4*
État final : code validé statiquement, environnement d'exécution requis introuvable
