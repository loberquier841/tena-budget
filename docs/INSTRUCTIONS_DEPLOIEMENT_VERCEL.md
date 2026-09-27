# TENΛ Budget - Instructions Déploiement Vercel + PostgreSQL - Étape 23 / 23 minimum

## Architecture retenue

Vercel (Next.js 14) + Neon PostgreSQL + PWA Dexie - PC personnel jamais serveur

## 1. Créer base PostgreSQL Neon

- Aller sur https://neon.tech
- Créer projet Free
- Copier DATABASE_URL: postgresql://user:password@ep-xxx.neon.tech/tena?sslmode=require

## 2. Configurer Vercel

- Importer repo GitHub sur https://vercel.com
- Framework preset: Next.js
- Build command: pnpm build (depuis vercel.json)
- Install command: pnpm install
- Variables d'environnement (serveur uniquement, jamais frontend):
  - DATABASE_URL = postgresql://... (type @database-url)
  - AUTH_SECRET = random 32 chars min (type @auth-secret) - générer `openssl rand -base64 32`
  - NEXTAUTH_URL = https://tena-budget.vercel.app (type @nextauth-url)

## 3. Migrations Prisma

```bash
pnpm install
npx prisma migrate deploy
```

Ou Vercel build hook avec `prisma migrate deploy`

## 4. Déployer

```bash
vercel --prod
# ou git push -> auto deploy Vercel
```

## 5. Vérifier réellement

- /api/health -> 200 { app: TENΛ Budget, version 0.23.0, stage Étape 23/23, database configured server only, auth configured server only, pwa, offline, banking MOCK_ONLY, pcRequired false, timestamp }
- /login -> Auth.js v5 Credentials + bcrypt + JWT httpOnly
- Session réelle
- /dashboard, /budgets, /transactions, /import 11 étapes, /banking mock, /audit, /beta, /famille, /autopilot
- Ne donne URL comme fonctionnelle qu'après vérification réelle /api/health 200 + login + session + pages principales

## 6. PWA

- manifest.json display standalone theme_color #7C3AED icons 192/512 + next-pwa 5.6.0 MIT dest public register true skipWaiting true
- Installation iPhone/Android réelle
- Standalone
- Service worker
- Lighthouse mesuré réellement `npx lighthouse https://tena-budget.vercel.app --view`

## 7. Test PC éteint

- Éteindre complètement PC personnel
- Depuis autre appareil (téléphone/tablette/ordinateur):
  - Connexion
  - Consultation dashboard/budgets/transactions
  - Ajout/modification transaction
  - Offline avion + création locale
  - Retour réseau + synchronisation
- Ne marquer VÉRIFIÉ qu'après test réel

## 8. Appareils

- Téléphone 375px
- Tablette 768px
- Ordinateur 1200px+
- Tactile + clavier/souris
- Aucun écran cassé ou débordement

## État actuel

Déploiement réel: NON EXÉCUTÉ - URL aucune - vercel.json EXISTS mais build non exécuté dans conteneur sans internet

Aucun élément marqué VÉRIFIÉ tant que opérations non réellement exécutées.
