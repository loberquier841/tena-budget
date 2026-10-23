# Sauvegardes locales TENΛ Budget (Web)

## Données incluses

Le fichier chiffré version `2.0` contient, pour l’espace local choisi :

- toutes les transactions, y compris les transactions supprimées logiquement et leur date de mise à la corbeille;
- tous les budgets;
- les objectifs actifs et supprimés, avec leurs versements associés;
- le profil terminé ou, à défaut, la progression locale inachevée du questionnaire;
- les références `categoryId` et `personId` présentes dans les transactions et budgets.

Les lignes financières sont chiffrées au repos dans IndexedDB avec le coffre local. L’export est ensuite chiffré séparément avec AES-GCM et un mot de passe de sauvegarde. L’application ne reçoit ni ne conserve ce mot de passe de sauvegarde.

Le fichier externe protège le contenu JSON, mais garde ses métadonnées de transport (version, date de création et `familyId`) visibles pour permettre la validation du fichier avant déchiffrement.

## Données absentes et raison

Le schéma Dexie Web ne contient pas de tables de catégories, de personnes, de règles récurrentes ou d’historique de génération. La page famille n’implémente pas le partage. La page récurrentes présente des exemples codés en dur. Les IDs de catégorie/personne ne sont que des références facultatives sur les lignes financières; les noms de catégories ou personnes ne sont pas enregistrés comme entités à part.

La file de synchronisation et les journaux de conflits ne sont pas exportés. Lors d’une restauration, les opérations locales en attente sont reconstruites pour les lignes financières ajoutées; les anciens journaux, compteurs d’essais et conflits ne sont pas repris. Le coffre, sa clé, sa phrase secrète et les métadonnées permettant de déverrouiller l’appareil ne sont jamais inclus. L’import de la sauvegarde ajoute des lignes et n’écrase pas les données existantes; les collisions d’ID bloquent la restauration.

Si une sauvegarde (notamment un fichier créé par un autre client) contient des catégories, personnes ou règles récurrentes, la Web app la refuse avant toute écriture. Elle ne supprime pas ces éléments silencieusement. Les éléments absents d’un fichier ancien ne peuvent pas être reconstruits.

## Compatibilité et récupération

La restauration accepte les sauvegardes `2.0`. Les champs facultatifs historiques, comme `savingContributions` et `userProfile`, restent facultatifs. Les versions inconnues ou les données qui ne peuvent pas être restaurées intégralement sont refusées avant l’ouverture de la transaction d’écriture.

Les anciennes sauvegardes `2.0` ont pu exclure les éléments supprimés logiquement ou la progression inachevée du questionnaire; aucune restauration ne peut recréer ces éléments s’ils ne figurent pas dans le fichier. Une nouvelle sauvegarde les inclut désormais.

La phrase du coffre local ne peut pas être récupérée à partir de ses données chiffrées. En revanche, une sauvegarde externe peut être restaurée dans un nouveau coffre avec une nouvelle phrase locale, à condition de disposer du fichier et de son mot de passe distinct. Sans sauvegarde déchiffrable, les données qui n’existent que dans un coffre verrouillé restent irrécupérables.
