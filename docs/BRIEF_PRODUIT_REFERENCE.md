# TENΛ Budget — brief produit de référence

Ce document est la référence produit actuelle. Il remplace les priorités et hypothèses contradictoires des anciennes roadmaps. Les anciennes étapes restent utiles comme inventaire technique, mais un élément indiqué comme « préparé » n'est pas pour autant fonctionnel, déployé ou vérifié.

## Produit et publics

TENΛ Budget est un produit commercial de gestion financière personnelle, avec une version personnelle prioritaire. Il doit aider à comprendre l'argent disponible, suivre revenus et dépenses, budgets et objectifs, connecter les banques avec consentement, prévoir et simuler, alerter, analyser, exporter et sauvegarder/restaurer les données, avec TENΛ AI comme assistant. L'expérience personnelle doit s'adapter aux besoins établis par un questionnaire d'accueil.

La version famille (membres, permissions, dépenses privées et communes) vient après une version personnelle solide. La version entreprise vient ensuite. Ces segments ne justifient pas de fabriquer des écrans sans fonctions réelles.

## Périmètre et phases du produit

La priorité est de construire le vrai TENΛ Budget personnel, complet et durable, pour Web, Android, iOS, Windows, macOS et Linux avec autant de logique partagée que possible. Le budget de base, les transactions locales, les objectifs, l'import/export disponible, les sauvegardes et les fonctions hors ligne ne doivent pas dépendre d'un gros serveur central. La banque réelle, la vérification e-mail, le paiement et la synchronisation entre appareils peuvent nécessiter des services dédiés; leurs dépendances doivent être nommées et vérifiées.

Le produit doit pouvoir distinguer les offres Free, Plus, Pro, Premium, Premium+, Famille, puis Entreprise, avec des capacités et limites réelles. Le questionnaire doit contribuer au choix d'une offre adaptée; les offres ne doivent pas être de simples écrans ou verrous artificiels.

Inventaire fonctionnel cible à couvrir : questionnaire, profil, personnalisation, dashboard, compte, banques, transactions, budgets, revenus/dépenses, catégories, objectifs/épargne, prévisions, simulations, notifications/alertes, import Excel/CSV, export Excel/CSV, rapports, documents, sauvegarde/restauration, coffre local, sécurité, offline, synchronisation, TENΛ AI, comparateur, aide aux économies, abonnements, paiement, famille puis entreprise. Toute capacité restante dans le code ou la documentation doit aussi être inventoriée avant d'être déclarée terminée.

Ordre stratégique : (1) TENΛ Budget personnel complet et local-first, (2) capacités réelles des offres, (3) commercialisation et amélioration du produit, (4) automatisation et IA progressivement, (5) projet TENΛ AI plus ambitieux, (6) version entreprise étendue. Ne pas détourner la priorité actuelle vers une grande plateforme IA ou entreprise.

Les mocks sont réservés aux tests ou environnements explicitement identifiés. Si une fonction n'existe pas encore, l'interface doit le dire clairement au lieu de simuler une transaction, une banque, un paiement ou un abonnement.

## Exigence d'identification et d'accès

- L'accès utilisateur doit inclure un lien envoyé par e-mail.
- L'identifiant utilisé dans le parcours doit être un code.
- Un code de démarrage doit accompagner l'activation initiale; il ne doit pas être redemandé à chaque ouverture ou visite. Le moment où il est requis de nouveau (nouvel appareil, déconnexion ou récupération) devra être défini dans le parcours.
- Cette exigence est enregistrée pour la checklist produit. Le format et le cycle de vie du code (code d'accès, code à usage unique, lien contenant un code, durée/renouvellement) restent à préciser lors de la conception du parcours; aucun comportement n'est présumé ni implémenté sur cette seule formulation.

## Produit final et plateformes

- Site officiel en `.com` : présentation, fonctionnalités, offres, inscription/connexion et téléchargements.
- Site distinct en `.com` pour l'application web personnelle complète.
- Applications Android, iOS, Windows, macOS et Linux, avec une page officielle de téléchargement lorsque les stores ne sont pas utilisés.
- Linux est l'environnement de développement actuel. Android peut être construit/testé ici si les outils sont disponibles. iOS/macOS exigent un environnement Apple pour leur compilation et signature; Windows doit être vérifié sous Windows.

Les domaines, comptes marchands, déploiements et téléchargements publics ne sont pas réputés exister tant qu'ils ne sont pas réellement configurés et vérifiés.

## Architecture et données

- Priorité au fonctionnement local et hors connexion, avec conservation des données personnelles sur l'appareil, sauvegardes chiffrées contrôlées par la personne et validation explicite des actions financières sensibles.
- Réutiliser le Core métier et ses règles de permissions, montants en centimes, déduplication et validation. Éviter de créer des produits indépendants par plateforme.
- Le dépôt contient déjà un Core TypeScript partagé entre le Web et l'application React/Vite, une application Electron qui réutilise cette interface, et un client Flutter avec sa propre logique et son stockage SQLite. Cette duplication Flutter/TypeScript est un écart à réduire prudemment; ne pas réécrire les applications sans migration démontrée.
- L'application Web React/Vite utilise Dexie/IndexedDB; le client Flutter utilise SQLite et un service de chiffrement local. Leur niveau de protection et leurs formats ne sont pas encore uniformes. Ne pas annoncer que toutes les données locales sont chiffrées de bout en bout.
- Un service distant minimal peut être nécessaire pour l'authentification multi-appareil, les retours de consentement bancaire et la vérification des paiements. Il doit rester limité aux secrets et opérations qui ne peuvent pas être sûrs dans le client. Pas de serveur central obligatoire pour consulter et gérer les données locales hors ligne. Synchronisation multi-appareil et compte distant sont des fonctions réseau, et ne peuvent pas être garanties « sans serveur ».

## Banque et paiement : état vérifié

Le dépôt ne contient actuellement qu'une interface et des fournisseurs bancaires mock. `createBankAdapter()` retombe sur un mock si un identifiant non pris en charge est demandé. Aucun fournisseur réel, identifiant marchand, secret ou flux bancaire vérifié n'est configuré. Aucun écran ne doit laisser croire à une connexion bancaire réelle.

La cible est une connexion en lecture seule, autorisée par la personne, récupérant les comptes et transactions réels, avec synchronisation selon les limites du fournisseur, détection des nouveautés et déduplication, conservation locale chiffrée et révocation possible. Les opérations sensibles restent soumises à confirmation. « À jour » ne signifie pas un flux bancaire instantané : la fréquence dépend des banques et du fournisseur.

Pour le lancement commercial en France, l'accès professionnel aux données de compte relève du régime des services d'information sur les comptes. La voie à évaluer en premier est un fournisseur dûment autorisé et son parcours de consentement; le statut réglementaire et les contrats requis doivent être confirmés avant d'activer cette fonction. Voir [ACPR — statut PSIC/AISP](https://acpr.banque-france.fr/fr/professionnels/lacpr-vous-accompagne/banque/creer-ma-societe/mes-procedures/etablissement-de-paiement-et-prestataire-de-service-dinformation-sur-les-comptes) et [ACPR — accès aux API bancaires](https://acpr.banque-france.fr/fr/professionnels/lacpr-vous-accompagne/parcours-fintech/contenus-pedagogiques/de-quel-statut-releve-mon-activite/jaccede-aux-api-des-banques-jinitie-des-ordres-pour-le-compte-de-mes-clients).

Iyzico n'est pas un paiement actif vérifié. Aucun abonnement ne doit être débloqué par une déclaration locale « payé » : l'état Premium doit provenir d'une vérification fiable côté serveur auprès du prestataire, sans clés dans le client. Ne pas inventer d'URL ou de clé.

## État réel observé dans le dépôt

- Le monorepo contient `packages/core`, `packages/db`, `packages/banking`, `packages/import-engine`, `packages/shared`, `packages/ui`, `apps/mobile`, `apps/web`, `apps/desktop` et `tena_app`.
- Le client React/Vite local possède les mécanismes Dexie pour transactions, budgets et objectifs, ainsi que des modifications locales de sauvegarde/restauration. La corbeille des transactions est récupérable.
- Plusieurs pages Next.js visibles dans `apps/web/app` affichent encore des valeurs codées en dur; le dashboard, les transactions, budgets et objectifs Web ne constituent pas encore une application commerciale reliée au compte et à la persistance locale.
- L'accueil Web n'est pas encore le site vitrine commercial; inscription et déploiement ne sont pas vérifiés. Le schéma Prisma décrit des modèles et Auth.js gère une partie de la connexion, mais cela ne constitue pas un produit hébergé prêt à vendre.
- `apps/desktop` réutilise l'application React via Electron. Flutter dispose de projets de plateformes natives, mais sa logique métier distincte empêche encore de parler d'un Core commun universel.
- Les pages IA et bancaires doivent être distinguées entre capacités locales réellement exécutées, démos et fonctions futures.

## Inventaire conservé depuis les anciennes étapes et décisions

Ces capacités font partie de la checklist globale, même lorsqu'elles sont partielles, historiques ou non disponibles dans le client actuel :

- Revenus et dépenses, catégories, personnes du foyer, budgets par période et par personne, opérations récurrentes, objectifs et versements.
- Recherche avancée, historique, graphiques et agrégats, prévisions, simulations isolées (les scénarios `sim_` et opérations `simtx_` ne doivent jamais modifier les finances réelles).
- Import CSV/XLSX multi-feuilles avec analyse, détection de doublons, correction, aperçu, validation humaine et rapport d'import; export CSV/Excel/PDF, totaux vérifiés et rapports mensuels/annuels.
- Documents associés, sauvegarde/restauration avec gestion des conflits, corbeille/restauration, coffre local, chiffrement, permissions, audit, export et suppression RGPD.
- File d'attente hors ligne, synchronisation éventuelle, journal de conflits, PWA/service worker, installation locale, notifications, alertes, comparateur de prix, aide aux économies, TENΛ AI et propositions Autopilot avec validation humaine.
- Famille : invitations, rôles owner/admin/member/child, permissions, séparation par famille/personne et gestion des appareils. Ces mécanismes doivent être vérifiés avant de les présenter comme collaboration multi-appareil disponible.
- Accès par lien e-mail et identifiant-code, code initial, gestion des appareils et récupération; l'authentification hébergée n'est pas une condition pour consulter les données locales hors ligne.
- Offres Free, Plus, Pro, Premium, Premium+, Famille et Entreprise; paiement réel vérifié côté serveur seulement. Site officiel `.com`, application Web distincte, page de téléchargement, clients Android/iOS/Windows/macOS/Linux.
- Sécurité : validation d'actions financières sensibles, secrets absents du client, autorisation bancaire révocable, données locales protégées, test de fuite entre espaces, limites clairement expliquées pour XSS/appareil compromis et sauvegarde multi-appareil.

Les anciens tests nommés banking/mock, Beta familiale, RGPD, performance et audit sont conservés comme inventaire Core, mais leurs anciens libellés « PASS » ne certifient ni leur disponibilité utilisateur ni une mise en production.

## Ordre de réalisation de référence

1. Terminer et éprouver la persistance, la sauvegarde/restauration sans écrasement silencieux, et la protection des données locales sur les clients réellement utilisés.
2. Stabiliser une tranche personnelle commune de bout en bout (onboarding adapté, compte local, transactions, budgets, objectifs, exports) et supprimer les données de démonstration des parcours présentés comme fonctionnels.
3. Choisir, après vérification juridique et commerciale, un partenaire bancaire autorisé; concevoir l'adaptateur et son petit relais serveur pour secrets/callbacks avant toute connexion réelle.
4. Rendre l'application web personnelle réellement utilisable puis construire le site officiel et la séparation des domaines, inscription, offres et téléchargements avec une identité cohérente.
5. Vérifier les flux de paiement Iyzico côté serveur avant tout accès Premium payant.
6. Réduire progressivement la divergence entre Flutter et Core partagé; valider la compilation et la distribution sur chaque plateforme dans son environnement requis.
7. Développer famille et entreprise après validation de la version personnelle.

La fondation du coffre IndexedDB a été vérifiée en octobre 2026 sur une fixture isolée contenant transactions, budgets, objectifs et versements : migration interrompue/reprise, verrouillage/déverrouillage, sauvegarde avant migration, restauration et contrôle des doublons. Aucun profil réel n'a été touché. Le coffre chiffre au repos les données financières et copies de synchronisation; la clé dérivée de la phrase secrète reste en mémoire pendant la session. Une phrase oubliée sans sauvegarde implique que TENΛ ne peut pas déchiffrer les données. Le chiffrement navigateur ne protège pas contre du JavaScript malveillant/XSS, un appareil compromis ou une personne qui connaît la phrase. Les identifiants de ligne et `familyId` restent visibles dans IndexedDB.

La tranche utilisateur active devient le questionnaire → profil local chiffré → personnalisation du tableau de bord avec états explicites selon les données disponibles. Le Core TypeScript est la source du schéma et des règles pour React/Vite/Electron/Web compatible; Flutter conserve un stockage SQLite distinct, à aligner sans prétendre qu'il partage déjà l'exécution du Core.
