# MISSION C01-A — Rapport Prisma et Authentification TENΛ Budget

**Date** : génération statique, environnement sans Node.js/pnpm
**Référentiel** : code lu en intégralité
**Règle** : aucune exécution runtime
## 1. Constats — Pourquoi Prisma et DATABASE_URL sont nécessaires

### 1.1 Schéma Prisma (`packages/db/prisma/schema.prisma`)

Le schémaDeclare explicitement une source de données PostgreSQL :

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

**Conséquence directe** : sans `DATABASE_URL` défini, toute opération Prisma échouera au démarrage. Le client Prisma ne peut être généré ni utilisé.
## 2. État réel des fichiers — Ce qui manque vraiment

| Fichier / Élément | Statut | Preuve dans le code |
|---|---|---|
| `.env` racine | **Absent** | `grep -r DATABASE_URL` → 0 occurrence frontend (SECURITY_AUDIT.md l.58) |
| `.env.local` | **Absent** | Aucun fichier `.env` trouvé dans la racine du projet |
| Migrations Prisma | **Absentes** | Dossier `prisma/migrations` inexistant ou vide |
| Client Prisma généré | **Non généré** | `prisma generate` jamais exécuté |
| `AUTH_SECRET` | **Non défini** | `process.env.AUTH_SECRET` dans auth.ts ligne 17, aucune valeur par défaut |
| `NEXTAUTH_URL` | **Non défini** | Non configuré, nécessaire pour les callbacks JWT |
| `exceljs` | **Non installé** | Dépendance "Prévue" dans SECURITY_AUDIT.md l.84 |
| `papaparse` | **Non installé** | Dépendance "Prévue" dans SECURITY_AUDIT.md l.85 |
| `jspdf` | **Non installé** | Dépendance "Prévue" dans SECURITY_AUDIT.md l.86 |

### 1.2 `auth.ts` — Dependence Prisma pour l'authentification
## 3. Corrections apportées (documentation uniquement)

### 3.1 Création de `.env.example`

Fichier créé à la racine du projet avec les variables minimales requis :

```env
# DATABASE_URL
# Format postgresql://username:password@host:port/database
DATABASE_URL="postgresql://postgres:password@localhost:5432/tenabudget"

# AUTH_SECRET - générer avec : openssl rand -hex 32
AUTH_SECRET="votre-secret-ici-au-moins-32-caracteres"

# NEXTAUTH_URL - URL de développement ou de production
NEXTAUTH_URL="http://localhost:3000"
```

**But** : permettre à tout développeur de créer son `.env.local` en se basant sur ce modèle. Les valeurs réelles dépendent de la base PostgreSQL choisie (Neon, Supabase, PostgreSQL local).

## 4. Ce qui fonctionnerait SI les corrections étaient appliquées

Si on suit les étapes suivantes (non exécutées dans cet environnement) :

1. `DATABASE_URL` pointe vers une base PostgreSQL fonctionnelle
2. `AUTH_SECRET` a une valeur aléatoire de 32+ caractères
3. `NEXTAUTH_URL` correspond à l'URL de développement ou de production
4. `pnpm prisma migrate dev` est exécuté (création tables User, Family, etc.)
5. `pnpm prisma generate` génère le client Prisma
6. `pnpm install` installe les dépendances (dont exceljs, papaparse, jspdf)

Alors :

- `auth.ts` fonctionnerait : `prisma.user.findUnique` trouverait les utilisateurs
- `signIn` avec credentials marcherait : bcrypt compare le mot de passe avec `user.passwordHash`
## 5. Limites de l'environnement actuel

| Limite | Impact | Contournement |
|---|---|---|
| Pas de Node.js/pnpm | Impossible d'exécuter `pnpm install`, `pnpm prisma migrate`, tests | Analyse statique uniquement ; corrections documentées |
| Pas de base PostgreSQL | `auth.ts` inutilisable sans DATABASE_URL | Documentation des options d'hébergement |
| 3 dépendances d'export manquantes | Pages `/import` et `/exports` inopérantes | Documenté dans SECURITY_AUDIT.md ; à installer séparément |
| Schéma Prisma non migré | Tables inexistantes en BDD | Migrations à exécuter après setup DB |

## 6. Fichiers modifiés dans ce cadre

| Fichier | Action | Motif |
|---|---|---|
| `/.env.example` | Créé | Modèle de configuration pour développeurs |
| `/.env.local` | Créé | Template avec valeurs placeholder (à remplir) |
| `docs/quality/RAPPORT_C01A_PRISMA_AUTH.md` | Créé | Ce rapport de mission |

**Aucun fichier applicatif `.tsx`, `.ts` source n'a été modifié** — conformément à la règle de ne modifier que ce qui est nécessaire pour la correction de mission, et dans ce cas, seules les fichiers de configuration/documentation ont été créés.

## 7. Risques restants et prochaines étapes

| Risque | Gravité | Description |
|---|---|---|
| Authentification cassée sans Prisma config | Critical | `auth()` renverra `null` → tout l'app en mode "déconnecté" |
| Import/Export fonctionnels | Medium | `exceljs`, `papaparse`, `jspdf` non installés → pages inopérantes |
| Protection middleware partielle | Medium | Seule `/famille/` couverte ; autres routes via `await auth()` en page |
| familyId localStorage dans transactions | Low | `localStorage.getItem('familyId') || 'p1'` → risque d'incohérence multi-users |

**Prochaines étapes recommandées** (hors périmètre immédiat sans environnement d'exécution) :
1. Lancer `pnpm install` dans un environnement Node compatible
2. Créer une base PostgreSQL (Neon/Docker) et configurer `DATABASE_URL`
3. Exécuter `pnpm prisma migrate dev --create-only` pour créer les tables
4. Exécuter `pnpm prisma generate` pour générer le client
5. Lancer le serveur de développement : `pnpm run dev`
6. Tester `localhost:3000/login` avec des identifiants de test

---
**Fin du rapport C01-A** — Analyse statique uniquement. Aucune exécution runtime effectuée. Aucune dépendance payante créée ou référencée.
- `session` callback mettrait à jour `token.id` et `(session as any).userId = token.id`
- Les pages protégées `await auth()` afficheraient le contenu correctement
- La middleware protégerait les routes via `req.auth`

**Reste à faire** : installer Node ≥ 20.9 + pnpm ≥ 8, exécuter les commandes ci-dessus.
### 3.2 Création de `.env.local` (template vide)

Fichier créé à la racine avec des valeurs de placeholder :

```env
# Fichier .env.local — NE PAS committer. Remplir avec les vraies valeurs.
DATABASE_URL="postgresql://USER:PASSWORD@HOST:PORT/DB_NAME"
AUTH_SECRET="generer-avec-openssl-rand-hex-32"
NEXTAUTH_URL="http://localhost:3000"
```

**Important** : Ce fichier ne doit **jamais** être commité dans Git. Les vraies valeurs dépendent de l'environnement d'hébergement.

### 3.3 Documentation des options Prisma / PostgreSQL

Trois options s'offrent à l'équipe (documentation seulement, pas d'implémentation) :

| Option | Description | Avantages | Inconvénients |
|---|---|---|---|
| **A. PostgreSQL Neon (cloud)** | Inscription sur neon.tech, créer une base | - Pas de serveur à maintenir<br>- Accès facile depuis Vercel<br>- Crédits gratuits disponibles | - Coût potentiel après seuil gratuit<br>- nécessite internet |
| **B. PostgreSQL local (Docker)** | `docker run -e POSTGRES_DB=tenabudget -p 5432:5432 postgres` | - Total contrôle<br>- Aucun coût cloud | - Doit faire tourner Docker en permanence<br>- Configuration réseau requise |
| **C. Prisma Accelerate** | Service de proxy Prisma pour le cache | - Améliore les performances<br>- Facilite le déploiement | - Service supplémentaire<br>- Peut avoir un coût |

**Note** : L'option C (Prisma Accelerate) nécessite un compte Prisma et n'est pas gratuite indéfiniment. Les options A et B évitent les services payants récurrents.

Le fichier `apps/web/auth.ts` ligne 6 importe et utilise Prisma :

```typescript
import { prisma } from "@tena/db";
```

Lignes 31-36 — vérification mot de passe par bcrypt avec Prisma :

```typescript
const user = await prisma.user.findUnique({
  where: { email },
});
if (!user) return null;
const ok = await bcrypt.compare(password, user.passwordHash);
if (!ok) return null;
```

**Pourquoi DATABASE_URL est indispensable** :
- Sans `DATABASE_URL`, `prisma.user.findUnique` lancera une erreur "P2003" ou "Connecting to database failed"
- `auth()` renverra `null` → toutes les pages protégées `await auth()` afficheront "Non connecté"
- La middleware ne pourra pas rediriger vers `/login` car il n'y aura pas de session

### 1.3 Architecture locale-first vs auth serveur

Le présentement de TENΛ Budget repose sur deux couches :

| Couche | Technologie | Stockage |
|---|---|---|
| **Données utilisateur** | IndexedDB/Dexie | LocalStorage navigateur, chiffré AES-GCM |
| **Authentification utilisateur** | NextAuth v5 + Prisma | Base PostgreSQL via `prisma.user.findUnique` |

**Résultat** : on ne peut pas faire fonctionner `auth()` sans Prisma + PostgreSQL, même si le stockage des budgets/transactions se fait localement. L'authentification est le point de connexion vers une base distante.