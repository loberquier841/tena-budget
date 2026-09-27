
# TENΛ Budget - Roadmap 23 Etapes Minimum - Correction officielle

Roadmap officielle fixee a 23 etapes minimum (au lieu de 27). Anciennes etapes 21-27 regroupees intelligemment dans Etapes 21,22,23 sans supprimer aucune fonctionnalite.

## Roadmap 23 etapes

Etapes 1-13: Validees proprietaire (fondations, budgets, transactions, recurring, savings, analytics, simulations, export, backup, banking mock MOCK_ONLY, security audit 11 verifications PASS, beta familiale preparation)

Etapes 14-20: Preparees code PASS, NON VERIFIEES reellement (tests reels, deploiement Vercel/Neon, PWA, offline/sync, PC eteint, appareils reels, DeepSeek reel, beta reelle, RGPD reel, performance reelle Vitest) - probleme environnement conteneur sans internet ConnectionRefused, a verifier localement pnpm install + typecheck + test + playwright test + build + deploiement Vercel/Neon + PWA Lighthouse + PC eteint + beta + RGPD

### Etape 21 / 23 minimum - Deploiement reel + tests reels + appareils + PWA + PC eteint (regroupe anciennes 21-23)

Priorites:
- Deploiement reel Vercel + PostgreSQL manage + migrations Prisma + variables serveur + build reel + /api/health reellement accessible + authentification + session + pages principales
- Installer dependances environnement avec Internet pnpm install + build + PostgreSQL + auth
- Vrais tests build/typecheck/Vitest/Playwright - nombres exacts PASS/FAIL/NON EXECUTES
- PWA + offline/sync - installation reelle, standalone, hors connexion, creation locale, retour reseau, synchronisation, conflit, service worker, Lighthouse mesure reellement
- Test PC eteint - eteindre PC personnel, utiliser TENΛ Budget depuis autre appareil, tester connexion, dashboard, transaction, offline, sync, ne marquer VERIFIE qu'apres test reel
- Vrais appareils - telephone 375px, tablette 768px, ordi 1200px+ tactile clavier/souris
- Banque MOCK uniquement, aucun fournisseur reel sans validation proprietaire, PC jamais serveur
- Ne marque jamais deploye sans deploiement reel, jamais teste sans execution reelle, controles Python ne remplacent pas Vitest/Playwright

### Etape 22 / 23 minimum - Beta reelle + securite + RGPD + audit DeepSeek + performance (regroupe anciennes 24-26)

Priorites:
- Beta familiale reelle - plusieurs comptes owner/admin/member/child, plusieurs appareils limite 3, invitations code 6 chars, permissions child refuse canAskAssistant false, seuil 500EUR owner, budgets Int familial global vs individuel jamais melanges, transactions Int personId obligatoire isDeleted exclu, isolation familles fam1 vs fam2 aucune fuite
- Permissions - 48 assertCan + familyId + personId + seuil 500EUR + child refuse
- Isolation familles - 23 fichiers filtrent familyId + filterValidTransactions
- RGPD reel - anonymisation apres 30j isDeleted anonymizeTransaction + shouldAnonymize + hardDeleteTransaction encadre owner+confirmation+30j+familyId + runAnonymizationJob + registre 6 activites + export famille/personne isole + isDeleted exclu + totaux Int verifies
- Performances reelles - 100/1000/5000/10000 transactions filterValid + getSpendingByCategory + getMonthlyEvolution + advancedSearch 8 filtres + tri + pagination 10/page + SyncQueue ne perd jamais - mesures reelles publiees objectif <100ms filter 1000 <200ms search 5000
- Audit DeepSeek reellement effectue - audit independant complet 13 categories permissions/familyId/personId/simulations/soft delete/validation/secrets/auth/sync/backups/donnees sensibles/import/banking mock + pour chaque probleme -> risque -> correction -> test non-regression + aucun probleme masque ou supprime simplement pour faire passer audit
- Corrections + tests de non-regression - budget.test.ts Int centimes, step5 advancedSearch 8 filtres + tri + pagination + isDeleted exclu, step6 getSpendingByCategory + getMonthlyEvolution + getBudgetVsSpent Int + familyId isole + isDeleted exclu, step7 sim_/simtx_ isolees assertNoRealTransactionModified, step11 MOCK_ONLY + aucun SDK reel + hashDedup + validation humaine obligatoire, step12 11 verifications audit, step13 beta familiale 4 membres + permissions 9 + isolations 4 + performance + RGPD, step14 anonymisation 30j + hard delete encadre + registre 6 activites
- Banque MOCK uniquement, PC jamais serveur

### Etape 23 / 23 minimum - Finition finale + documentation + version finale (regroupe anciennes 27 + finition)

Priorites:
- Finition UI/UX tous ecrans /dashboard /budgets /transactions /recurrentes /objectifs /famille /historique /simulations /assistant /import /exports /sauvegardes /banking /audit /beta coherents + OfflineIndicator + ResponsiveNav 260px fixe + mobile coulissant overlay + auto-fit minmax 220px/300px + padding-top 56px mobile + inputs min-width 200
- Compatibilite 375px/768px/1200px+ tactile clavier/souris navigation mobile/desktop aucun ecran casse ou debordement + preparation Capacitor/Tauri sans reecrire core
- Documentation utilisateur + guide installation PWA + guide famille + guide import 11 etapes + guide banking mock + guide RGPD export/suppression + guide deploiement Vercel/Neon + ARCHITECTURE.md + DEPLOYMENT.md + RGPD.md + COMPATIBILITE.md + SECURITE_DEEPSEEK.md + 23 etapes roadmap
- Release notes + changelog + checklist complete 23 etapes toutes PASS reelles + preparation production + validation proprietaire finale
- Banque MOCK uniquement, PC jamais serveur, aucune fonctionnalite supprimee

## Bibliotheques et services externes - 23 etapes

| Lib | Licence | Prevu | Installe package.json | Configure | Deployee |
|-----|---------|-------|------------------------|-----------|---------|
| next-pwa 5.6.0 | MIT | Oui | Oui | Oui next.config.js + manifest.json | Non - Vercel build |
| dexie 4.0.8 | Apache 2.0 | Oui | Oui | Oui dexie.ts TenaDatabase v1 | Non - IndexedDB |
| recharts 2.12.0 | MIT | Oui | Oui | Oui Charts.tsx | Non |
| playwright 1.42.0 | MIT | Oui | Oui | Oui config | Non - CI |
| exceljs | MIT | Oui Etape 7 | Non | Prepare export.ts | Non |
| papaparse | MIT | Oui | Non | Prepare | Non |
| jspdf | MIT | Oui | Non | Prepare | Non |
| Capacitor | MIT | Oui Etape 21 | Non | Prepare core compatible | Non |
| Tauri | MIT/Apache 2.0 | Oui Etape 21 | Non | Prepare core compatible | Non |
| GoCardless SDK | N/A | Non (mock) | Non | Non | Non - a comparer |
| Tink SDK | N/A | Non (mock) | Non | Non | Non - a comparer |
| Plaid SDK | N/A | Non (mock) | Non | Non | Non - a comparer |
| Budget Insight SDK | N/A | Non (mock) | Non | Non | Non - a comparer |

Aucun fournisseur bancaire definitif choisi - a comparer apres Etape 23, attente validation proprietaire.

## Regles absolues conservees - 23 etapes

- Toutes fonctionnalites validees conservees - aucune supprimee meme si roadmap passe 27->23
- Tests Vitest/Playwright 170+ conserves
- Securite 48 assertCan + 23 familyId + isDeleted exclu + sim_/simtx_ isolees + VALIDATION_REQUIRED + 0 secret frontend + MOCK_ONLY
- Isolation familles fam1 vs fam2 aucune fuite
- Permissions owner/admin/member/child + seuil 500EUR + canAskAssistant child false
- Regle PC personnel jamais necessaire + jamais serveur
- Simulations isolees sim_/simtx_ jamais modif reelles
- Aucun paiement/achat automatique
- Aucune banque reelle sans validation proprietaire
- 23 etapes minimum, meme si etapes supplementaires necessaires au-dela
