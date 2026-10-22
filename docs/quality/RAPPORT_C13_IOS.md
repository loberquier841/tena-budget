# Rapport C13 — Audit iOS, interface mobile et protection du dépôt

**Projet** : TENΛ Budget
**Agent précédeant** : C12 (a préparé l'interface iOS avec Capacitor)
**Date** : 2026-10-22

---

## 1. Modifications locales et rapport C12

- L'agent C12 a apporté 734 modifications dans `apps/mobile/src/App.tsx` dans le but de construire le profil local-first onboarding et le coffre de migration chiffré.
- Aucun fichier n'a été supprimé, notamment aucun fichier `.backup`.
- Les changements concernent principalement :
  - Création du système de vault local avec migration
  - Gestion du profil utilisateur et de l'onboarding (5 étapes)
  - Stockage local des budgets, objectifs, transactions avec Dexie (IndexedDB)
  - Sauvegarde et restauration chiffrées
  - Moteur de permissions intégré
- Le dépôt git montre un historique propre depuis C01 jusqu'à cc742ba (C12).

---
## 2. Vérification de `apps/mobile/capacitor.config.json`, scripts et versions de Capacitor

| Élément | Valeur | Statut |
|---|---|---|
| `appId` | `fr.tena.budget` | ✅ Correspondance attendue |
| `appName` | `TENΛ Budget` | ✅ Correspondance attendue |
| `webDir` | `dist` | ✅ Standard Capacitor |
| `bundledWebRuntime` | `false` | ✅ Utilisation du runtime natif |

**package.json mobile** :
- `@capacitor/ios`: `8.5.2`
- Dependencies : `@tena/core`, `@tena/shared`, `@tena/banking`, `dexie@^4.0.11`, `react@^18.3.1`, `react-dom@^18.3.1`
- Scripts : `dev`, `build`, `preview` (Vite-based, pas de CLI Capacitor directe dans package.json)

**Capacitor CLI** : Non vérifié directement, mais la présence de `ios/` suggère que `npx cap add ios` a été exécuté à un moment donné.

---
## 3. Dossier iOS — fichiers attendus et configuration

### Structure du dossier `apps/mobile/ios/`

```
ios/
  App/
    AppDelegate.swift
    Info.plist
    Main.storyboard
    Base.lproj
    capacitor.config.json (dans App/)
    config.xml
    App.xcodeproj/
    capacitor-cordova-ios-plugins/
    CapApp-SPM/
```

### Fichiers attendus vs présents

| Fichier | Statut | Commentaire |
|---|---|---|
| `Info.plist` | ✅ Présent | Voir analyse ci-dessous |
| `AppDelegate.swift` | ✅ Présent | Délegate Capacitor standard |
| `Main.storyboard` | ✅ Présent | Écran de lancement |
| `Base.lproj` | ✅ Présent | Ressources de localisation |
| `capacitor.config.json` | ⚠️ Présent (dans App/) | Config Capacitor pour sous-module |
| `config.xml` | ✅ Présent | Ancienne config Cordova, peut être redondant |
| `App.xcodeproj/` | ⚠️ Présent | Projet Xcode minimal, nécessite `npx cap sync` |
| `DerivedData/` | ❌ Absent | Non généré (pas de build) |
| `Pods/` | ❌ Absent | Non généré (pas de `pod install`) |

### Analyse de `Info.plist`

- `CFBundleDisplayName` : `TENΛ Budget` ✅ (cohérent avec `capacitor.config.json`)
- `CFBundleIdentifier` : `$(PRODUCT_BUNDLE_IDENTIFIER)` → Doit être défini sur `fr.tena.budget` dans Xcode
- `LSRequiresIPhoneOS` : `true` ⚠️ → Restreint l'application aux iPhones uniquement (pas de support iPad via ce flag)
- `UIRequiredDeviceCapabilities` : `armv7` ⚠️ → Capabilité ancienne; bloque l'installation sur les appareils modernes (iPhone 5s+/iPad Air+). Doit être mis à jour pour inclure `arm64`.
- `UISupportedInterfaceOrientations` : Portrait + Landscape Left + Landscape Right ✅
- `UISupportedInterfaceOrientations~ipad` : Toutes les orientations ✅

### Conclusion du dossier iOS

- La structure de base est en place mais **incomplète**.
- Il manque l'exécution de `npx cap sync` pour synchroniser la configuration Capacitor avec le projet Xcode.
- Le champ `UIRequiredDeviceCapabilities: armv7` est un **blocage technologique** — il empêche l'installation sur tout appareil iOS moderne. Doit être mis à jour pour inclure `arm64`.
- `LSRequiresIPhoneOS: true` peut être intentionnel si le support iPad n'est pas visé, mais il faut s'assurer que l'interface s'adapte correctement.

---
## 4. Examen de `apps/mobile/src/App.tsx` — problèmes mobiles/iPad identifiés

### Points positifs

- La composante est bien structurée avec des fonctions de rendu séparées (`renderHome`, `renderTransactions`, `renderBudget`, etc.)
- Les états vides (`Empty`) ont des messages explicites adaptés au contexte mobile.
- Les styles CSS incluent des requêtes médium adaptatives :
  - `@media (max-width: 900px)` — réduit la sidebar, ajuste la grille
  - `@media (max-width: 600px)` — passe en grille unique, réduit les padding
  - `@media (max-width: 1000px)` — breakpoint intermédiaire

### Problèmes mobiles/iPad clairement identifiés (à corriger sans refaire l'interface)

1. **Largeur de sidebar par défaut** : `.sidebar{width:248px}` leave `main` avec `width:calc(100% - 248px)`. Sur un iPhone en portrait (320px), il reste seulement 72px — **trop étriqué**. La règle `@media (max-width: 900px)` réduit à 76px, ce qui est mieux, mais la transition pourrait être améliorée.

2. **Breakpoint `armv7` dans Info.plist** : Non un problème de code mais de configuration native. Voir section 3.

3. **Requêtes médias manquantes pour les très petits écrans** : La règle `@media (max-width: 600px)` existe mais certaines propriétés ne sont pas optimisées :
   - `.stats` repasse en grille 1 colonne ✅
   - `.homeStats .card` a `min-height:66px` qui peut être serré sur très petits écrans
   - La `.balanceHero` a `min-height:92px` dans la règle 700px — peut masquer du contenu sur iPhone SE

4. **Texte et cibles tactiles** : Certains composants utilisent du texte comme libellé de bouton sans taille de police minimale recommandée pour iOS (11px minimum pour les textes, 44px minimum pour les cibles tactiles). Vérifier les buttons dans les formulaires.

5. **Orientation paysage** : La CSS ne semble pas avoir de règles spécifiques pour l'orientation paysage sur iPad. La grille `.grid2` à 2 colonnes peut ne pas s'adapter optimalement.

6. **Recherche globale `.globalSearch`** : Largeur fixe de 210px qui peut dépasser l'écran sur iPhone en portrait sans zoom horizontal. La règle 900px la cache (`display:none`), ce qui est correct.

7. **État de chargement** : Les composants `Empty` affichent des messages mais la hauteur fixe peut causer défilement inattendu sur très petits écrans.

---
## 5. Navigation, formulaires, questionnaire financier, tableau de bord, états vides sur petits écrans

| Composant | Statut | Preuves / Observations |
|---|---|---|
| **Navigation** | ⚠️ Partiellement vérifié | La navigation par onglets est présente avec 15 sections. La sidebar cachée sous 900px devient un menu hamburger-style. **Besoin de test sur appareil réel** pour vérifier la fluidité et l'accessibilité (VoiceOver). |
| **Formulaires** | ⚠️ Vérifié en partie | Les inputs ont des labels et des `type="password"` appropriés. Les select ont des options. Les tailles de police par défaut sont raisonnables. **Points d'amélioration** : certaines inputs n'ont pas de `min-width` ni de `max-width` contraint, peuvent déborder sur iPhone SE. |
| **Questionnaire financier** | ⚠️ Vérifié | 5 étapes d'onboarding (ménage, revenus, expérience, priorités, profil). Les choix sont présentés avec des boutons `primary`/`ghost`. Les étapes sont indiquées avec une barre de progression. **Tester sur iPhone SE** : la barre d'étape et les choix peuvent être trop serrés verticalement. |
| **Tableau de bord** | ⚠️ Vérifié | L'accueil affiche le solde, les revenus/dépenses, et les graphiques. La grille `.homeStats` repasse en 1 colonne sous 600px. Les graphiques `.chart` ont `height:190px` fixe — peut nécessiter défilement. Les cartes de catégorie utilisent une grille `.categoryRow` qui s'adapte sous 700px. |
| **États vides** | ✅ Correctement implémenté | Chaque section possède des messages `Empty` adaptés : "Aucune transaction enregistrée sur cet appareil", "Pas de budget enregistré pour cette période", "Aucun objectif enregistré", etc. Les messages sont en français et contextuels.

**Note important** : Aucun test réel sur simulateur ou appareil iOS n'a été possible (voir section 8). Tous les statuts ci-dessus sont basés sur lecture statique du code.
## 6. Compatibilité des données et coffre local avec Capacitor

| Aspect | Statut | Observations |
|---|---|---|
| **Stockage local** | ⚠️ Théorique | Utilise Dexie (wrapper IndexedDB). Capacitor stocke les fichiers sous `app/docs/` dans l'espace iOS. **Aucun test d'exécution réel** n'a pu être effectué (voir section 8). |
| **Synchronisation Capacitor** | ⚠️ Non vérifiée | La config `bundledWebRuntime: false` suggère un runtime natif, mais sans build Xcode, on ne peut vérifier la présence des plugins Capacitor (Storage, Filesystem, etc.). |
| **Migration vault** | ✅ Code présent | `createLocalVaultAndMigrate`, `unlockLocalDatabase`, `lockLocalDatabase`, `createLocalBackup`, `restoreLocalBackup` sont implémentés dans `@tena/core`. Le flux de sauvegarde/restauration semble complet. |
| **Permissions d'écriture** | ✅ Vérifié par code | `assertCan(localRole, 'action')` est appelé avant toute écriture locale. Le rôle `owner` a tous les droits. |
| **Compatibilité données → Capacitor** | ⚠️ Non testé | Les données sont stockées localement dans IndexedDB via Dexie. Capacitor pour iOS expose ces données via le webview, mais la persistance à travers les mises à jour de l'app n'a pas été testée. |
| **Avertissement** | ⚠️ Important | *Ne pas prétendre que le stockage a été validé sans test réel.* La seule façon de valider est de builds iOS réel ou d'utiliser un émulateur Android avec Dexie (non couvert ici). |

---
## 7. Permissions iOS — examen et recommandations

### Permissions actuellement déclarées dans `Info.plist`

| Permission | Statut | Commentaire |
|---|---|---|
| `armv7` (device capability) | ❌ Obsolète | Doit être `arm64` pour les appareils modernes. Voir section 3. |
| `UIInterfaceOrientationPortrait` | ✅ Déclaré | |
| `UIInterfaceOrientationLandscapeLeft` | ✅ Déclaré | |
| `UIInterfaceOrientationLandscapeRight` | ✅ Déclaré | |
| **Permissions d'accès matériel** | ❌ Absentes | Aucune des suivantes n'est déclarée :<br> - `NSPhotoLibraryAddUsageDescription`<br> - `NSPhotoLibraryUsageDescription`<br> - `NSCameraUsageDescription`<br> - `NSMotionUsageDescription`<br> - `NSAppleMusicUsageDescription` |
| **Permissions de confidentialité** | ⚠️ Minimales | L'application claims `LSRequiresIPhoneOS: true` et n'a pas d'entitlements de collecte de données étendues. |

### Permissions nécessaires selon les fonctionnalités

| Fonctionnalité | Permission requise | Statut actuel |
|---|---|---|
| **Prise de photo/receipt** | `NSCameraUsageDescription` | ❌ Non déclarée |
| **Enregistrement dans Photos** | `NSPhotoLibraryAddUsageDescription` | ❌ Non déclarée |
| **Accéléromètre/mouvement** | `NSMotionUsageDescription` | ❌ Non déclarée (si features de suivi) |
| **Bibliothèque musicale** | `NSAppleMusicUsageDescription` | ❌ Non déclarée (non pertinent pour ce cas) |
| **Stockage de base / Base de données** | Aucune entitlement spéciale | ✅ Déjà couvert par le sandbox iOS |

### Recommandations

1. **Si aucune caméra/photo n'est utilisée** (apparaît probable pour cette version) : Aucune permission supplémentaire n'est nécessaire. Le sandbox iOS protège déjà le stockage local.

2. **Si des fonctionnalités de caméra/photos doivent être ajoutées plus tard** : Ajouter les clés suivantes dans `Info.plist` (dans la section `<dict>`) :
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Cette application a besoin d'accéder à la caméra pour scanner des reçus et des documents.</string>
   <key>NSPhotoLibraryAddUsageDescription</key>
   <string>Cette application a besoin d'accéder à votre galerie photo pour sauvegarder vos reçus.</string>
   ```

3. **Corriger `UIRequiredDeviceCapabilities`** : Remplacer `armv7` par `arm64` (ou ajouter les deux) pour permettre l'installation sur les appareils modernes.

4. **Considérer `NSUserTrackingUsageDescription`** si jamais l'application intègre le suivi analytics Across apps (non visible dans le code actuel).

---
## 8. Vérifications possibles — blocage Xcode / SDK iOS

### Situation actuelle

- `xcodebuild` est disponible mais point vers `/Library/Developer/CommandLineTools` — **seulement les Command Line Tools**, pas Xcode complet.
- Aucune application Xcode n'est dans `/Applications/` (recherche négative).
- Swift est disponible (`/usr/bin/swift`) mais ne peut pas compiler d'applications iOS sans le SDK.
- `ls /Applications/Xcode*.app` ❌ → Aucun Xcode détecté.

### Conséquences

| Vérification | Résultat | Commentaire |
|---|---|---|
| `npx cap add ios` | ⚠️ Possible | Peut ajouter la structure de projet, mais `npx cap sync` ou `npx cap open ios` échoueront sans Xcode. |
| `npm run build` (Vite) | ✅ Fonctionne | Le build Vite vers `dist/` fonctionne en environnement Node.js. |
| Compilation iOS (.ipa) | ❌ BLOQUÉ | Impossible sans Xcode + iOS SDK. |
| Tests sur simulateur | ❌ BLOQUÉ | Impossible sans Xcode. |
| Vérification réelle du stockage local iOS | ❌ BLOQUÉ | Nécessite un appareil ou simulateur iOS. |
| Vérification des permissions iOS réelles | ❌ BLOQUÉ | Nécessite Xcode ou un simulateur. |

### Documented blocking issue

> **BLOQUANT** : Xcode complet et le SDK iOS ne sont pas installés sur cette machine. Seuls les Command Line Tools sont disponibles (`/Library/Developer/CommandLineTools`). Par conséquent :
> - Aucun build iOS réel n'a pu être exécuté.
> - Aucun test sur simulateur ou appareil réel n'a pu être effectué.
> - Les vérifications de permissions, de stockage Capacitor et de rendu UI sur iOS sont basées sur **analyse statique du code uniquement**.
> - Toute affirmation selon laquelle "l'application iOS a été testée et compile avec succès" serait **fausse** et doit être évitée.

**Solution recommandée** : Installer Xcode depuis l'App Store (`xcode --install` ou depuis https://developer.apple.com/xcode/`), puis exécuter :
```bash
npx cap add ios
npx cap sync
```
Cela générera les fichiers Xcode complets, réglera `Info.plist`, `config.xml` et permettra les builds ultérieurs.

---
## 9. Résumé des statuts

| # | Élément | Statut | Preuves |
|---|---|---|---|
| 1 | Configuration capacitor.config.json | ✅ RÉUSSI | `appId: fr.tena.budget`, `appName: TENΛ Budget`, `webDir: dist` |
| 2 | Structure dossier iOS de base | ⚠️ NON TESTÉ | Fichiers présents mais `npx cap sync` non exécuté ; `armv7` dans Info.plist |
| 3 | CSS responsive mobile/iPad | ⚠️ NON TESTÉ | Media queries présentes ; besoin de test sur appareil réel |
| 4 | Navigation et formulaires mobiles | ⚠️ NON TESTÉ | Analyse statique seulement ; 15 sections de navigation, forms existants |
| 5 | Questionnaire financier / dashboard / états vides | ⚠️ NON TESTÉ | Messages Empty présents ; tailles à vérifier sur iPhone SE |
| 6 | Données / coffre local compatible Capacitor | ⚠️ NON TESTÉ | Code Dexie présent ; pas de test d'exécution iOS |
| 7 | Permissions iOS | ✅ RÉUSSI (analyse) | Pas de permissions matériel nécessaires actuellement ; `armv7` à corriger |
| 8 | Vérifications Xcode / SDK iOS | ❌ BLOQUÉ | Xcode complet introuvable ; compilation iOS impossible |
| 9 | Rapport produit `RAPPORT_C13_IOS.md` | ✅ RÉUSSI | Document généré avec statuts et preuves |

**Statut global** : **BLOQUÉ** (en raison du manque d'Xcode/SDK iOS pour validation réelle), mais les constatations par analyse de code sont complètes et exploitables.
## 10. Preuves documentées

- `/Users/dg/Documents/loïs/TENΛ Budget/apps/mobile/capacitor.config.json` — configuration Capacitor lue et validée
- `/Users/dg/Documents/loïs/TENΛ Budget/apps/mobile/package.json` — dépendances et scripts
- `/Users/dg/Documents/loïs/TENΛ Budget/apps/mobile/ios/App/Info.plist` — configuration iOS lue
- `/Users/dg/Documents/loïs/TENΛ Budget/apps/mobile/src/App.tsx` — composante React lue (864 lignes)
- `/Users/dg/Documents/loïs/TENΛ Budget/apps/mobile/ios/App/App/Info.plist` — configuration détaillée
- `/Users/dg/Documents/loïs/TENΛ Budget/.git/logs/` — historique des commits C01-C12
- Analyse CSS média queries dans App.tsx (lignes 845-859)
- Aucun fichier `.backup` modifié dans l'arborescence mobile (respecté la règle impérative)

---
**Produit par** : Agent C13 — Audit iOS, interface mobile et protection du dépôt
**Date** : 2026-10-22
