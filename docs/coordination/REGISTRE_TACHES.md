# REGISTRE_TACHES.md — Suivi des 20 missions et fichiers réservés

Dépôt : `/Users/dg/Documents/Loïs/TENΛ Budget`
Coordonnateur : en attente de validation avant intégration globale

## Statut des sessions

| Session | Mission | Fichiers réservés | Tests | Statut | Fichiers modifiés | Résultat tests |
|---------|---------|-------------------|-------|--------|-------------------|----------------|
| 1 | Nettoyage doublons | `packages/core/package_1.json`, `apps/web/package_1.json`, `apps/web/package_2.json`, `apps/web/app/layout_1.tsx`, `apps/web/app/layout_2.tsx`, `packages/core/src/budget/index_1.ts` | `@tena/core typecheck`, `@tena/web typecheck` | En attente | — | — |
| 2 | Core : Permissions & sécurité | `packages/core/src/permissions/`, `packages/core/src/security/` | `family.test.ts` | En attente | — | — |
| 3 | Core : Budget & transactions | `packages/core/src/budget/` | `budget.test.ts`, `step5.test.ts` | En attente | — | — |
| 4 | Core : Backup & localVault | `packages/core/src/backup/`, `packages/core/src/localVault.ts`, `packages/core/src/sync/` | `localVault.test.ts` | En attente | — | — |
| 5 | Core : RGPD | `packages/core/src/rgpd/` | `step14.test.ts` | En attente | — | — |
| 6 | Core : Analytics | `packages/core/src/analytics/` | `step6.test.ts` | En attente | — | — |
| 7 | Core : Product & autopilot | `packages/core/src/product/`, `packages/core/src/autopilot/`, `packages/core/src/assistant/` | `profile.test.ts`, `autopilot.test.ts` | En attente | — | — |
| 8 | Core : Banking mock | `packages/core/src/banking/`, `packages/banking/` | `step11.test.ts`, `step11.test_1.ts` | En attente | — | — |
| 9 | Import engine | `packages/import-engine/` | `@tena/import-engine test` | En attente | — | — |
| 10 | Shared, UI, DB | `packages/shared/`, `packages/ui/`, `packages/db/` | `typecheck` sur 3 packages | En attente | — | — |
| 11 | Web : Pages principales | `apps/web/app/dashboard/`, `apps/web/app/transactions/`, `apps/web/app/budgets/`, `apps/web/app/recurrentes/` | vitest + `e2e/dashboard.spec.ts` | En attente | — | — |
| 12 | Web : Pages métier | `apps/web/app/objectifs/`, `apps/web/app/famille/`, `apps/web/app/historique/`, `apps/web/app/simulations/`, `apps/web/app/assistant/`, `apps/web/app/beta/` | vitest + Playwright | En attente | — | — |
| 13 | Web : Auth, API, pages techniques | `apps/web/auth.ts`, `apps/web/middleware.ts`, `apps/web/app/(auth)/`, `apps/web/app/api/`, `apps/web/app/import/`, `apps/web/app/exports/`, `apps/web/app/sauvegardes/`, `apps/web/app/banking/`, `apps/web/app/audit/` | vitest + `e2e/import.spec.ts`, `e2e/rgpd.spec.ts` | En attente | — | — |
| 14 | Web : Layout & composants | `apps/web/app/layout.tsx`, `apps/web/app/page.tsx`, `apps/web/components/`, `apps/web/public/`, `apps/web/next.config.js`, `apps/web/tsconfig.json` | `@tena/web build`, `@tena/web typecheck` | En attente | — | — |
| 15 | Mobile Vite/Capacitor | `apps/mobile/src/`, `apps/mobile/vite.config.ts`, `apps/mobile/index.html`, `apps/mobile/package.json` | `@tena/mobile build` | En attente | — | — |
| 16 | Desktop Electron | `apps/desktop/main.js`, `apps/desktop/package.json` | `@tena/desktop build` (si possible) | En attente | — | — |
| 17 | Android Capacitor | `android/` | Vérification Gradle | En attente | — | — |
| 18 | Flutter : main, state, theme | `tena_app/lib/main.dart`, `tena_app/lib/state/`, `tena_app/lib/theme/` | `flutter analyze`, `flutter test` | En attente | — | — |
| 19 | Flutter : pages & widgets | `tena_app/lib/pages/`, `tena_app/lib/widgets/` | `flutter test` | En attente | — | — |
| 20 | Flutter : services, models, tests, e2e, docs | `tena_app/lib/services/`, `tena_app/lib/models/`, `tena_app/test/`, `e2e/`, `docs/` (lecture seule) | `flutter test`, `npx playwright test` | En attente | — | — |

## Fichiers `.backup` à préserver (intouchables)

- `tena_app/lib/main.dart.backup` + variantes
- `tena_app/lib/services/database_service.dart.backup` + `backup_transactions_v2`
- `tena_app/lib/pages/transactions_page.dart.backup_v2`
- `tena_app/lib/widgets/finance_chart.backup.dart` + `backup_v2` + `backup_v3` + `.before_gold`
- `tena_app/test/widget_test.dart.backup`

## Règle de modification

Une session = une branche `feature/sline-XX-<mission>`. Aucun commit, push ou merge sans autorisation du coordonnateur. Aucun fichier n'est modifié par deux sessions simultanément.

## Validation globale

L'intégration globale n'a lieu qu'après validation du coordonnateur, une fois les 20 sessions terminées et leurs tests passés.