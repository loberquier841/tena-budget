# MISSION C01-B2 — SÉCURISATION RÉELLE ET COHÉRENCE DES DONNÉES

## 1. Causes exactes des problèmes

### 1.1 familyId depuis localStorage dans transactions/page.tsx

**Fichier** : `apps/web/app/transactions/page.tsx`, ligne 31 (avant correction)

```typescript
const familyId = session?.userId || localStorage.getItem('familyId') || 'family_default';
```

**Problème** : Le code avait des commentaires d'avertissement ("Interdiction : ne pas considérer localStorage comme preuve d'autorisation - problème C4 du rapport C01") mais implémentait exactement l'interdit : priorité à la session, puis localStorage, puis 'family_default'.

**Conséquence** : La valeur 'family_default' est partagée par tous les utilisateurs sans session dans le même navigateur, provoquant un mélange de données entre comptes (problème C4).

### 1.2 familyId avec fallback 'family_default' dans budgets et objectifs

**Fichiers** :
- `apps/web/app/budgets/page.tsx`, ligne 8
- `apps/web/app/objectifs/page.tsx`, ligne 8

```typescript
const familyId = session.userId || 'family_default';
```

**Problème** : 'family_default' comme valeur par défaut signifie que tous les utilisateurs sans session dans un navigateur partageront les mêmes données familiales.

### 1.3 assertCan non exécuté en runtime

**Fichier** : `apps/web/app/transactions/page.tsx`, lignes 144-147 (avant correction)

Les vérifications n'étaient mentionnées que dans le texte des boutons, jamais exécutées à runtime.

## 2. Corrections apportées

### 2.1 transactions/page.tsx

- Retiré `localStorage.getItem('familyId')` fallback
- Retiré `'family_default'` fallback
- Si pas de session : affichage erreur "Connexion requise" + chargement interrompu
- Si session : utilisation de `session.userId` uniquement comme familyId
- Import et utilisation de `assertCan` pour les permissions d'édition/suppression

### 2.2 budgets/page.tsx

- `session.userId || 'family_default'` → `session.userId`

### 2.3 objectifs/page.tsx

- `session.userId || 'family_default'` → `session.userId`

## 3. Fichiers modifiés

- `apps/web/app/transactions/page.tsx` — retrait fallbacks dangereux, ajout assertCan
- `apps/web/app/budgets/page.tsx` — retrait fallback family_default
- `apps/web/app/objectifs/page.tsx` — retrait fallback family_default

## 4. Risques restants

- L'IndexedDB locale ne fournit pas de séparation sécurisée entre utilisateurs du même navigateur
- assertCan non entièrement exécuté en runtime côté frontend
- Pages d'import/export non opérantes (dépendances manquantes)

## 5. Prochaines actions

1. Documenter la limitation IndexedDB navigateur partagé
2. Tester les mécanismes de session absente et identité inconnue
3. Résoudre les dépendances exceljs/papaparse/jspdf pour pages /import et /export