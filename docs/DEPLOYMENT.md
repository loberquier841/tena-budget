
# TENΛ Budget - Déploiement - Étape 13 / 20 minimum

## État réel du déploiement - Étape 13

**Déployé:** NON - pas encore déployé sur Vercel/Neon. À faire Étapes 14-15.

**Prévu:** Vercel (Next.js) + Neon Postgres Free
**Installé (package.json):** next-pwa@5.6.0 MIT, dexie@4.0.8 Apache 2.0, recharts@2.12.0 MIT, @playwright/test@1.42.0 MIT
**Configuré:** next.config.js withPWA dest public register true, public/manifest.json display standalone, Dexie TenaDatabase v1, Auth.js, Prisma schema
**Déployé:** À déployer - nécessite DATABASE_URL Neon + AUTH_SECRET + NEXTAUTH_URL Vercel env

## Prérequis déploiement réel

```bash
# 1. Neon Postgres
DATABASE_URL=postgresql://user:password@ep-xxx.neon.tech/tena?sslmode=require

# 2. Vercel env
AUTH_SECRET=xxx (32 chars random)
NEXTAUTH_URL=https://tena-budget.vercel.app
DATABASE_URL=postgresql://...

# 3. Prisma
npx prisma migrate deploy

# 4. Build
pnpm build (next-pwa génère SW + manifest)

# 5. Test PWA
Lighthouse PWA 100%, offline test avion, installable iPhone/Android
```

## PC personnel jamais nécessaire

- Après déploiement Vercel+Neon, PC éteint = app continue
- PC allumé uniquement: pnpm dev + git push + prisma migrate deploy
- Aucun serveur local sur PC, aucune SQLite locale, aucun ngrok

## Vérifications déploiement (à faire réel)

- [ ] Vercel build OK
- [ ] Neon Postgres connexion OK
- [ ] Auth login OK (bcrypt)
- [ ] PWA installable iPhone/Android OK
- [ ] Offline avion OK (Dexie)
- [ ] Sync online OK (SyncQueue → Neon)
- [ ] Manifest display standalone OK
- [ ] Service worker cache OK
- [ ] HTTPS OK
- [ ] DATABASE_URL jamais frontend
- [ ] AUTH_SECRET jamais frontend

## Banking

Aucun déploiement banking réel tant que fournisseur non validé propriétaire.

## 20 étapes minimum

Déploiement réel prévu Étapes 14-15, pas avant validation tests réels Étape 13.
