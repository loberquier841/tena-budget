
import { NextResponse } from 'next/server';

export async function GET() {
  const checks = {
    app: 'TENΛ Budget',
    version: '0.16.0',
    stage: 'Étape 16 / 20 minimum - Déploiement réel + tests réels',
    database: process.env.DATABASE_URL ? 'configured (server only, never frontend)' : 'not configured - requires DATABASE_URL Neon',
    auth: process.env.AUTH_SECRET ? 'configured (server only, never frontend)' : 'not configured - requires AUTH_SECRET',
    nextauthUrl: process.env.NEXTAUTH_URL ? 'configured' : 'not configured',
    pwa: 'manifest.json + next-pwa 5.6.0 MIT + service worker',
    offline: 'Dexie 4.0.8 Apache 2.0 TenaDatabase v1 transactions/budgets/syncQueue/conflicts',
    sync: 'SyncQueue + ConflictLog ne perd jamais donnée',
    banking: 'MOCK_ONLY=true NO_REAL_SDK=true READ_ONLY=true - aucun SDK réel, aucun fournisseur choisi',
    pcRequired: false,
    architecture: 'PWA Dexie (offline source vérité) ↔ HTTPS ↔ Vercel (Next.js+Auth.js+API) ↔ Neon Postgres (familyId isolé)',
    checks: {
      build: 'À vérifier: pnpm build',
      database: 'À vérifier: Prisma + Neon connexion',
      auth: 'À vérifier: login bcrypt + JWT httpOnly + session',
      health: 'PASS - /api/health répond',
      pages: 'À vérifier: /dashboard /transactions /import /banking /audit',
      pwa: 'À vérifier: manifest display standalone + SW cache + installable',
      offline: 'À vérifier: avion mode + Dexie + création locale',
      sync: 'À vérifier: retour réseau + SyncQueue → Neon',
      security: 'À vérifier: DATABASE_URL jamais frontend + AUTH_SECRET jamais frontend + familyId isolé',
    },
    timestamp: new Date().toISOString(),
  };
  return NextResponse.json(checks);
}
