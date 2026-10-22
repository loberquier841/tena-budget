# PLAN_20_SESSIONS.md — 20 missions Cline pour TENΛ Budget

Chaque mission est attribuée à une seule session (agent Cline n°1 à 20). Aucun fichier n'est partagé entre deux sessions. Les tests listés sont ceux que chaque agent doit exécuter localement.

## Session 1 — Nettoyage des doublons et fichiers en conflit

**Objectif :** Identifier et résoudre les fichiers en double (`package_1.json`, `package_2.json`, `layout_1.tsx`, `layout_2.tsx`, `index_1.ts`) sans casser le build.

**Fichiers réservés :**
- `packages/core/package_1.json`
- `apps/web/package_1.json`, `apps/web/package_2.json`
- `apps/web/app/layout_1.tsx`, `apps/web/app/layout_2.tsx`
- `packages/core/src/budget/index_1.ts`

**Tests :** `pnpm --filter @tena/core typecheck`, `pnpm --filter @tena/web typecheck`

## Session 2 — Core : Permissions, sécurité et isolation famille

**Objectif :** Auditer et stabiliser le module permissions (assertCan, rôles, seuil 500€) et le module sécurité.

**Fichiers réservés :**
- `packages/core/src/permissions/permissions.ts`
- `packages/core/src/permissions/family.ts`
- `packages/core/src/security/` (tous les fichiers du répertoire)

**Tests :** `packages/core/src/permissions/family.test.ts` (vitest)

## Session 3 — Core : Budget, transactions, catégories, récurrents, épargne, simulation

**Objectif :** Consolidation du module budget (création, modification, catégories, règles récurrentes, objectifs d'épargne, simulations isolées).

**Fichiers réservés :**
- `packages/core/src/budget/budget.ts`
- `packages/core/src/budget/transaction.ts`
- `packages/core/src/budget/category.ts`
- `packages/core/src/budget/recurring.ts`
- `packages/core/src/budget/savings.ts`
- `packages/core/src/budget/simulation.ts`
- `packages/core/src/budget/personBudget.ts`
- `packages/core/src/budget/search.ts`

**Tests :** `packages/core/src/budget/budget.test.ts`, `packages/core/src/budget/step5.test.ts` (vitest)

## Session 4 — Core : Backup, localVault et sync Dexie

**Objectif :** Sauvegarde/chiffrement local, vault Dexie, synchronisation hors ligne, gestion des conflits.

**Fichiers réservés :**
- `packages/core/src/backup/backup.ts`
- `packages/core/src/backup/local.ts`
- `packages/core/src/localVault.ts`
- `packages/core/src/sync/` (tous les fichiers du répertoire)

**Tests :** `packages/core/src/localVault.test.ts` (vitest)

## Session 5 — Core : RGPD, anonymisation et registre d'activités

**Objectif :** Anonymisation après 30j, registre des 6 activités, soft delete, droit à l'oubli.

**Fichiers réservés :**
- `packages/core/src/rgpd/anonymization.ts`
- `packages/core/src/rgpd/registry.ts`

**Tests :** `packages/core/src/rgpd/step14.test.ts` (vitest)

## Session 6 — Core : Analytics, stats, history, searchAdvanced

**Objectif :** Graphiques, statistiques, historique, recherche avancée avec isolation familyId.

**Fichiers réservés :**
- `packages/core/src/analytics/charts.ts`
- `packages/core/src/analytics/history.ts`
- `packages/core/src/analytics/stats.ts`
- `packages/core/src/analytics/searchAdvanced.ts`
- `packages/core/src/analytics/index.ts`

**Tests :** `packages/core/src/analytics/step6.test.ts` (vitest)

## Session 7 — Core : Product profile, autopilot et assistant IA

**Objectif :** Profil utilisateur, questionnaire d'onboarding, recommandations, autopilot, assistant TENΛ AI.

**Fichiers réservés :**
- `packages/core/src/product/profile.ts`
- `packages/core/src/autopilot/autopilot.ts`
- `packages/core/src/assistant/tenaAssistant.ts`

**Tests :** `packages/core/src/product/profile.test.ts`, `packages/core/src/autopilot/autopilot.test.ts` (vitest)

## Session 8 — Core : Banking mock, connecteur et pipeline de réutilisation

**Objectif :** Connecteur bancaire MOCK uniquement, lecture seule, pipeline d'import bancaire, détection de doublons.

**Fichiers réservés :**
- `packages/core/src/banking/BankConnector.ts`
- `packages/core/src/banking/interface.ts`
- `packages/core/src/banking/mockProvider.ts`
- `packages/core/src/banking/pipelineReuse.ts`
- `packages/core/src/banking/reuse-proof.ts`
- `packages/core/src/banking/index.ts`
- `packages/banking/src/index.ts`
- `packages/banking/package.json`

**Tests :** `packages/core/src/banking/step11.test.ts`, `packages/core/src/banking/step11.test_1.ts` (vitest)

## Session 9 — Import engine

**Objectif :** Moteur d'import CSV/XLSX, détection de confiance, doublons, prévisualisation, validation obligatoire.

**Fichiers réservés :**
- `packages/import-engine/src/` (tous les fichiers)
- `packages/import-engine/package.json`
- `packages/import-engine/tsconfig.json`

**Tests :** `pnpm --filter @tena/import-engine test` (vitest)

## Session 10 — Packages partagés : shared, ui, db

**Objectif :** Schémas partagés (zod), composants UI, client Prisma DB.

**Fichiers réservés :**
- `packages/shared/src/index.ts`, `packages/shared/package.json`, `packages/shared/tsconfig.json`
- `packages/ui/src/index.ts`, `packages/ui/package.json`, `packages/ui/tsconfig.json`
- `packages/db/src/index.ts`, `packages/db/package.json`, `packages/db/tsconfig.json`


## Session 11 — Web Next.js : Pages principales (dashboard, transactions, budgets, recurrentes)

**Objectif :** Pages web principales du tableau de bord, transactions, budgets, règles récurrentes.

**Fichiers réservés :**
- `apps/web/app/dashboard/page.tsx`
- `apps/web/app/transactions/page.tsx`, `apps/web/app/transactions/page_1.tsx`, `apps/web/app/transactions/page_2.tsx`
- `apps/web/app/budgets/page.tsx`
- `apps/web/app/recurrentes/page.tsx`

**Tests :** vitest + Playwright (`e2e/dashboard.spec.ts`)

## Session 12 — Web Next.js : Pages métier (objectifs, famille, historique, simulations, assistant, beta)

**Objectif :** Pages objectifs, famille, historique, simulations, assistant, bêta familiale.

**Fichiers réservés :**
- `apps/web/app/objectifs/page.tsx`
- `apps/web/app/famille/page.tsx`
- `apps/web/app/historique/page.tsx`
- `apps/web/app/simulations/page.tsx`
- `apps/web/app/assistant/page.tsx`, `apps/web/app/assistant/page_1.tsx`
- `apps/web/app/beta/page.tsx`

**Tests :** vitest + Playwright

## Session 13 — Web Next.js : Auth, API et pages techniques (import, exports, sauvegardes, banking, audit)

**Objectif :** Authentification NextAuth, routes API, pages import/export/sauvegardes/banking/audit, middleware de protection.

**Fichiers réservés :**
- `apps/web/auth.ts`
- `apps/web/middleware.ts`
- `apps/web/app/(auth)/login/` (tous les fichiers)
- `apps/web/app/api/` (tous les fichiers)
- `apps/web/app/import/page.tsx`
- `apps/web/app/exports/page.tsx`
- `apps/web/app/sauvegardes/page.tsx`
- `apps/web/app/banking/page.tsx`
- `apps/web/app/audit/page.tsx`

**Tests :** vitest + Playwright (`e2e/import.spec.ts`, `e2e/rgpd.spec.ts`)

## Session 14 — Web Next.js : Layout, composants, page racine, public, config

**Objectif :** Mise en page responsive, composants partagés, page d'accueil, ressources statiques, configuration Next.js/PWA.

**Fichiers réservés :**
- `apps/web/app/layout.tsx`
- `apps/web/app/page.tsx`
- `apps/web/components/Charts.tsx`
- `apps/web/components/Navigation.tsx`
- `apps/web/components/ResponsiveNav.tsx`
- `apps/web/public/manifest.json`, `apps/web/public/sw.js`, `apps/web/public/workbox-*.js`
- `apps/web/next.config.js`
- `apps/web/tsconfig.json`
- `apps/web/next-env.d.ts`

**Tests :** `pnpm --filter @tena/web build`, `pnpm --filter @tena/web typecheck`

## Session 15 — Mobile Vite / Capacitor

**Objectif :** Application mobile React + Vite, point d'entrée, configuration Capacitor/Vite.

**Fichiers réservés :**
- `apps/mobile/src/App.tsx`
- `apps/mobile/src/main.tsx`
- `apps/mobile/vite.config.ts`
- `apps/mobile/index.html`
- `apps/mobile/package.json`

**Tests :** `pnpm --filter @tena/mobile build`, `pnpm --filter @tena/mobile typecheck` (si script existe)

## Session 16 — Desktop Electron

**Objectif :** Application desktop Electron (offline), fichier main, configuration de build.

**Fichiers réservés :**
- `apps/desktop/main.js`
- `apps/desktop/package.json`

**Tests :** `pnpm --filter @tena/desktop build` (si possible sans serveur payant)

## Session 17 — Android Capacitor

**Objectif :** Projet Android natif Capacitor (Gradle, build, signatures).

**Fichiers réservés :**
- `android/` (tous les fichiers du répertoire : build.gradle, settings.gradle, gradle.properties, gradlew, etc.)

**Tests :** Vérification de la cohérence des fichiers Gradle (pas de build Android sans environnement complet)

## Session 18 — Flutter : main.dart, state et theme

**Objectif :** Point d'entrée Flutter, état période, thème de l'application. Préserver tous les fichiers `.backup`.

**Fichiers réservés :**
- `tena_app/lib/main.dart` (ne pas toucher aux `.backup`)
- `tena_app/lib/state/period_state.dart`
- `tena_app/lib/theme/tena_app_theme.dart`
- `tena_app/lib/theme/tena_theme.dart`

**Tests :** `flutter analyze` sur les fichiers concernés, `flutter test tena_app/test/widget_test.dart` (si environnement Flutter disponible)

## Session 19 — Flutter : Pages et widgets

**Objectif :** Pages (budget, catégories, prévisions, objectifs, paywall, profil, transactions) et widgets (carte, graphique, sidebar, section future). Préserver les `.backup`.

**Fichiers réservés :**
- `tena_app/lib/pages/budget_page.dart`
- `tena_app/lib/pages/categories_page.dart`
- `tena_app/lib/pages/forecast_page.dart`
- `tena_app/lib/pages/goals_page.dart`
- `tena_app/lib/pages/paywall_page.dart`
- `tena_app/lib/pages/profile_page.dart`
- `tena_app/lib/pages/transactions_page.dart` (ne pas toucher à `.backup_v2`)
- `tena_app/lib/widgets/finance_chart.dart` (ne pas toucher aux `.backup`)
- `tena_app/lib/widgets/tena_card.dart`
- `tena_app/lib/widgets/tena_future_section.dart`
- `tena_app/lib/widgets/tena_sidebar.dart`

**Tests :** `flutter test` sur les tests de pages/widgets associés

## Session 20 — Flutter : Services, models, tests, e2e et consolidation docs

**Objectif :** Services Flutter (budget, catégorie, crypto, database, finance, forecast, goal, insight, notification, payment, report, secure_key_store, user_profile), modèles, tests Flutter, tests e2e Playwright, et revue des docs existantes.

**Fichiers réservés :**
- `tena_app/lib/services/` (tous les fichiers, sauf les `.backup` à préserver)
- `tena_app/lib/models/` (tous les fichiers)
- `tena_app/test/` (tous les fichiers de test, sauf `widget_test.dart.backup`)
- `e2e/` (tous les fichiers spec et config)
- `docs/` (revue en lecture seule des docs existantes, pas de modification des docs de référence)

**Tests :** `flutter test tena_app/test/`, `npx playwright test` (e2e)

## Règle transversale

Aucune session ne modifie un fichier réservé à une autre session. En cas de besoin avéré, le coordonnateur doit réattribuer le fichier avant toute modification.
**Tests :** `pnpm --filter @tena/shared typecheck`, `pnpm --filter @tena/ui typecheck`, `pnpm --filter @tena/db typecheck`