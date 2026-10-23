# TENΛ Budget — préparation commerciale

État de travail vérifié sur la branche `gpt6/transfer-finance-safety-2026-10-23`, le 23 octobre 2026. Ce document complète le brief produit; il ne certifie ni une mise en production ni une offre déjà vendue.

## Éléments confirmés dans le code

- Le questionnaire produit un profil local et le Core sait chiffrer les données du coffre navigateur. Les tests Core du coffre et du questionnaire passent dans l’environnement de développement utilisé pour cette vérification.
- Le parcours personnel Web lit des transactions, budgets et objectifs depuis le stockage local IndexedDB; les pages famille et import indiquent les limites au lieu de simuler une activité.
- Cette branche permet de télécharger un fichier de sauvegarde chiffré contenant les transactions, budgets, objectifs, versements et profil disponibles, puis de le restaurer dans IndexedDB après déchiffrement, contrôle d’intégrité et vérification des conflits. Les tests d’intégration de ce flux passent; les contenus qui ne sont pas représentables dans le stockage Web sont refusés.
- Cette branche permet des exports CSV locaux pour les transactions et les budgets. Les exports Excel et PDF ne sont pas actifs.
- Aucune connexion bancaire réelle, aucun paiement récurrent et aucun abonnement actif n’ont été vérifiés. Les offres affichées par le Core restent des projections non lancées et sans prix configuré.
- La compilation Web a réussi après génération locale du client Prisma. Cela ne prouve ni qu’une base distante est configurée, ni que l’authentification ou un déploiement fonctionnent en production.

## Première version commercialisable — ordre recommandé

1. Stabiliser le parcours personnel de bout en bout : questionnaire, coffre, transactions, budgets et objectifs, avec reprise après rechargement et états d’erreur compréhensibles.
2. Terminer la restauration de sauvegarde sans écrasement silencieux; vérifier les doublons, l’intégrité du fichier, la compatibilité des versions et les erreurs interrompues.
3. Finir l’import CSV/XLSX avec aperçu, validation des colonnes, détection des doublons et confirmation avant écriture; ne pas présenter le moteur d’analyse seul comme une fonction d’import terminée.
4. Vérifier l’accessibilité clavier et lecteur d’écran, les formats de date/montant, les migrations et la récupération après fermeture inattendue.
5. Préparer support, politique de confidentialité, conditions de vente, procédure de sauvegarde et canal de signalement avant d’accepter des données financières de clients.
6. Décider ensuite si une synchronisation multi-appareil ou une connexion bancaire est nécessaire à la première vente. Ces fonctions introduisent des coûts, des obligations et des risques distincts; elles ne doivent pas être promises avant sélection et vérification des prestataires.

## Peut attendre après la première version

- Partage familial et rôles avancés; version entreprise.
- Connexion bancaire réelle, paiement intégré et automatisations nécessitant des services distants.
- Assistant IA, comparateur et recommandations d’économies tant que la qualité, le consentement, les coûts et la valeur réelle ne sont pas démontrés.
- Exports PDF et Excel, si CSV couvre les besoins des premiers utilisateurs.

## Coûts et dépendances à chiffrer

**Constat :** le parcours local de base ne nécessite pas de serveur central pour conserver les données sur l’appareil. Le code et la compilation seuls ne permettent pas de conclure que l’hébergement, les noms de domaine, la distribution, le support ou les services de compte sont gratuits.

**À chiffrer avant engagement :** domaines et hébergement du site, distribution et signature des applications, service d’envoi de liens e-mail si retenu, base et hébergement si l’authentification multi-appareil est activée, partenaire bancaire et frais par compte/opération, paiement et remboursements, support, conformité et conseil juridique. Les tarifs dépendent des fournisseurs et du volume; aucun tarif fournisseur n’est établi ici.

**Règle de marge à documenter pour chaque offre :** revenu net encaissé − frais de paiement − coûts variables par utilisateur (banque, e-mail, stockage/synchronisation, assistance) − taxes/remboursements. Ajouter les coûts fixes mensuels répartis sur le nombre d’abonnés payants. Ne pas activer une offre payante avant d’avoir des coûts observés et une marge cible validée.

## Hypothèses commerciales — à ne pas traiter comme des faits

- **Différenciation possible :** confidentialité compréhensible, usage hors ligne et contrôle local des finances. Cela peut attirer des personnes réticentes à centraliser leurs données, mais l’avantage et la confiance doivent être testés.
- **Piste d’offre :** garder la gestion personnelle de base utile sans compte distant obligatoire; évaluer séparément une offre payante pour des services récurrents réellement coûteux ou utiles. Aucun niveau, tarif ou verrouillage de fonctionnalité n’est approuvé par cette hypothèse.
- **Prix et marge :** aucune fourchette fiable n’est disponible dans les fichiers consultés. Fixer un prix après entretiens, test de compréhension des offres et chiffrage fournisseur; comparer le revenu net à un scénario d’usage prudent, moyen et élevé.

## Validation proposée avant dépenses importantes

- Réaliser 8 à 12 entretiens exploratoires avec des personnes correspondant au public personnel ciblé; vérifier leurs outils actuels, leurs inquiétudes de confidentialité et leur volonté de payer, sans leur suggérer la réponse.
- Observer 5 personnes utilisant le parcours local : créer le profil, saisir une transaction, retrouver un budget, exporter le CSV et comprendre la sauvegarde/restauration.
- Tester séparément les formulations « données locales », « sauvegarde chiffrée » et les limites actuelles; vérifier que les participants ne comprennent pas à tort qu’une banque, une restauration ou un paiement est déjà connecté.
- Présenter plusieurs hypothèses de prix seulement après avoir calculé les coûts variables; mesurer l’intention d’achat comme un signal exploratoire, pas comme une prévision de ventes.
- Décider de poursuivre si les personnes terminent les tâches sans aide, comprennent où résident leurs données et demandent spontanément une fonction payante assez précise pour couvrir son coût.

## Prochaine priorité

Raccorder l’aperçu et la validation du moteur d’import CSV/XLSX au stockage local, avec tests de doublons et d’annulation avant écriture. C’est le principal écart fonctionnel restant entre les besoins annoncés et une première version personnelle testable.
