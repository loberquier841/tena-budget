# TENΛ Budget — Audit LOT 1 / Cartographie (réel)
_Date : 2026-11-07 (audit exécutable, sans modification destructive)._

Ce document reflète l’état **observé** du dépôt. Il ne certifie pas qu’un module est déployé, signé, publiable ou commercialement conforme sans build/vérification dédiée. Références : `docs/BRIEF_PRODUIT_REFERENCE.md` (prévalent), code, configs, `flutter --version/doctor/analyze/test/build macos --debug` (sondage).

## 1. Périmètre du produit (rappel)
- **Priorité 1** : vraie app **macOS** (`tena_app/`, Flutter), installable, hors ligne, locale-first.
- **Priorité 2** : app iPhone (après stabilisation Mac).
- **Priorité 3** : site public HTTPS **distinct** (pas un dashboard, pas l’app), liens de téléchargement réels uniquement.
- Contraintes structurantes : réutilisation maximale, **SQLite** + cible **SQLCipher**, **montants en centimes (int)** jamais en float, aucune donnée financière envoyée automatiquement, aucune fausse conformité/sécurité absolue, **13 fichiers `.backup*` intacts**.

## 2. Cartographie du dépôt
| Zone | Stack / rôle | État observé | Réutiliser ? |
|---|---|---|---|
| `tena_app/` | Flutter/Dart (56 `.dart` sous `lib/`), projets macOS/iOS/Android/web. `models/`, `pages/`, `services/`, `state/`, `theme/`, `widgets/`. | **Cœur local le plus avancé** : SQLite FFI, chiffrement applicatif AES-GCM (`tena1:`), onboarding/profil, transactions/budgets/goals/catégories, forecast/finance/insight/report/notification stubs, import CSV (pipeline unique LOT 2), sauvegarde JSON+SHA-256+chiffrement optionnel. | **Oui, base prioritaire Mac.** |
| `apps/web/` | Next.js 14/React 18, PWA, Dexie, NextAuth, recharts, workspace `@tena/*`. | Monorepo web riche en routes ; pages/données démo selon brief. Non = site vitrine public final vérifié. | Réutiliser patterns/UI/textes avec prudence ; ne pas confondre avec app native. |
| `apps/desktop/` | Electron (réutilise app React). | Présent. Packaging Mac natif via Electron ≠ app Flutter macOS. | À évaluer (hors priorité Flutter Mac). |
| `apps/mobile/` | Mobile monorepo. | Présent. | Après Mac/iPhone Flutter ou selon stratégie validée. |
| `packages/core,db,banking,import-engine,shared,ui` | Core TS, Dexie/DB, banking mock, import, shared, UI. | Réutilisable comme logique/règles ; banking **mock**. | Alignement fonctionnel ; pas de réécriture Flutter. |
| `android/` (racine), Capacitor | Android/Capacitor. | Hors phase 1. | Garder. |
| `standalone/` | HTML prototypes. | Isolés. | Trier plus tard, ne pas supprimer. |
| `docs/` | Brief, roadmaps historiques, audits/qualité. | Référence + historique. | `BRIEF_PRODUIT_REFERENCE.md` = vérité produit. |
| Scripts racine | `install_flutter.sh`, `launch.py`, turbo/pnpm. | Utilitaires. | Vérifier sécurité/pertinence avant usage. |

## 3. Modules `tena_app` — état / réutilisation
| Module | État | Notes |
|---|---|---|
| Transactions (modèle, DB, page) | **Partiel/solide local** | `Transaction.amount` = `double` (euros) ; DB chiffre champs. Dette centimes à migrer avec plan validé. |
| CSV import/export | **Stabilisé LOT 2** | Pipeline unique `ImportService` (analyse/mapping/preview/erreurs/doublons 2C) + commit chiffré `DatabaseService`. Export canonique conservé. |
| Budgets | **Fonctionnel local** | Stockage/chiffrement centimes côté budgets ; API DB corrigée (global/category) + tests déterministes. |
| Objectifs | **Fonctionnel local** | `GoalEntry` centimes, CRUD chiffré, UI page. |
| Sauvegardes | **Base fonctionnelle** | JSON versionné, SHA-256, chiffrement via `CryptoService`, validation/restauration, pas d’écrasement silencieux (suffixe). **Non prouvé** portable inter-appareil/perte de clé (dépend clé maître locale) ; documents/coffre non couverts complètement. |
| Profil/onboarding | **Présent** | `user_profile` chiffré, questionnaire/onboarding, gating `main.dart`. |
| Comptes multi, factures/OCR, coffre docs, calendrier, abonnements, patrimoine avancé, automatisations/règles, IA locale LLM, OFX/QFX/QIF, sync chiffrée | **Manquants ou incomplets** | À créer par lots en réutilisant modèles/services existants. |
| Design system Mac premium (nav latérale, shell, accessibilité, dark/light, états) | **Partiel** | `theme/`, `widgets/`, icônes macOS placeholders génériques Flutter à professionnaliser. |

## 4. Vérifications exécutées (réelles)
- `flutter --version` : stable 3.47.7 / Dart 3.13.5 (macOS arm64).
- `flutter doctor` : Flutter OK ; **Xcode non installé** (CLT seuls), **CocoaPods absent**, Android SDK absent. **macOS device détecté**.
- `flutter build macos --debug` : **échec bloquant outillage** — Xcode requis. Aucun DMG/artefact release produit.
- `flutter analyze --no-pub` : **62 issues, 0 error** (infos/warnings : imports relatifs tests, imports inutilisés, style/placeholders). Pas d’erreur de compilation signalée.
- Tests (avant/après LOT 2.1) : voir section 6.

## 5. Bloqueurs / risques majeurs
| Sujet | Constat | Action |
|---|---|---|
| Build Mac/iOS/signature/notarisation | Xcode/CocoaPods absents. | Installation/config Xcode (machine/utilisateur). DMG/signature/notarisation **après** build réel. |
| SQLCipher (cible brief) | **Non utilisé** dans `tena_app` ; chiffrement applicatif AES-GCM. | Plan de migration détaillé + validation avant implémentation (clés, compat backups, perf, tests). |
| Centimes natifs transactions | `Transaction.amount` `double`, `transactions.amount REAL` (valeur chiffrée). Budgets/goals déjà orientés centimes. | Migration transverse avec plan validé (modèle, DB, services, UI, CSV, backup, tests). |
| Isolation tests DB FFI | Échecs combinés dus au partage `sqflite_common_ffi`/keystore/état. | **Partiellement corrigé LOT 2.1** (DB temp isolée + keystore stable sur suites critiques). Étendre aux suites restantes au besoin (LOT 4). |
| Tests non critiques | `preferences_services_test` (erreur type SharedPreferences), `widget_test` (contexte app/assets natifs en test). | Investiguer séparément ; ne pas masquer. |
| Banking/paiement/sync/auth déployée | Mocks/non vérifiés selon brief. | Ne jamais présenter comme réels. |

## 6. État tests (LOT 2.1)
**Avant (baseline audit, DB FFI nettoyée)** : `flutter test --no-pub` complet → **123 pass, 31 fail** (dont DB/crypto/backup et effets d’isolation/env).

**Après stabilisation déterministe (suites ciblées, exécutées réellement)** :
- `database_service_test` : **18/18 pass** (DB temp isolée par test, keystore stable).
- `backup_service_test` : **21/21 pass** (DB temp isolée + crypto stable).
- `crypto_service_test` : **8/8 pass** (contrat clé persistée après usage ; montant illisible lève erreur explicite, pas de zéro silencieux).
- `csv_edge_cases_test` : **11/11 pass** (isolation).
- `import_service_test` : **7/7 pass**.
- `import_pipeline_test` : **13/13 pass** (isolation).
- `finance_service_test` : **20/20 pass** (isolation + assertion alignée sur chiffrement réel des catégories).
- `analysis_services_test` : **26/26 pass** (vérifié dans run combiné).

**Suite complète après changements (même machine, `flutter test --no-pub`)** : **152 pass, 2 fail** — `test/services/preferences_services_test.dart` (“CategoryService les valeurs par défaut sont persistées”, cast `SharedPreferences.getStringList`) et `test/widget_test.dart` (démarrage app ; sensible aux assets natifs/`flutter pub get`/contexte). Ces 2 échecs ne sont pas introduits par LOT 2.1 et ne concernent pas le socle CSV/DB/crypto/backup corrigé.

**`flutter analyze --no-pub` (global)** : **62 issues, 0 error**. Fichiers modifiés LOT 2.1 analysés : `database_service.dart` (2 infos mineures), `crypto_service.dart` (0), tests modifiés (0/warnings existants hors scope).

## 7. Modifications LOT 2.1 (réelles, non destructives)
- `tena_app/lib/services/database_service.dart` : hooks test-only `testDatabasePath` + `resetAndDeleteTestDatabase()` (aucun impact prod) ; correction **réelle** bugs de lecture budget (`getGlobalBudget` `whereArgs` global, `getCategoryBudget` requête par `id` car `category` chiffrée, `_budgetFromRow` gère `category` null).
- `tena_app/lib/services/crypto_service.dart` : `decryptNumber` lève une erreur explicite sur montant en clair illisible (évite zéro silencieux) — comportement plus sûr.
- `tena_app/test/services/database_service_test.dart` : isolation DB temp + `tearDown` + keystore/key reset.
- `tena_app/test/services/backup_service_test.dart` : isolation DB temp + keystore/key reset.
- `tena_app/test/services/crypto_service_test.dart` : assertion “clé persistée” alignée sur génération lazy à l’usage (comportement réel), contrat de sécurité préservé.
- `tena_app/test/services/import_pipeline_test.dart`, `csv_edge_cases_test.dart`, `finance_service_test.dart` : isolation DB temp/keystore ; assertion finance alignée sur catégories chiffrées au repos (API `getTransactions()` reste source de vérité pour regroupement).
- `docs/AUDIT_LOT1_CARTOGRAPHIE.md` : créé.

**Non touchés** : les **13 fichiers `.backup*`** (vérifiés présents). Aucun commit/push.

## 8. Préparation Mac (config vérifiée)
- `tena_app/pubspec.yaml` : `name: tena_budget`, `version: 1.0.0+1`, `publish_to: none`. Description à professionnaliser.
- macOS `AppInfo.xcconfig` : `PRODUCT_NAME=tena_budget`, `PRODUCT_BUNDLE_IDENTIFIER=fr.tena.tenaBudget`, copyright 2026.
- macOS `Info.plist` : display name `TENΛ Budget`, version/build depuis Flutter.
- Icônes `macos/Runner/Assets.xcassets/AppIcon.appiconset` présentes (tailles standards) — qualité/design à valider pour produit premium.
- **Build/distribution** : nécessite Xcode complet + CocoaPods. Procédure (à exécuter après installation) : `flutter pub get` → `flutter build macos --release` → créer DMG (outil à choisir) → signature Developer ID + notarisation Apple (`notarytool`) → vérifier artefact/Gatekeeper. **Non exécutable ici** (Xcode absent).

## 9. Backlog priorisé (prochaines briques Mac premium, réutilisation max)
1. **Stabiliser totalement la baseline** : traiter `preferences_services_test`/`widget_test` (env/assets), étendre isolation aux suites DB restantes si combinées ; garder tests verts.
2. **Shell Mac natif/premium** : navigation latérale repliable, barre actions rapides, recherche globale, raccourcis, menus contextuels, dark/light, états vides/chargement/erreurs (réutiliser `theme/widgets/pages`).
3. **Socle financier fiable** : revue comptes/transactions/budgets/goals/catégories UX + calculs, suppression confirmations, filtres, tableaux, cohérence visuelle.
4. **Sauvegardes produit** : UI export/import chiffré, prévisualisation validation, compat version/schéma, aucun écrasement silencieux, rapport clair.
5. **Calendrier/abonnements/échéances** (local).
6. **Factures/documents/OCR local** (après choix libs compatibles/licences) + coffre documentaire.
7. **Stats/prévisions/patrimoine/rapports** avancés sur données réelles.
8. **Automatisations locales** (règles explicites).
9. **IA locale optionnelle** (modèle léger, mesure perf M2 16 Go, licences).
10. **Migration centimes/SQLCipher** uniquement avec plans détaillés validés.
11. **Packaging Mac** (Xcode installé) : release, DMG, signature/notarisation, doc install.
12. **iPhone** puis **site public HTTPS** distinct.

## 10. Prochaine étape concrète (recommandée)
- Corriger de façon ciblée `test/widget_test.dart` et `test/services/preferences_services_test.dart` (diagnostic + fix minimal, sans casser contrats), puis relancer la **suite complète** jusqu’à baseline verte ou résidus explicitement non liés.
- Démarrer la brique **shell/navigation Mac** dans `tena_app` (layout, sidebar, routes, actions rapides) en réutilisant pages/services existants.
