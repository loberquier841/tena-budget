# Rapport — Tests & état du dépôt (Tena Budget)

**Date :** 2026-11-07  
**Branche :** `main` (synchronisée avec `origin/main` avant commit)  
**Commit de référence avant session :** `e12e8d2`

## 1. Résumé exécutif

| Périmètre | Commande | Résultat |
|---|---|---|
| Monorepo TS (Turbo) | `pnpm test` | **Échec** — 2 suites `@tena/core` en erreur ; `@tena/import-engine` OK ; `@tena/web` sans tests (`--passWithNoTests`) |
| Typecheck TS (Turbo) | `pnpm typecheck` | **Échec** — erreurs de syntaxe dans `packages/core/src/product/onboarding.test.ts` |
| Tests Flutter (`tena_app`) | `flutter test` | **Partiel** — **57 tests réussis**, **13 suites en échec au chargement** (erreurs de compilation) |

## 2. Monorepo TypeScript (`pnpm test`)

- **`@tena/import-engine`** : 1 fichier, **20 tests passés**.
- **`@tena/web`** : aucun fichier de test trouvé (sortie 0 avec `--passWithNoTests`).
- **`@tena/core`** : **156 tests passés** sur 13 fichiers ; **2 fichiers en échec** (0 test exécuté dans ces suites) :
  - `src/backup/backup.test.ts` — `ReferenceError: beforeAll is not defined` (import `beforeAll` manquant dans le fichier de test).
  - `src/product/onboarding.test.ts` — échec de transformation/esbuild : erreur de syntaxe (guillemets échappés `\"` dans le source, ex. `from \"vitest\"`).

## 3. Typecheck TypeScript (`pnpm typecheck`)

- Packages OK : `@tena/shared`, `@tena/db`, `@tena/import-engine`, `@tena/ui`, `@tena/banking`.
- **`@tena/core`** : échec (exit 2) dû aux erreurs de syntaxe dans `packages/core/src/product/onboarding.test.ts` (caractères invalides / chaînes non terminées liées aux échappements).
- `@tena/web` non atteint dans la chaîne en raison de l’échec `@tena/core` (dépendances/pipeline).

## 4. Tests Flutter (`tena_app`, `flutter test`)

- **57 tests passés** (ex. `crypto_service_test`, `analysis_services_test`, `preferences_services_test`, `widget_test`, etc. — voir log complet).
- **13 suites en échec au chargement** (compilation) ; les erreurs proviennent principalement de modifications en cours dans `lib/services/database_service.dart` (syntaxe/API incomplètes : signature `openDatabase`, références `db`/variables non définies, `static` mal placés, helpers CSV/transactions/types manquants ou incohérents) et de tests impactés (`csv_edge_cases_test.dart` et autres suites dépendantes : `chronological_order_test`, `data_isolation_test`, `database_migration_test`, `encryption_cycle_test`, `legacy_migration_integration_test`, `lot7_profile_scope_test`, services import/document/transaction rule, etc.). Détail : `/tmp/tena_flutter_test.log`.

## 5. État du dépôt (périmètre enregistré)

Ce commit enregistre l’ensemble des modifications de travail présentes (web, packages core/banking, app Flutter, tests, docs, scripts/outillage), en excluant les artefacts locaux de récupération (`.recovery_20261107/`, ignoré) et les fichiers sensibles/ignorés par `.gitignore` (aucun `.env` réel détecté hors `.env.example`).

## 6. Actions recommandées

1. Corriger `packages/core/src/product/onboarding.test.ts` (syntaxe/échappements) puis relancer `pnpm typecheck && pnpm test`.
2. Ajouter `import { beforeAll } from "vitest";` (si nécessaire) dans `packages/core/src/backup/backup.test.ts` et vérifier la suite.
3. Stabiliser `tena_app/lib/services/database_service.dart` (API `openDatabase`, structure de classe/méthodes, CSV/import/export, migrations/messages) pour restaurer la compilation des 13 suites Flutter.
4. Relancer `pnpm test`, `pnpm typecheck` et `flutter test` après correctifs.
