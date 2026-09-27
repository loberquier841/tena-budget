
# TENΛ Budget - Roadmap 27 Étapes Minimum - Mode Accéléré Autorisé

**Rappel: 27 étapes minimum, regroupement par blocs compatibles autorisé sans supprimer fonctionnalités, sécurité intacte, PC jamais serveur, MOCK bancaire uniquement sans validation propriétaire.**

## Blocs accélérés

### BLOC 1 - Consolidation + Déploiement + Tests + PWA + PC éteint + Bêta + RGPD + Performance + Compatibilité + Sécurité (Étapes 14-18)
- **Objectif:** Passer projet préparé → application réellement testée et déployée
- **Inclus:**
  - Étape 14: Validation technique réelle + RGPD anonymisation + hard delete encadré + registre 6 activités + performance 100/1000/5000/10000 + déploiement préparation vercel.json + .env.example + /api/health
  - Étape 15: Tests réels pnpm install + typecheck + vitest + playwright + déploiement Vercel/Neon + PWA + offline/sync + PC éteint + bêta familiale + RGPD + performance
  - Étape 16: Déploiement réel Vercel/Neon + build + base PostgreSQL + auth + session + /api/health + pages principales + tests réels + PWA + offline/sync + PC éteint + sécurité
  - Étape 17: Déploiement réel + tests réels + PWA + offline + sync + PC éteint + bêta familiale + RGPD + performance + banque MOCK + règle absolue ne jamais marquer déployé/testé/fonctionnel/vérifié uniquement parce que code existe
  - Étape 18: Compatibilité 375px/768px/1200px+ + tactile + clavier/souris + PWA installable + navigation mobile/desktop + aucun écran cassé + préparation Capacitor/Tauri sans réécrire core + audit DeepSeek 13 catégories permissions/familyId/personId/simulations/soft delete/validation/secrets/auth/sync/backups/données sensibles/import/banking mock + sécurité utilisateur ne puisse jamais lire autre famille/contourner permissions/modifier sans autorisation/contourner validation import/transformer simulation en réelle/acceder secret serveur + banque MOCK + PC jamais serveur
- **Dépendances:** Aucune entre ces 5 étapes - toutes peuvent être préparées en parallèle code, mais vérification réelle nécessite internet + Vercel/Neon + device réel
- **État réel:** Code préparé PASS, tests réels NON EXÉCUTÉS - problème environnement ConnectionRefused pas internet dans conteneur, à exécuter localement pnpm install + typecheck + test + playwright test + build + déploiement Vercel/Neon + PWA Lighthouse + PC éteint + bêta + RGPD
- **Prêt pour bloc suivant:** Oui, code prêt pour Bloc 2 même si vérification réelle en attente environnement

### BLOC 2 - Finition Mobile/Desktop + Documentation + Sécurité Finale + Performance Finale + Finition UI/UX (Étapes 19-23)
- **Étape 19:** Compatibilité réelle 375/768/1200 + tactile + clavier/souris + PWA installable + navigation + Capacitor/Tauri préparation sans réécrire core + tests device réel Chrome DevTools + iPhone/Android
- **Étape 20:** Sécurité finale DeepSeek + audit indépendant + tests non-régression + vulnérabilités 0 + corrections sans masquer problèmes
- **Étape 21:** Documentation utilisateur + guide installation PWA + guide famille + guide import 11 étapes + guide banking mock + guide RGPD export/suppression + guide déploiement Vercel/Neon + ARCHITECTURE.md + DEPLOYMENT.md + RGPD.md + 27 étapes roadmap
- **Étape 22:** Performance finale 100/1000/5000/10000 + optimisation index familyId+personId+categoryId+bookingDate + pagination 10/page + Dexie where(familyId) + Map/Set
- **Étape 23:** Finition UI/UX tous écrans /dashboard /budgets /transactions /recurrentes /objectifs /famille /historique /simulations /assistant /import /exports /sauvegardes /banking /audit /beta cohérents + OfflineIndicator + ResponsiveNav + auto-fit minmax

### BLOC 3 - Version Finale + Release + Validation Propriétaire + Prêt Production + Future Banking (Étapes 24-27)
- **Étape 24:** Version finale v1.0 + changelog + release notes + checklist 27 étapes toutes PASS réelles
- **Étape 25:** Validation propriétaire finale + bêta publique + retours UX + corrections sans supprimer fonctionnalité
- **Étape 26:** Prêt production + déploiement Vercel/Neon vérifié + URL réelle fonctionnelle + test PC éteint réel VÉRIFIÉ + PWA Lighthouse mesuré réel + offline/sync réel VÉRIFIÉ
- **Étape 27:** Future banking comparaison GoCardless/Tink/Plaid/Budget Insight + aucun fournisseur choisi + aucun SDK réel + MOCK_ONLY + documentation comparatif + attente validation propriétaire pour vraie connexion bancaire + roadmap au-delà 27 si nécessaire

## État actuel

- Étapes 1-13: Validées propriétaire
- Étapes 14-18: Préparées code PASS, NON VÉRIFIÉES réellement (tests réels, déploiement, PWA, offline/sync, PC éteint) - problème environnement conteneur sans internet, à vérifier localement
- Étapes 19-27: À développer en mode accéléré par blocs

## Bibliothèques et services externes - 27 étapes

| Lib | Licence | Prévu | Installé package.json | Configuré | Déployé |
|-----|---------|-------|------------------------|-----------|---------|
| next-pwa 5.6.0 | MIT | Oui | Oui | Oui next.config.js + manifest.json | Non - Vercel build |
| dexie 4.0.8 | Apache 2.0 | Oui | Oui | Oui dexie.ts TenaDatabase v1 | Non - IndexedDB |
| recharts 2.12.0 | MIT | Oui | Oui | Oui Charts.tsx | Non |
| playwright 1.42.0 | MIT | Oui | Oui | Oui config | Non - CI |
| exceljs | MIT | Oui Étape 7 | Non | Préparé export.ts | Non |
| papaparse | MIT | Oui | Non | Préparé | Non |
| jspdf | MIT | Oui | Non | Préparé | Non |
| Capacitor | MIT | Oui Étape 19 | Non | Préparé core compatible | Non |
| Tauri | MIT/Apache 2.0 | Oui Étape 19 | Non | Préparé core compatible | Non |
| GoCardless SDK | N/A | Non (mock) | Non | Non | Non - à comparer |
| Tink SDK | N/A | Non (mock) | Non | Non | Non - à comparer |
| Plaid SDK | N/A | Non (mock) | Non | Non | Non - à comparer |
| Budget Insight SDK | N/A | Non (mock) | Non | Non | Non - à comparer |

Aucun fournisseur bancaire définitif choisi - à comparer après Étape 27.

## Règles absolues conservées

- Toutes fonctionnalités validées conservées
- Tests Vitest/Playwright 170+ conservés
- Sécurité 48 assertCan + 23 familyId + isDeleted exclu + sim_/simtx_ isolées + VALIDATION_REQUIRED + 0 secret frontend + MOCK_ONLY
- Isolation familles fam1 vs fam2 aucune fuite
- Permissions owner/admin/member/child + seuil 500€ + canAskAssistant child false
- Règle PC personnel jamais nécessaire + jamais serveur
- Simulations isolées sim_/simtx_ jamais modif réelles
- Aucun paiement/achat automatique
- Aucune banque réelle sans validation propriétaire
- 27 étapes minimum, même si étapes supplémentaires nécessaires au-delà
