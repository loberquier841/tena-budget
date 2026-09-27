
# TENΛ Budget - Audit Sécurité Étape 12 - Consolidation

## 20 étapes minimum - PC personnel jamais nécessaire

### Architecture déploiement
- **Prévu**: Vercel + Neon Postgres + PWA Dexie
- **Installé**: next-pwa@5.6.0 MIT, dexie@4.0.8 Apache 2.0, recharts@2.12.0 MIT, @playwright/test@1.42.0 MIT
- **Configuré**: next.config.js withPWA, public/manifest.json, TenaDatabase Dexie v1
- **Déployé**: À déployer sur Vercel (DATABASE_URL + AUTH_SECRET côté serveur Vercel uniquement)

### Audit permissions côté serveur
- budget/budget.ts: assertCan=True familyId=True
- budget/transaction.ts: assertCan=True familyId=True
- budget/recurring.ts: assertCan=True familyId=True
- budget/savings.ts: assertCan=True familyId=True
- analytics/searchAdvanced.ts: assertCan=True familyId=True
- backup/backup.ts: assertCan=True familyId=True
- export/export.ts: assertCan=True familyId=True
- simulation/advanced.ts: assertCan=True familyId=True
- analytics/stats.ts: lecture seule, filterValidTransactions familyId + isDeleted + personId
- sync/sync.ts: familyId filtré, pas de write sans validation
- banking/mockProvider.ts: familyId isolé, lecture seule

Seuil 500€ owner: amountCents > 50000 nécessite owner dans budget, transaction, recurring, savings

### Isolation familyId
- filterValidTransactions + getSpendingByCategory + getMonthlyEvolution + getBudgetVsSpent + getSpendingByPerson: familyId filtré première ligne
- bankingToImportPipeline + transformToTransactionAfterValidation + detectBankingDuplicates: familyId isolé
- Dexie: transactions.where(familyId).equals(familyId) + budgets.where(familyId) + syncQueue.where(familyId)
- Assistant: answerAssistantQuery baseFilters familyId + canAskAssistant child refusé
- Aucune requête cross-family

### Simulations isolation
- Namespace sim_ / simtx_ distinct: createWhatIfScenario id sim_ + addWhatIfTransaction id simtx_ + jamais tx_ ou bud_
- Aucune Transaction réelle créée: calculateImpact SimulationTransaction[] séparé, jamais Transaction[] réel modifié
- assertNoRealTransactionModified: beforeIds === afterIds + simTransactions id startswith simtx_
- Simulations exclues stats: filterValidTransactions ne prend que Transaction[] réel
- Simulations exclues banking: generateBankingReport simulationsExcluded:true
- Simulations exclues assistant: answerAssistantQuery sans simulations

### Soft delete
- isDeleted exclu stats: filterValidTransactions + getSpendingByCategory + getMonthlyEvolution + getAnnualEvolution + getBudgetVsSpent
- isDeleted exclu searchAdvanced: !includeDeleted && t.isDeleted → false
- isDeleted exclu Dexie: getLocalTransactions filter !isDeleted
- Soft delete obligatoire: softDeleteTransaction + softDeleteBudget + softDeleteRecurringRule + softDeleteGoal → isDeleted=true + deletedAt, jamais physique
- isDeleted exclu banking duplicates: existing.filter(!isDeleted)

### Validations obligatoires
- Import: step9 VALIDATION_REQUIRED + step10Import throw IMPORT_FORBIDDEN si !validated + UI checkbox
- Banking: requiresHumanValidation() true + validateBankingImport !validated → VALIDATION_REQUIRED + transformToTransactionAfterValidation uniquement après validation
- Export: verifyExportTotals realTotal === exportData.totalCents
- Backup: generateChecksum SHA-256 + encryptBackup AES-GCM + decryptBackup vérifie checksum mismatch → BACKUP_INTEGRITY_FAILED
- Restauration: restoreBackup overwrite=false → conflicts[] si ID existe

### Secrets
- Aucun AUTH_SECRET frontend: grep apps/web/app/**/*.tsx → 0 occurrence
- Aucun DATABASE_URL frontend: grep → 0
- Aucun client_secret frontend: grep → 0
- IBAN masqué uniquement: BankAccount ibanMasked FR76 **** **** 1234 jamais complet
- Password jamais loggué: encryptBackup + decryptBackup ne console.log pas password
- Banking MOCK_ONLY: BankConnector MOCK_ONLY=true NO_REAL_SDK=true READ_ONLY=true aucun SDK réel

### PWA/offline/sync
- Manifest installable: public/manifest.json name TENΛ Budget short_name TENΛ display standalone theme_color #7C3AED icons 192/512
- next-pwa configuré: next.config.js withPWA dest public register true skipWaiting true runtimeCaching fonts/images
- Dexie offline-first: TenaDatabase transactions/budgets/syncQueue/conflicts LocalTransaction syncStatus pending/conflict/synced
- SyncQueue + ConflictLog ne perd jamais donnée: syncWithServer queue → success delete queue synced, conflict → ConflictLog localVersion/serverVersion resolution pending, failed → attempts+1
- PC personnel jamais nécessaire: Architecture Vercel + Neon + PWA Dexie, pas de serveur local PC, pas SQLite locale, pas tunnel ngrok

### Responsive
- Menu latéral desktop 260px fixe: ResponsiveNav sidebar width 260 position fixed
- Menu mobile coulissant: mobileOpen state ☰/✕, overlay rgba(0,0,0,0.5), transform translateX(-100%)→0 transition 0.3s, @media max-width 768px
- Tableaux responsive: auto-fit minmax 220px/300px, overflowX auto, min-width 160/200
- 15 écrans cohérents: / + /login + /dashboard + /budgets + /transactions + /recurrentes + /objectifs + /famille + /historique + /simulations + /assistant + /import + /exports + /sauvegardes + /banking

### Bibliothèques et services externes
| Lib | Prévu | Installé | Configuré | Déployé | Licence | Rôle |
|-----|-------|----------|-----------|---------|---------|------|
| next-pwa | Oui | Oui 5.6.0 | Oui next.config.js | Manifest + SW | MIT | PWA installable |
| dexie | Oui | Oui 4.0.8 | Oui TenaDatabase v1 | IndexedDB | Apache 2.0 | Offline-first |
| recharts | Oui | Oui 2.12.0 | Oui Charts.tsx | Graphiques | MIT | Graphiques dashboard |
| @playwright/test | Oui | Oui 1.42.0 | Oui playwright.config.ts | Tests E2E | MIT | Tests parcours complet |
| exceljs | Oui | Prévu | Non | Non | MIT | Export Excel (Étape 7) |
| papaparse | Oui | Prévu | Non | Non | MIT | Export CSV |
| jspdf | Oui | Prévu | Non | Non | MIT | Export PDF |
| GoCardless | Prévu | Non | Non | Non | API | Banking (à comparer) |
| Tink | Prévu | Non | Non | Non | API | Banking (à comparer) |
| Plaid | Prévu | Non | Non | Non | API | Banking (à comparer) |
| Budget Insight | Prévu | Non | Non | Non | API | Banking (à comparer) |

Aucun fournisseur bancaire définitif choisi - à comparer après Étape 11
Aucune vraie connexion bancaire - mocks uniquement Étape 11

### Problèmes trouvés et corrigés
- BankConnector.ts contenait référence gocardless → corrigé MOCK_ONLY
- Stats.ts assertCan=False mais lecture seule → OK, filterValidTransactions familyId + isDeleted
- Tests Python miroirs → clairement distingués des vrais tests Vitest/Playwright (ne remplacent pas)

### État déploiement
- Prévu: Vercel + Neon Postgres
- Installé: next-pwa, dexie, recharts, playwright
- Configuré: manifest.json, next.config.js withPWA, Dexie v1, playwright.config.ts
- Déployé: À déployer (DATABASE_URL + AUTH_SECRET côté serveur Vercel uniquement, jamais frontend)

### Tests
- Réellement exécutés: Aucun (node_modules absent, pas internet) - environnement conteneur
- Restant à exécuter localement: pnpm install + pnpm typecheck + pnpm test + npx playwright test (130+ tests)
