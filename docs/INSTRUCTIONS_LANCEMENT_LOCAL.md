# TENΛ Budget - Instructions Lancement Local - Étape 23 / 23 minimum

## Prérequis

- Node.js >=20.9.0 (requis Next.js 14.2) - vérifier `node --version`
- pnpm >=8.0.0 - vérifier `pnpm --version`
- Internet - requis pour pnpm install

## Installation

```bash
pnpm install
```

Vérifie: 0 erreur, node_modules créé

## Typecheck

```bash
pnpm typecheck
```

Vérifie: 0 erreur TypeScript

## Tests Vitest

```bash
pnpm test
```

Attendu: 178+ tests PASS (170+ existants + 8 Autopilot), 0 FAIL

## Tests E2E Playwright

```bash
npx playwright install
pnpm test:e2e
# ou
npx playwright test
```

Attendu: 30+ tests PASS

## Build

```bash
pnpm build
```

Vérifie: build Next.js PASS, .next créé, SW généré par next-pwa

## Lancement dev

```bash
pnpm dev
# ou
pnpm --filter @tena/web dev
```

Ouvre http://localhost:3000

## Variables .env.local

Copier .env.example vers .env.local et remplir avec vraies valeurs (Neon DATABASE_URL + AUTH_SECRET 32 chars + NEXTAUTH_URL)

Ne jamais commit .env.local

## État actuel

Toutes commandes ci-dessus: NON EXÉCUTÉES dans conteneur sans internet Node 16.20.2 - à exécuter dans environnement externe avec Internet + Node 20.9+

Aucun élément marqué VÉRIFIÉ tant que opérations non réellement exécutées.
