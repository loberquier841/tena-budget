# DEMARRAGE_CLINE.md — Règles communes aux 20 agents Cline

## Projet

TENΛ Budget — dépôt existant `/Users/dg/Documents/Loïs/TENΛ Budget` (monorepo pnpm/turbo, Flutter, Next.js, Capacitor, Electron).

## Règle absolue : 20 sessions maximum

Au plus **20 agents Cline** (sessions) sont autorisés. Chaque session porte un numéro de 1 à 20, attribué dans `PLAN_20_SESSIONS.md` et suivi dans `REGISTRE_TACHES.md`.

## Règles communes (s'appliquent à tous les agents)

### 1. Un fichier = un agent

Aucun fichier source ne doit être modifié simultanément par deux agents. Chaque fichier est réservé à une session unique, listée dans `REGISTRE_TACHES.md`. Si un agent a besoin d'un fichier déjà réservé, il doit attendre que la session le libère et valider avec le coordonnateur.

### 2. Espace de travail isolé par agent

Chaque agent exécute ses commandes dans un environnement isolé :

- Branche Git dédiée : `feature/sline-XX-<nom-mission>` (XX = numéro de session)
- Aucun `git commit`, `git push`, `git merge` sans autorisation expresse du coordonnateur
- Les tests s'exécutent localement dans le propre terminal de l'agent
- Pas de partage de `node_modules` ou de build entre agents (chacun installe ses propres dépendances si nécessaire)

### 3. Préservation des fichiers `.backup`

Tous les fichiers `.backup` et `.backup_*` présents dans `tena_app/lib/` (main.dart, database_service.dart, transactions_page.dart, finance_chart.dart, widget_test.dart et variantes) doivent être **préservés intacts**. Aucun agent ne doit les modifier, les supprimer ni les renommer.

### 4. Aucun engagement financier ni serveur payant

- Aucun commit, push, merge
- Aucun serveur payant (Vercel, Neon, etc.) sans autorisation
- Aucun achat, aucun abonnement, aucun paiement
- Le dépôt reste sur `origin/main` ; aucune modification du remote

### 5. Pas de nouvelle application

On travaille exclusivement sur le dépôt TENΛ Budget existant. Interdiction de créer une nouvelle application ou un nouveau projet.

### 6. Lecture seule en attendant la validation

Tant que le coordonnateur n'a pas validé l'intégration globale, aucune session ne doit intégrer ses modifications dans la branche principale. Les modifications restent dans la branche de travail de l'agent.

### 7. Tests obligatoires avant intégration

Chaque agent doit exécuter les tests de son périmètre (Vitest, Playwright ou Flutter `flutter test`) et obtenir 0 échec avant de demander l'intégration.

### 8. Communication

Tout blocage, conflit de fichier ou besoin de partager un fichier doit être signalé au coordonnateur avant action.

## Livrables attendus par session

À la fin de sa mission, chaque agent produit :

- La liste des fichiers modifiés (dans sa branche isolée)
- Le résultat des tests (PASS/FAIL)
- Une note d'impact sur les autres sessions