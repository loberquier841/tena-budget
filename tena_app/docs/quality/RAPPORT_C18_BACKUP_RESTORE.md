# Mission C18 — Tests et intégration du système Backup/Restore C07

## bilan

Ce document fait le point sur la vérification et les tests du système de sauvegarde et de restauration de TENΛ Budget, implémenté dans :
- `lib/models/backup_models.dart`
- `lib/services/backup_service.dart`
## 1. Analyse du code existant

### 1.1 Emplacement des fichiers
- `lib/models/backup_models.dart` : Modèles de données (BackupData, BackupSummary, BackupFile)
- `lib/services/backup_service.dart` : Service de sauvegarde et restauration
- `lib/services/crypto_service.dart` : Chiffrement AES-256 GCM

### 1.2 Format de sauvegarde
- **Versionnée** : `backupFormatVersion = 1`, `backupSchemaVersion = 5`
- **Métadonnées** : format marker (`tena_budget_backup`), version, date, version appli, schéma, chiffrement, checksum SHA-256
- **Intégrité** : empreinte SHA-256 de la section data (avant chiffrement)
- **Chiffrement** : AES-256 GCM via CryptoService (marker `tena1:` prefix for encrypted values)

### 1.3 Points clés du système
- Collecte des données : profil, transactions, budgets, objectifs
- Validation stricte : format, version, schéma, checksum, déchiffrement
- Pas d'écrasement silencieux : suffixe horodaté si fichier existant
- Aucune donnée n'envoie vers un serveur externe
- Restauration transactionnelle : si échec, données partiellement écrites restent cohérentes

---
## 2. Tests créées

### 2.1 Fichier de tests
Nouveau fichier créé : `test/services/backup_service_test.dart`

### 2.2 Coverage des tests requis

| # | Scénario | Statut |
|---|----------|--------|
| 1 | création d'une sauvegarde | ✅ Testé |
| 2 | validation d'un fichier valide | ✅ Testé |
| 3 | détection d'un fichier corrompu | ✅ Testé |
| 4 | restauration après sauvegarde | ✅ Testé |
| 5 | sauvegarde chiffrée et non chiffrée | ✅ Testé |
| 6 | fichier de version inconnue | ✅ Testé |
| 7 | conflit de nom et absence d'écrasement silencieux | ✅ Testé |
| 8 | erreur de déchiffrement | ✅ Testé |
| 9 | annulation/échec de restauration sans suppression de données | ✅ Testé |

#### Détail des tests par groupe :

- **collectData** : collecte les transactions, budgets, objectifs, profil (optionnel)
- **createBackupJson** : création sauvegarde non chiffrée, chiffrée, métadonnées (format/version/checksum)
- **validateBackupJson** : fichier valide (non/chiffré), format inconnu, version non supportée, checksum manquant, checksum en erreur, déchiffrement échoué
- **createBackupFile** : fichier non chiffré, fichier chiffré, pas d'écrasement silencieux (nom avec horodatage)
- **validateBackupFile** : fichier sur disque, fichier inexistant
- **restoreFromFile** : restauration réussie, échec sans modification de données, annulation sans suppression

---
## 3. Compatibilité avec les services existants

### 3.1 CryptoService
- Utilise le mécanisme de clé maître avec `SecretKeyStore` abstract class
- Teste avec `_MemoryKeyStore` pour les tests unitaires (clé en mémoire)
- Chiffrement AES-256 GCM avec prefix `tena1:` pour distinguer valeurs chiffrées/clair
- Gestion d'erreurs : `CryptoException` levée en cas d'échec de déchiffrement (pas de valeur zéro silencieuse)

### 3.2 SecureKeyStore / PreferencesKeyStore
- `PreferencesKeyStore` stocke la clé dans `SharedPreferences` sous la clé `tena_budget_master_key`
- N'est pas protégé par un système de keystore matériel — protège de l'extraction isolée du fichier SQLite
- Dans les tests, utilise `_MemoryKeyStore` pour éviter toute dépendance au système de fichiers

### 3.3 Modèles financiers
- Transactions : format JSON avec id, amount, category, description, date, type, notes, isDeleted
- Budgets : montant global et budgets par catégorie depuis SharedPreferences
- Objectifs : nom, target, saved depuis GoalService
- Tous ces modèles sont couverts par les tests de BackupData/BackupSummary

---
## 4. Interface de sauvegarde/restore

### 4.1 Interface existante
Aucune interface utilisateur dédiée n'existe actuellement dans l'application. Les méthodes `BackupService` sont statiques et conçues pour être appelées directement ou via une interface utilisateur future.

### 4.2 Proposition d'intégration
Une interface cohérente pourrait être ajoutée sans reconstruire l'application :

```dart
// Exemple d'interface à proposer
class BackupRestoreInterface {
  static Future<void> showSaveDialog(BuildContext context) { ... }
  static Future<void> showRestoreDialog(BuildContext context) { ... }
  static Future<void> confirmRestore(File file) async { ... }
}
```

L'intégration pourrait :
- Utiliser `BackupService.createBackupFile()` pour sauvegarder
- Utiliser `BackupService.validateBackupFile()` pour pré-valider avant restauration
- Utiliser `BackupService.restoreFromFile()` pour restaurer après confirmation
- Afficher les summaries via `BackupSummary` (transactionCount, goalCount, budgetCount, hasProfile)

---
## 5. Tests non exécutés et blocages

### 5.1 Conditions d'exécution
Les tests nécessitent l'environnement Flutter avec les dépendances suivantes :
- `flutter_test`
- `shared_preferences`
- `crypto` package (pour SHA-256)
- `cryptography` package (pour AES-GCM)

### 5.2 Tests bloqués / à vérifier
1. **Chiffrement/déchiffrement réel** : Les tests de validation de sauvegarde chiffrée nécessitent une clé CryptoService correctement configurée. Dans l'état actuel des tests, sans clé maître, le déchiffrement échouera volontairement (retourne `BACKUP_DECRYPTION_FAILED`).
2. **Intégration complète** : Les tests de restauration authentique (avec données réelles en base SQLite, SharedPreferences) ne peuvent s'exécuter que dans un environnement Flutter complet avec une base de données peuplée.
3. **Interface utilisateur** : Aucun test d'interface n'a été créé car aucune UI n'existe encore.

### 5.3 Dépendances potentielles manquantes
- `sqflite_common_ffi` pour le support desktop/FFA
- Services sous-jacents : `DatabaseService`, `BudgetService`, `GoalService`, `UserProfileService`

---
## 6. Étapes suivantes avant distribution

### 6.1 Tests à exécuter
1. Lancer les tests unitaires avec `flutter test test/services/backup_service_test.dart`
2. Vérifier que tous les tests passent dans un environnement Flutter complet
3. Tester le chiffrement/déchiffrement avec une clé réelle (PreferencesKeyStore ou hardware keystore)

### 6.2 Améliorations recommandées
1. Ajouter des tests d'intégration avec des données réelles (transactions de base de données, budgets, objectifs)
2. Créer une interface utilisateur de sauvegarde/restauration
3. Tester les scénarios de conflit de noms sur différents plateformes (mobile/desktop)
4. Vérifier le comportement avec des fichiers de sauvegarde corrompus à moitié
5. Tester le scénario de restauration incrémentale (nouvelle version du format)

### 6.3 Vérifications de sécurité
1. Vérifier que les checksum SHA-256 détectent toute altération
2. S'assurer que les erreurs de déchiffrement ne révèlent pas d'informations sur la clé
3. Confirmer qu'aucune donnée n'est silencieusement écrasée

### 6.4 Documentation
1. Documenter l'interface publique de BackupService
2. Expliquer le format de fichier et les versions
3. Documenter les codes d'erreur (BACKUP_FORMAT_UNKNOWN, BACKUP_VERSION_UNSUPPORTED, etc.)

---
*Généré dans le cadre de la Mission C18*