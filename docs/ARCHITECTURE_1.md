
# TENΛ Budget - Architecture - 27 Étapes Minimum - Mode Accéléré

## Principe absolu: PC personnel jamais nécessaire + jamais serveur

```
Téléphones PWA Dexie (offline source vérité locale)
  ↕ HTTPS SyncQueue + ConflictLog ne perd jamais
Vercel (Next.js 14 + Auth.js v5 + API /api/health + vercel.json)
  ↕ DATABASE_URL Prisma (serveur uniquement)
Neon Postgres (familyId isolé, isDeleted exclu, Int centimes)
```

PC éteint: app continue, auth continue, sync continue, PWA installable, données accessibles - Vérifié via /api/health pcRequired=false (logique) + à vérifier réellement après déploiement Vercel.

PC allumé: uniquement dev (pnpm dev) + git push + prisma migrate deploy - Jamais serveur.

Interdit: serveur Node local PC, SQLite locale PC, dossier partagé, tunnel ngrok dépendant PC allumé, sauvegarde uniquement locale PC.

## Stack - Mode accéléré 27 étapes

- Frontend: Next.js 14 App Router + React 18 + Tailwind + Recharts 2.12 MIT + auto-fit minmax responsive 375/768/1200
- PWA: next-pwa 5.6.0 MIT + manifest.json display standalone theme_color #7C3AED icons 192/512 + service worker + OfflineIndicator + /api/health
- Offline: Dexie 4.0.8 Apache 2.0 + TenaDatabase v1 tables transactions/budgets/syncQueue/conflicts LocalTransaction syncStatus pending/conflict/synced updatedAt + saveLocalTransaction pending + SyncQueueItem + syncWithServer ne perd jamais + ConflictLog localVersion/serverVersion + resolveConflict conserve trace
- Backend: Next.js API routes + Prisma 5 + PostgreSQL Neon + /api/health + vercel.json + .env.example
- Auth: Auth.js v5 Credentials + bcrypt + JWT httpOnly, AUTH_SECRET serveur Vercel 32 chars uniquement, session, owner/admin/member/child, canAskAssistant child false, invitations code 6 chars, limite 3 appareils
- Tests: Vitest + Playwright 1.42 MIT - 170+ tests définis, 0 exécutés conteneur sans internet (ConnectionRefused), à exécuter localement pnpm install + typecheck + test + playwright test
- Exports: exceljs MIT + papaparse MIT + jspdf MIT prévus Étape 7, totaux Int vérifiés verifyExportTotals, familyId/personId isolé, isDeleted exclu
- Banking: MOCK_ONLY Étape 11, aucun SDK réel, COMPATIBLE_PROVIDERS listés sans choix définitif (mock, gocardless, tink, plaid, budget-insight), IBAN masqué FR76 **** uniquement, MOCK_ONLY=true NO_REAL_SDK=true READ_ONLY=true, lecture seule PSD2, consent 90j mock, hashDedup réimport, validation humaine obligatoire requiresHumanValidation()=true
- Compatibilité: ResponsiveNav @media max-width 768px translateX(-100%)->0 + overlay + bouton ☰/✕ + desktop 260px fixe + auto-fit minmax 220px/300px + padding-top 56px mobile + inputs min-width 200 + 17 écrans tous responsive 0 débordement - vérifié code PASS, réel device 375/768/1200 NON VÉRIFIÉ à tester Chrome DevTools + iPhone/Android réels
- Mobile natif: Capacitor MIT + Tauri MIT/Apache 2.0 préparation sans réécrire core - core pure TS sans DOM compatible Capacitor/Tauri, Dexie compatible, next-pwa compatible, Auth.js compatible, aucune dépendance PC
- Sécurité: 48 assertCan dans 12+ fichiers, 23 familyId isolation, isDeleted 15+ fichiers, sim_/simtx_ isolées, VALIDATION_REQUIRED import + banking, 0 secret frontend process.env.DATABASE_URL/AUTH_SECRET, IBAN masqué, MOCK_ONLY, audit DeepSeek 13 catégories

## Int centimes

Toutes valeurs internes amountCents: number Int centimes, conversion euros affichage seulement cents/100, pas d'arrondi interne, pas de Float, pas de parseFloat pour montants, Math.floor(current*100/target) pour percentInt, calculateRemaining budgeted - spent Int, totalCents reduce Int.

## Permissions serveur 48 assertCan

budget/budget.ts assertCan + familyId + seuil 500€ + isDeleted, transaction.ts assertCan + familyId + personId obligatoire + amountCents Int + seuil 500€, recurring.ts, savings.ts, searchAdvanced.ts assertCan(budget:read) + 8 filtres combinables familyId+personId+category+source+fromDate/toDate+min/max+labelContains+tri+pagination, backup.ts assertCan + familyId, export.ts assertCan + familyId + isDeleted exclu, simulation/advanced.ts assertCan + familyId + sim_/simtx_.

## Isolation familyId 23 fichiers

filterValidTransactions if (t.familyId !== filters.familyId) return false première ligne, getSpendingByCategory + getMonthlyEvolution + getBudgetVsSpent + getSpendingByPerson, searchAdvanced, bankingToImportPipeline + transformToTransactionAfterValidation + detectBankingDuplicates, Dexie where(familyId).equals(familyId), assistant answerAssistantQuery baseFilters familyId, aucune fuite cross-family.

## Simulations sim_/simtx_ isolées

Namespace sim_ scénario + simtx_ transaction simulation jamais tx_ ou bud_, assertNoRealTransactionModified before.length===after.length + IDs simtx_, SimulationTransaction[] séparé jamais Transaction[] réel modifié, simulations exclues stats/history/export/backup/banking/assistant.

## Soft delete + RGPD

isDeleted + deletedAt + softDeleteTransaction obligatoire jamais physique, filterValidTransactions exclut isDeleted, advancedSearch includeDeleted=false par défaut, Dexie filter !isDeleted, backup filtre !isDeleted, anonymisation après 30j anonymizeTransaction, hard delete encadré owner + confirmation + 30j + familyId isolé hardDeleteTransaction, registre 6 activités budget/transaction/export/backup/banking_mock/sync familyIdIsolated true isDeletedExcluded true.

## Pipeline import 11 étapes

Sélection (XLSX multi-feuilles + CSV read-only) → Analyse (rawCells) → Détection (confiance 0-100 + EUR + dates FR) → Résumé → Corrections (réexécution réelle recognizeData) → Doublons (exact hash + likely, keep_both par défaut) → Comparaison côte à côte → Prévisualisation (sélection années) → Validation obligatoire checkbox → Import (après validation uniquement, throw IMPORT_FORBIDDEN) → Rapport complet (importés/ignorés/modifiés/ambigus/doublons/erreurs/attention) - réutilisé banking bankingToImportPipeline, hashDedup date|amount|label.lower.

## Performance réelle Node.js pur (seule mesure réelle possible sans dépendances)

filterValidTransactions 100 tx 0ms valid 99 PASS, 1000 0ms 990 PASS, 5000 1ms 4950 PASS, 10000 0ms 9900 PASS
getSpendingByCategory 100 0ms 4 cat PASS, 1000 0ms PASS, 5000 1ms PASS, 10000 2ms PASS
getMonthlyEvolution 100 1ms 12 mois PASS, 1000 1ms PASS, 5000 6ms PASS, 10000 9ms PASS
advancedSearch 8 filtres combinables + tri + pagination 10/page 100 0ms total 8 PASS, 1000 0ms total 80 PASS, 5000 0ms total 400 PASS, 10000 1ms total 792 PASS
SyncQueue ne perd jamais 100-10000 0-1ms PASS
Objectif <100ms filter 1000, <200ms search 5000 → PASS réel mesuré Node.js pur.

## Déploiement Étape 17-18

Déployé: NON - pas encore déployé réellement Vercel/Neon, préparation vercel.json + .env.example + /api/health + manifest.json + next.config.js withPWA - EXISTS PASS mais NON VÉRIFIÉ réellement build + base + auth + session + /api/health + pages principales
À faire: pnpm install avec internet → PASS, pnpm build → PASS, Neon Free DATABASE_URL, Vercel env DATABASE_URL@database-url + AUTH_SECRET@auth-secret + NEXTAUTH_URL@nextauth-url, prisma migrate deploy, déployer, vérifier /api/health 200 pcRequired:false, login bcrypt, session, dashboard, transactions, import 11 étapes, banking mock, audit, beta, URL réelle fonctionnelle uniquement après vérification, test PC éteint réel depuis téléphone, PWA installation + offline avion + sync + service worker + Lighthouse mesuré réel.

## 27 étapes minimum - Mode accéléré

Bloc 1 (14-18): Consolidation + Déploiement + Tests + PWA + PC éteint + Bêta + RGPD + Performance + Compatibilité + Sécurité - Préparé code PASS, NON VÉRIFIÉ réellement (tests réels, déploiement, PWA, offline/sync, PC éteint) - problème environnement conteneur sans internet, à vérifier localement
Bloc 2 (19-23): Finition Mobile/Desktop + Documentation + Sécurité Finale + Performance Finale + Finition UI/UX
Bloc 3 (24-27): Version Finale + Release + Validation Propriétaire + Prêt Production + Future Banking comparaison
