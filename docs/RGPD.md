
# TENΛ Budget - RGPD / Données - Étape 13 / 20 minimum

## Principes RGPD

### 1. Isolation données familiales

- Toutes données filtrées `familyId`, aucune fuite cross-family vérifiée audit 37 assertCan + 16 familyId filters
- `filterValidTransactions`, `advancedSearch`, `getSpendingByCategory` filtrent familyId première ligne
- Tests: familyId isolation PASS

### 2. Droit à l'effacement - Soft delete

- `isDeleted=true + deletedAt=Date`, jamais suppression physique DB
- `softDeleteTransaction`, `softDeleteBudget`, `softDeleteRecurringRule`, `softDeleteGoal` obligatoire
- Stats excluent `isDeleted`, recherche `includeDeleted=false` par défaut
- Export ne contient pas `isDeleted`
- Backup filtre `!isDeleted`

**Vérification concrète:**
- Créer transaction tx1, softDelete tx1 → isDeleted=true, deletedAt=now, filterValidTransactions exclut tx1, dashboard total réduit, recherche ne trouve plus sauf includeDeleted=true

### 3. Droit d'accès - Export

- `prepareExcelExport` sheets Transactions + Budgets, `totalCents` Int vérifié `verifyExportTotals`
- `prepareCsvExport` conserve `MontantCents + MontantEuros` affichage, filtres familyId/personId respectés
- `preparePdfExport` summary budgeted/spent/remaining Int
- Tous exports respectent `familyId/personId/category/fromDate/toDate`, `isDeleted` exclu

**Vérification concrète:**
- Export famille fam1 → seulement données fam1, pas fam2
- Export personne p1 → seulement p1

### 4. Données sensibles

- `IBAN masqué` FR76 **** **** 1234 uniquement, jamais complet
- Aucun mot de passe bancaire stocké, `BankConnector MOCK_ONLY`
- `AUTH_SECRET` serveur Vercel uniquement, jamais frontend (grep 0 occurrence frontend)
- `DATABASE_URL` serveur uniquement
- `password` jamais loggué backup.ts

### 5. Consentement bancaire

- PSD2 lecture seule uniquement, consent 90j mock, expiration `consentExpiresAt`, révocation `revokedAt`
- Validation humaine obligatoire `requiresHumanValidation()=true`, `VALIDATION_REQUIRED`
- Aucune Transaction réelle créée sans validation

### 6. Minimisation données

- Seulement `familyId, personId, amountCents Int, bookingDate, label, categoryId, source, isDeleted, hashDedup` stockés
- Pas de tracking externe, pas de Google Analytics, pas de données superflues

### 7. Sécurité

- 37 assertCan serveur, seuil 500€ owner, permissions owner/admin/member/child
- AES-GCM 256 backups chiffrés, SHA-256 checksum, PBKDF2 100000 iterations
- HTTPS Vercel, JWT httpOnly, bcrypt passwords

## État réel RGPD Étape 13

- Soft delete: implémenté et vérifié PASS
- Export: implémenté PASS (Int totaux vérifiés)
- Isolation familyId: implémenté et vérifié PASS
- Secrets: 0 dans frontend PASS
- Banking consent: mock uniquement, pas de vraie donnée bancaire
- Anonymisation: à implémenter Étape 14 (suppression définitive après 30j isDeleted)

## Limites restantes

- Anonymisation automatique après 30j isDeleted: à implémenter Étape 14
- Droit oubli complet (hard delete après soft): à implémenter Étape 14 avec confirmation owner
- Registre traitements: à créer Étape 14
