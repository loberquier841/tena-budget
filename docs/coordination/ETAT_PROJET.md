# ETAT_PROJET.md — TENΛ Budget

État réel du dépôt après inspection du code. Aucun élément n'est inventé ; tout est issu de la lecture du dépôt `/Users/dg/Documents/Loïs/TENΛ Budget`.

## 1. Dépôt et environnement

- Chemin absolu : `/Users/dg/Documents/Loïs/TENΛ Budget`
- Remote Git : `https://github.com/loberquier841/tena-budget.git`
- Branche courante : `main` (propre, à jour avec `origin/main`)
- Dernier commit : `cc742ba` — "Build local-first profile onboarding and encrypted vault"
- `git status` : `nothing to commit, working tree clean`
- Aucun fichier `.env` présent (seul `.env.example` est versionné)
- Propriétaire du dossier : `dg` (lecture et écriture autorisées)
- Node.js requis : `>=20.9.0` ; pnpm requis : `>=8.0.0`
- Internet requis pour `pnpm install`

## 2. Architecture (monorepo pnpm + turbo)

Workspaces : `apps/*`, `packages/*`

### Packages TypeScript (6)

| Package | Rôle | Fichiers clés |
|---------|------|---------------|
| `@tena/core` | Logique métier (budget, transactions, catégories, objectifs, prévisions, backup, sécurité, permissions, RGPD, banking mock, analytics, autopilot, assistant, profil, localVault, sync/dexie) | `packages/core/src/` |
| `@tena/shared` | Schémas partagés (zod) | `packages/shared/src/index.ts` |
| `@tena/db` | Prisma client (PostgreSQL/Neon) | `packages/db/src/index.ts` |
| `@tena/banking` | Re-export de `@tena/core` (banking) | `packages/banking/src/index.ts` |
| `@tena/import-engine` | Moteur d'import (CSV/XLSX) | `packages/import-engine/src/` |
| `@tena/ui` | Composants UI partagés | `packages/ui/src/index.ts` |

### Applications (3)

| App | Technologie | Rôle |
|-----|-------------|------|
| `apps/web` | Next.js 14 App Router + React 18 + next-auth + next-pwa + Dexie | Web PWA principale |
| `apps/mobile` | Vite + React + Capacitor | Mobile (webview Capacitor) |
| `apps/desktop` | Electron 44.5.1 + electron-builder | Desktop offline |

### Mobile natif / Flutter

- `tena_app/` : application Flutter (Dart SDK ^3.13.4), stockage SQLite séparé (`sqflite`), tests Flutter présents.
- `android/` : projet Capacitor Android (Gradle).

### Tests

- Vitest : tests unitaires dans `packages/core/src/` (budget, step5, step6, step11, step13, step14, profile, autopilot, localVault, family, etc.)
- Playwright : 4 specs e2e dans `e2e/` (consolidation, dashboard, full-parcours, import, rgpd)
- Flutter : `tena_app/test/` (widget_test, analysis_services, crypto_service, finance_service, forecast_service, preferences_services)

## 3. Fichiers de configuration à la racine

`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `turbo.json`, `tsconfig.base.json`, `capacitor.config.ts`, `vercel.json`, `.env.example`, `.gitignore`, `README.md`.

## 4. Fichiers `.backup` à préserver (non modifiables)

Plusieurs fichiers de sauvegarde existent dans `tena_app/lib/` :

- `tena_app/lib/main.dart.backup` + variantes `_dashboard`, `_dashboard_v2..v4`, `_mois`, `.before_dashboard`, `.before_gold`
- `tena_app/lib/services/database_service.dart.backup`, `database_service.dart.backup_transactions_v2`
- `tena_app/lib/pages/transactions_page.dart.backup_v2`
- `tena_app/lib/widgets/finance_chart.backup.dart`, `finance_chart.backup_v2.dart`, `finance_chart.backup_v3.dart`, `finance_chart.dart.before_gold`
- `tena_app/test/widget_test.dart.backup`

Ces fichiers ne doivent pas être modifiés ni supprimés.

## 5. Fichiers en doublon / en conflit (à inventorier)

- `packages/core/package.json` vs `packages/core/package_1.json`
- `apps/web/package.json` vs `apps/web/package_1.json` vs `apps/web/package_2.json`
- `apps/web/app/layout.tsx` vs `layout_1.tsx` vs `layout_2.tsx`
- `packages/core/src/budget/index.ts` vs `index_1.ts`

## 6. État d'avancement réel (selon docs existantes)

- Étapes 1-13 : validées propriétaire (selon roadmap)
- Étapes 14-18 : code "préparé PASS", mais **NON VÉRIFIÉES réellement** (tests réels, déploiement, PWA, offline/sync, PC éteint) — environnement sans internet, Node 16.20.2 dans le conteneur de doc
- Étapes 19-27 : à développer (finition mobile/desktop, docs, sécurité finale, performance, UI/UX, release, production)
- Aucun test n'a été réellement exécuté sur ce poste (pas de `node_modules`, pas d'internet selon la documentation)
- Déploiement : NON déployé (Vercel/Neon préparés, non vérifiés)

## 7. Technologies et dépendances notables

- Next.js 14.2, NextAuth v5 beta, bcryptjs, Dexie 4.0.8, Recharts 2.12, Zod, Prisma 5, next-pwa 5.6.0
- Flutter SDK ^3.13.4, sqflite, flutter_secure_storage, cryptography, fl_chart
- Electron 44.5.1, electron-builder 26.15.3
- Playwright 1.42, Vitest 1.4, TypeScript 5.4, Turbo 1.13, pnpm 8.15

## 8. Contraintes du brief produit (à respecter)

- Local-first prioritaire ; version famille puis entreprise après une version personnelle solide
- Aucune vraie connexion bancaire (MOCK uniquement) sans validation propriétaire
- Aucun paiement automatique
- Aucun secret côté frontend (AUTH_SECRET, DATABASE_URL)
- Pas de serveur PC local ; pas de tunnel ngrok
- Simulations isolées (`sim_`/`simtx_`), jamais de modification de vraies transactions
- Soft delete (`isDeleted`), jamais de suppression physique
- 0 secret frontend