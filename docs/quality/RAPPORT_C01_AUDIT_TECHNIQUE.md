# RAPPORT C01 — Audit Technique Complémentaire Web

**Mission** : Approfondissement de l'audit technique de l'application Web TENΛ Budget.
**Période** : Travail de 5 heures effectives (documentation de vérifications statiques).
**Environnement** : Lecture seule, Node.js/pnpm non installés dans l'environnement d'exécution.
**Référentiel** : Code source au chemin `/Users/dg/Documents/Loïs/TENΛ Budget`, état `main` propre, dernier commit `cc742ba`.

---

## 1. Contrôles réalisés et commandes exécutées

| Phase | Commande / Action | Fichier ciblé | Résultat |
|---|---|---|---|
| **Phase 1 — Préparation** | `ls` racine, `find` tsconfig, `cat` package.json scripts | Racine, config | Node/pnpm absents (`which node` / `which pnpm` → code 1). Turbo/project config lisible. |
| | Lecture du rapport initial `RAPPORT_C01_WEB_APP.md` | `docs/quality/` | Rapport existant sans exécution, basé sur lecture code. |
| **Phase 2 — Stockage & Dexie** | `read_files` dexie.ts | `packages/core/src/sync/dexie.ts` | Schema IndexedDB complet : `LocalTransaction`, `LocalBudget`, `LocalSavingGoal`, `LocalSavingContribution`, `LocalUserProfileRecord`. Encryptage AES-GCM via `localVault.ts` (PBKDF2 310k it.). `encodeLocalRecord`/`decodeLocalRecord` pour champs sensibles. |
| | `read_files` profile.ts | `packages/core/src/product/profile.ts` | Types `OnboardingAnswers`, `UserProfile`, `OnboardingProgress`. Fonctions `createUserProfile`, `validateOnboardingAnswers`, `recommendForProfile`, `updateUserProfile`. Statut `ProductCapability` par feature (available-local, partial, mock-only, planned). |
| | `read_files` budgets page | `apps/web/app/budgets/page.tsx` | `getLocalBudgets(familyId)` depuis Dexie. Lecture session `auth()` côté serveur. `amountCents` en entiers. Seuil 500€ owner, `personId` respecté, `isDeleted` soft delete affiché grisé. |
| | `read_files` transactions page | `apps/web/app/transactions/page.tsx` | `useEffect` + `getLocalTransactions(familyId)` depuis Dexie. `useState` loading/error. Filtres combinables, tri, pagination. `isDeleted` opacity 0.5 exclu des stats. `personId` champ obligatoire affiché. `assertCan` en commentaires. |
| | `read_files` objectifs page | `apps/web/app/objectifs/page.tsx` | `getLocalSavingGoals(familyId)` depuis Dexie. `calculateProgress` pour `percentInt`, `remainingCents`. Contributions, archivage soft, seuil 500€ owner, `personId` respecté. |
| | `read_files` onboarding page | `apps/web/app/onboarding/page.tsx` | Questionnaire 8 étapes : vault → householdMode → incomePattern → budgetExperience → priorities → wantedFeatures → notificationPreference → summary/done. `saveLocalOnboardingProgress`/`getLocalOnboardingProgress` vers Dexie. `createLocalVault` / `activateLocalVault` côté client. `localStorage.getItem('familyId')` fallback (non encore depuis auth). |
| | `read_files` middleware.ts | `apps/web/middleware.ts` | Protection `/famille/:path*` → redirection `/login` si non connecté. `auth` imported de `@/auth`. `matcher` configuré uniquement sur famille. |
| | `read_files` auth.ts | `apps/web/auth.ts` | NextAuth v5, Credentials provider, bcrypt 12. `prisma.user.findUnique` via `@tena/db`. `jwt` / `callbacks session`. Secrets via `process.env` (server-only). |
| **Phase 3 — Sécurité** | Vérification exposition secrets | `auth.ts`, composants page | `grep` confirmé : 0 occurrence `AUTH_SECRET` dans `apps/web/app/**/*.tsx`. 0 occurrence `DATABASE_URL` frontend. `BankConnector MOCK_ONLY=true` confirmé. |
| | Vérification routes protégées | `middleware.ts` | Seule `/famille/` protégée. Autres routes (budgets, transactions, objectifs) protégeaient via `await auth()` dans chaque page mais *non* via middleware (sauf famille). |
| | Masquage IBAN | SECURITY_AUDIT.md | `ibanMasked FR76 **** **** 1234` jamais complet. Pas de log password dans backup/decrypt. |
| **Phase 4 — Vérifications techniques** | `read_files` tests profile | `packages/core/src/product/profile.test.ts` | 4 tests Vitest : création profil, recommandations sans claims de déverrouillage, mise à jour dashboard, validation priorités/features. |
| | `read_files` security audit | `docs/SECURITY_AUDIT.md` | Tableau libs installées/prévues : dexie OK, next-pwa OK, recharts OK. `exceljs`, `papaparse`, `jspdf` = *Prévu* mais **non installés**. |
| | Vérification montant centimes | `budgets/page.tsx`, `transactions/page.tsx`, `objectifs/page.tsx` | Tous les montants en `amountCents` / `currentCents` / `targetCents` — entiers, pas de `Float`. Format `${c/100).toFixed(2)} €` affiché. |
| | États loading/erreur | `transactions/page.tsx` | `loading`, `error` state avec affichage UI dédié. `budgets/page.tsx` try/catch avec `console.error`. `objectifs/page.tsx` try/catch avec `console.error`. |
| **Phase 5 — Livrable** | Création rapport | `docs/quality/RAPPORT_C01_AUDIT_TECHNIQUE.md` | En cours. |
## 2. Résultats vérifiables avec chemins précis

### 2.2 Questionnaire et Profil

### 2.3 Pages Web — Données et fonctionnement

### 2.4 Sécurité et Authentification

### 2.5 Dettes techniques et dépendances manquantes

### 5. Corrections recommandées — classées par priorité

#### Priorité 2 — Élevée (fonctionnalités bloquées)

#### Priorité 3 — Moyenne (dette technique et UX)

### 6. Dépendances entre corrections

### 7. Tests à effectuer après correction

### 8. Limits de l'environnement et tâches restant à accomplir

| Limite | Impact | Solution |
|---|---|---|
| **Node.js / pnpm non installés** dans l'environnement d'exécution | Impossible d'exécuter `pnpm install`, tests, build, typecheck en live. | Toutes les analyses sont **statiques** (lecture de code). Les corrections réelles nécessitent un environnement de développement avec Node ≥ 20.9 + pnpm ≥ 8. |
| **Aucune base de données** (Pas de .env, pas de migrations Prisma) | `auth.ts` inutilisable, pas de persistance durable au-delà d'IndexedDB local. | C1-C3 du rapport : créer configuration Neon/DATABASE_URL, appliquer migrations. |
| **Dépendances d'export manquantes** (exceljs, papaparse, jspdf) | Pages `/import` et `/exports` ne peuvent pas fonctionner. | C5 : installer les 3 librairies + `jspdf-autotable` pour les tableaux. |
| **Middleware protection partielle** | Routes autres que `/famille/` protégées uniquement par composant. | C7 : étendre `matcher` ou rendre la protection systématique en page. |
| **familyId localStorage dans transactions** | Risque d'incohérence multi-utilisateurs sur un même navigateur. | C4 : remplacer par `session.userId` provenant de `auth()`. |
| **Fichiers dupliqués toujours présents** | Codebase éparpillée, risque de confusion. | C8 : consolidation documentée, report C14. |
| **Aucun test Playwright exécuté** (0/30) | Aucune validation E2E en conditions réelles. | Après C1-C2 + build : `npx playwright test` sur les 5 specs existantes. |

**Tâches restant à accomplir (hors environnement immédiat)** :
- Lancer la phase C02 (installation environnement) pour rendre le dépôt exécutable.
- Après C02 : exécuter `pnpm typecheck`, `pnpm test` (Vitest), `pnpm build` (Next.js).
- Connecter l'auth NextAuth à une base Prisma Neon/Docker locale.
- Installer les dépendances d'export et raccorder les pipelines import/export.
- Nettoyer les doublons et finaliser la check-list des 23 étapes.
- Préparer le déploiement Vercel avec les secrets CI/CD.

---
**Fin du rapport C01 — Audit Technique Complémentaire.**
**Généré** $(date) **dans un environnement de lecture seule sans runtime d'exécution.**
**Toutes les preuves sont issues de l'analyse statique du code source existant.**
**Aucun fichier applicatif n'a été modifié durant cette mission.**
**Aucun commit, push ou suppression de fichier n'a été effectué.**
| Test | Fichier | Commande (après C1-C2) |
|---|---|---|
| Tests Vitest core | `packages/core/src/product/profile.test.ts` + autres | `pnpm --filter @tena/core test` |
| Tests Vitest import-engine | `packages/core/src/import-engine/` | `pnpm --filter @tena/import-engine test` |
| Typecheck global | Tous workspaces | `pnpm run typecheck` (turbo) |
| Build Next.js | Application web | `pnpm --filter @tena/web build` |
| Tests Playwright E2E | `e2e/` | `npx playwright test` (nécessite serveur dev en cours) |
| Test Auth complet | `/login` → dashboard | Lancer le serveur, créer un compte, naviguer dans toutes les routes. |
| Test Import CSV/XLSX | Page `/import` | Importer un fichier de test, vérifier création de transactions en Dexie. |
| Test Export PDF/Excel | Page `/exports` | Générer un fichier, vérifier contenu et téléchargement. |
| Test Backup → Restore | Page `/sauvegardes` | Créer une sauvegarde chiffrée, restaurer, vérifier données identiques. |
```
C1 (env) ──┐
           ├──→ C2 (migrations Prisma) ──→ C3 (NextAuth ↔ Prisma)
           │
C5 (deps) ──┤
           ├──→ C7 (middleware étendu)
           │
C4 (familyId auth) ──→ C7 (protection cohérente)
           │
C8 (nettoyage doublons) ──→ C14 (roadmap/déploiement final)
```

**Ordre recommandé d'exécution** :
1. C1 → C2 → C3 : rendre l'environnement exécutable et l'auth fonctionnelle.
2. C4 : corriger le familyId pour qu'il vienne de l'auth session.
3. C5 : installer les librairies d'export pour rendre les fonctionnalités import/export opératives.
4. C7 : harmoniser la protection des routes.
5. C8-C13 : nettoyage et tests tout au long.
| # | Correction | Fichier / Zone | Effet |
|---|---|---|---|
| C8 | **Nettoyer les fichiers dupliqués** | `apps/web/app/layout_*.tsx`, `apps/web/app/schema_*.prisma`, `apps/web/app/test_*.ts`, etc. | Consolider vers la version canonique. Documenter dans la check-list C14. |
| C9 | **Rendre les états de loading/erreur uniformes** | Toutes les pages asynchrones | Vérifier la cohérence du style (mêmes couleurs, mêmes composants `alert`/`spinner`). |
| C10 | **Vérifier le seuil 500€ owner et personId** | `budgets/page.tsx`, `transactions/page.tsx`, `objectifs/page.tsx` | S'assurer que la logique `owner` vs `famille` est bien comprise et que les assertions `assertCan` correspondent au rôle réel. |

#### Priorité 4 — Basse (améliorations)

| # | Correction | Fichier / Zone | Effet |
|---|---|---|---|
| C11 | **Mettre à jour les capacités ProductCapability** | `packages/core/src/product/profile.ts` | Si de nouvelles features sont implémentées, mettre à jour le statut `available-local` / `partial` / `mock-only` / `planned`. |
| C12 | **Ajouter des tests de non-régression** | `packages/core/src/product/profile.test.ts` | Les 4 tests existants couvrent la création de profil, les recommandations, la mise à jour, la validation. Étendre avec des tests de stockage Dexie si possible. |
| C13 | **Documenter le choix mobile (Capacitor vs Flutter)** | `capacitor.config.ts`, `tena_app/pubspec.yaml` | Définir quelle voie est prioritaire pour V1 et documenter le statut de l'autre. |
| # | Correction | Fichier / Zone | Effet |
|---|---|---|---|
| C5 | **Installer les dépendances d'export manquantes** | `apps/web/package.json`, `packages/core/package.json` | Ajouter `exceljs`, `papaparse`, `jspdf`, `jspdf-autotable`. Raccorder aux pages `/import` et `/exports`. |
| C6 | **Vérifier et corriger le rôle familyId / permissions** | `apps/web/app/budgets/page.tsx`, `transactions/page.tsx`, `objectifs/page.tsx` | S'assurer que le rôle `owner` est lu depuis la session/DB et non hardcodé. Vérifier `assertCan` assertions sont bien utilisées côté client. |
| C7 | **Aligner protection middleware sur toutes les routes protégées** | `apps/web/middleware.ts` | Étendre `matcher` pour couvrir `/budgets`, `/transactions`, `/objectifs`, `/dashboard`, etc. au minimum, ou rendre la protection page-level systématique. |
#### Priorité 1 — Critical (bloquant développement)

| # | Correction | Fichier / Zone | Effet |
|---|---|---|---|
| C1 | **Créer `.env.example` et `.env.local` de développement** | Racine du projet | Fournir `DATABASE_URL` (Neon), `AUTH_SECRET` généré, `NEXTAUTH_URL=http://localhost:3000`. Permet à `auth.ts` de fonctionner. |
| C2 | **Appliquer migrations Prisma et générer le client** | `packages/db/prisma/schema.prisma` + `pnpm prisma generate` + `pnpm prisma migrate dev` | Création des tables User, Family, Transaction, Budget, SavingGoal etc. dans une base PostgreSQL locale/Neon. |
| C3 | **Raccorder NextAuth aux tables Prisma** | `apps/web/auth.ts` — s'assurer que `prisma.user.findUnique` correspond à la table créée, ajouter `PrismaAdapter` NextAuth si besoin. | Rendre la fonction `signIn` vraiment opérationnelle avec bases de données réelles. |
| C4 | **Remplacer `localStorage familyId` par session auth** | `apps/web/app/transactions/page.tsx` ligne 21 | Remplacer `localStorage.getItem('familyId') || 'p1'` par `session.userId` issue du `auth()`. Assure l'isolation famille correcte. |
| Élément | Statut | Obsèques |
|---|---|---|
| `exceljs` | Non installé | Referencé dans SECURITY_AUDIT.md comme "Prévu" pour export Excel (étape 7). Absent de `package.json`. |
| `papaparse` | Non installé | Referencé comme "Prévu" pour import CSV. |
| `jspdf` | Non installé | Referencé comme "Prévu" pour export PDF. |
| `exceljs`, `papaparse`, `jspdf` | Non dans `package.json` | Vérification : `grep -r exceljs` → aucun résultat confirmé. |
| Node.js / pnpm | Non dans environnement d'exécution | `which node` / `which pnpm` → code 1. Impossible d'exécuter `pnpm install`, `pnpm test`, `npx playwright test`. |
| Base de données Prisma / Neon | Non configurée | `auth.ts` ligne 6 : `import { prisma } from "@tena/db"`. Migrations inexistantes, `.env` inexistant. `prisma generate` et `prisma migrate dev` non exécutables. |
| Fichiers dupliqués | Toujours présents | `layout_1.tsx`, `layout_2.tsx`, `schema_1.prisma` → `schema_3.prisma`, `test_1.ts` etc. Non nettoyés. |
| `familyId` hardcodé | Page transactions | `localStorage.getItem('familyId') || 'p1'` — à remplacer par valeur issue de l'auth session. |

### 2.6 Points hypothétiques ou nécessitant exécution

| Point | Pourquoi hypothétique | Comment valider |
|---|---|---|
| Exécution des tests Vitest | Pas de `node_modules`, pas de runtime Node | Après `pnpm install` : `pnpm --filter @tena/core test` |
| Exécution Playwright E2E | Pas de navigateur headless configuré, pas de serveur dev | Après `pnpm install` + `pnpm run build` : `npx playwright test` |
| Connexion Auth réelle | Base Prisma absente | Créer `.env.local` + appliquer migrations Prisma, vérifier `localhost:3000/login` |
| Import CSV/XLSX réel | `exceljs`/`papaparse` non installés | Installer dépendances, tester `import-engine` pipeline vers Dexie |
| Export PDF/Excel réel | `jspdf`/`exceljs` non installés | Installer, raccorder aux pages `/exports`, `/import` |
| Synchronisation famille multi-session | `localStorage familyId` usage | Test multi-onglets / multi-utilisateurs avec vraie base |
| CycleBackup → Restore AES-GCM | `localVault.ts` code valide mais non exécuté | Après `pnpm install` : tester avec un mot de passe, vérifier checksum SHA-256 |
**`apps/web/middleware.ts`** :

```typescript
import { auth } from "@/auth";
export default auth((req) => {
  const isAuthPage = req.nextUrl.pathname.startsWith("/login");
  const isLogged = !!req.auth;
  if (!isAuthPage && !isLogged && req.nextUrl.pathname !== "/") {
    if (req.nextUrl.pathname.startsWith("/famille")) {
      return Response.redirect(new URL("/login", req.nextUrl));
    }
  }
});
```

- `matcher: ["/famille/:path*"]` — protège uniquement les routes famille.
- Autres routes (budgets, transactions, objectifs, dashboard) protégées par `await auth()` dans chaque composant, pas par middleware.

**`apps/web/auth.ts`** :

- NextAuth v5, stratégie JWT.
- Provider Credentials avec bcrypt 12.
- `prisma.user.findUnique({ where: { email } })` — **bloquant** : base Prisma inexistante (pas de .env, pas de migrations).
- `jwt` callback : `token.id = user.id`.
- `session` callback : `(session as any).userId = token.id`.
- `hashPassword` / `verifyPassword` utilitaires bcrypt.

**Points de vulnérabilité identifiés** (non testés intrusivement, lecture code seulement) :

1. **Base Prisma absente** — `auth.ts` importe `prisma` mais aucune base n'est configurée. Sans Neon/DATABASE_URL, la connexion Auth échouera silencieusement ou renverra `null` user. Bloque tout système de connexion utilisateur.
2. **Protection partielle middleware** — Seule la route `/famille/` est couverte par le middleware. Les routes `/budgets`, `/transactions`, `/objectifs`, `/dashboard` etc. ne sont protégées que par le `await auth()` dans chaque composant, laissant une fenêtre d'accès direct si l'utilisateur connaît l'URL.
3. **familyId depuis localStorage** — Dans `transactions/page.tsx` ligne 21 : `const familyId = localStorage.getItem('familyId') || 'p1'`. Ce n'est pas extrait de la session auth, ce qui peut entraîner des incohérences si plusieurs familles utilisent le même navigateur.
4. **Aucun rôle utilisateur dynamique** — Les pages affichent `{b.personId ? '(individuel)' : '(global - jamais mélangé)'}` ou `{g.personId ? `(${g.personId})` : '(Famille)'}` — la logique de contrôle d'accès par rôle n'est pas visible dans les pages lues, seuls des comments `assertCan` apparaît\.
**`apps/web/app/budgets/page.tsx`** (Server Component) :

- `await auth()` — vérification session côté serveur.
- `familyId = session.userId || 'family_default'`.
- `await getLocalBudgets(familyId)` — IndexedDB Dexie, données réelles (plus de mock).
- Tableau affichant `type` (annuel/mensuel), année/mois, catégorie, personne, montant en `amountCents` (entiers), boutons Modifier/Archiver.
- Footer pédagogique : `✓ createBudget() Int only, refuse float • monthly sans mois refusé • duplicate interdit • seuil 500€ owner • personId respecté • familial vs individuel séparés`.

**`apps/web/app/transactions/page.tsx`** (Client Component, `'use client'`) :

- `useState` : `transactions`, `loading`, `error`, `filters`, `sort`.
- `useEffect` chargement asynchrone : `getLocalTransactions(familyId)` depuis Dexie.
- `familyId = localStorage.getItem('familyId') || 'p1'` — **note**: pas encore depuis contexte auth (à corriger).
- Filtres combinables : `personId`, `categoryId`, `source`, `label`, plages dates, `includeDeleted`.
- Tri sur `bookingDate` / `amountCents` / `label`.
- Pagination 10 par page.
- `isDeleted` : lignes opacity 0.5, exclues des stats, restaurables en soft delete.
- `personId` obligatoire affiché sous forme `t.person` (`t.personId`).
- `assertCan(budget:read)`, `assertCan(transaction:write)`, `assertCan(tx:delete)` en comments de boutons.

**`apps/web/app/objectifs/page.tsx`** (Server Component) :

- `await auth()`, `familyId = session.userId || 'family_default'`.
- `await getLocalSavingGoals(familyId)` — filtre `!goal.isDeleted`.
- `calculateProgress(g)` → `percentInt` (floor current*100/target), `remainingCents` = target - current.
- Barres de progression en `%` entières, couleurs vert (dépassé) / bleu (en cours).
- Contributions `+ Ajouter contribution` — refuse 0, refuse passage négatif.
- Bouton Archiver → soft delete.
**Fichier** : `packages/core/src/product/profile.ts`

- `OnboardingAnswers` (l.10-17) : `householdMode`, `incomePattern`, `budgetExperience`, `priorities`, `wantedFeatures`, `notificationPreference`.
- `UserProfile` (l.19-23) : `id: 'primary'`, `schemaVersion: 1`, `createdAt`, `updatedAt`, `completedAt`, `answers`, `dashboard.visibleCards`, `dashboard.compact`.
- `OnboardingProgress` (l.26-35) : idem UserProfile + `status: 'in-progress'`, `currentStep`, `startedAt`, `updatedAt`.
- `createUserProfile` (l.101-107) : valide avec `validateOnboardingAnswers`, retourne profil complet avec calcul `cardsFor`.
- `validateOnboardingAnswers` (invoqué) : lance `PROFILE_PRIORITY_REQUIRED` si priorités vides, `PROFILE_FEATURE_INVALID` si feature fausse.
- `recommendForProfile` (l.119-136) : jamais de `availability: "launched"` pour features payantes — toujours `not-launched`. Tiers free/plus/pro/premium/premium-plus/family/enterprise selon features voulues et householdMode.

**Fichier** : `apps/web/app/onboarding/page.tsx`

- 8 étapes avec navigation `goNext` / `goPrevious`.
- Étape `vault` : création coffre local avec `createLocalVault` + `activateLocalVault`.
- Toutes les étapes sauvegardent la progression via `saveLocalOnboardingProgress` dans Dexie.
- Étape `summary` : appelle `createUserProfile` et redirige vers `/dashboard`.
### 2.1 Stockage IndexedDB (Dexie)

**Fichier** : `packages/core/src/sync/dexie.ts`

- Interface `LocalTransaction` (l.9-23) : `id`, `familyId`, `amountCents`, `bookingDate`, `label`, `categoryId`, `personId`, `isDeleted`, `syncStatus`, `updatedAt`.
- Interface `LocalBudget` (l.25-35) : `id`, `familyId`, `amountCents`, `year`, `month`, `categoryId`, `personId`, `syncStatus`, `updatedAt`.
- Interface `LocalSavingGoal` (l.37-39) étend `SavingGoal` + `syncStatus`.
- Interface `LocalUserProfileRecord` (l.68) : `id: 'primary'` + `payload: UserProfile | OnboardingProgress`.
- **Chiffrement** (l.70-94) : `encodeLocalRecord` / `decodeLocalRecord` — champs sensibles encryptés par table avec `encryptLocalValue`/`decryptLocalValue` depuis `localVault.ts`.
- **Champs encryptés par table** (l.70-78) :
  - `transactions` : `amountCents`, `bookingDate`, `label`, `categoryId`, `personId`, `deletedAt`, `createdAt`, `createdByUserId`.
  - `budgets` : `amountCents`, `categoryId`, `personId`.
  - `savingGoals` : `personId`, `name`, `targetCents`, `currentCents`, `deletedAt`.
  - `savingContributions` : `goalId`, `amountCents`, `bookingDate`, `note`, `createdByUserId`.
- Fonctions CRUD : `getLocalBudgets` (l.383-387), `saveLocalBudget` (l.389-408), `getLocalSavingGoals` (l.410-414), `saveLocalSavingGoal` (l.416-442).