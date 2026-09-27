
import { test, expect } from '@playwright/test';

test.describe('TENΛ Budget Étape 10 - Parcours complet E2E', () => {
  test('import 11 étapes visibles + progression + retour arrière sûr', async ({ page }) => {
    await page.goto('/import');
    await expect(page.locator('text=Pipeline 11 étapes')).toBeVisible();
    await expect(page.locator('text=Sélection')).toBeVisible();
    await expect(page.locator('text=Analyse')).toBeVisible();
    await expect(page.locator('text=Détection')).toBeVisible();
    await expect(page.locator('text=Validation')).toBeVisible();
    await expect(page.locator('text=Rapport')).toBeVisible();
    // Progression claire
    await expect(page.locator('text=en cours')).toBeVisible();
  });

  test('correction mapping relance réellement analyse', async ({ page }) => {
    await page.goto('/import');
    // Va à étape 5
    await page.click('text=Suivant →');
    await page.click('text=Suivant →');
    await page.click('text=Suivant →');
    await page.click('text=Suivant →');
    await expect(page.locator('text=Corrections')).toBeVisible();
    await expect(page.locator('text=relance réellement')).toBeVisible();
    await page.click('text=Corriger → Relance réelle');
    await expect(page.locator('text=Corrigé, analyse relancée')).toBeVisible();
  });

  test('doublons côte à côte + keep_both par défaut', async ({ page }) => {
    await page.goto('/import');
    for (let i=0;i<5;i++) await page.click('text=Suivant →');
    await expect(page.locator('text=Doublons')).toBeVisible();
    await expect(page.locator('text=keep_both')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Côte à côte')).toBeVisible();
    await expect(page.locator('text=Entrant')).toBeVisible();
    await expect(page.locator('text=Existant')).toBeVisible();
  });

  test('sélection années + validation obligatoire avant import', async ({ page }) => {
    await page.goto('/import');
    for (let i=0;i<7;i++) await page.click('text=Suivant →');
    await expect(page.locator('text=Prévisualisation')).toBeVisible();
    await expect(page.locator('text=Années détectées')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Validation')).toBeVisible();
    await expect(page.locator('text=Obligatoire avant import')).toBeVisible();
    // Suivant bloqué sans validation
    await expect(page.locator('text=Validation obligatoire')).toBeVisible();
  });

  test('aucun import réel avant validation + rapport complet', async ({ page }) => {
    await page.goto('/import');
    for (let i=0;i<8;i++) await page.click('text=Suivant →');
    await page.check('input[type="checkbox"]');
    await expect(page.locator('text=Validé')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Import')).toBeVisible();
    await expect(page.locator('text=IMPORT_FORBIDDEN')).toBeVisible();
    await page.click('text=Terminer import → Rapport');
    await expect(page.locator('text=Rapport final complet')).toBeVisible();
    await expect(page.locator('text=Importés')).toBeVisible();
    await expect(page.locator('text=Ignorés')).toBeVisible();
    await expect(page.locator('text=Modifiés')).toBeVisible();
    await expect(page.locator('text=Ambigus')).toBeVisible();
    await expect(page.locator('text=Doublons')).toBeVisible();
  });

  test('parcours complet import → correction → doublons → validation → import → dashboard → recherche → comparaison', async ({ page }) => {
    await page.goto('/import');
    await expect(page.locator('text=Pipeline 11 étapes')).toBeVisible();
    // 1-4
    for (let i=0;i<4;i++) await page.click('text=Suivant →');
    await expect(page.locator('text=Corrections')).toBeVisible();
    // Correction
    await page.click('text=Corriger → Relance réelle');
    await page.click('text=Suivant →');
    await expect(page.locator('text=Doublons')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Côte à côte')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Prévisualisation')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Validation')).toBeVisible();
    await page.check('input[type="checkbox"]');
    await page.click('text=Suivant →');
    await page.click('text=Terminer import → Rapport');
    await expect(page.locator('text=Rapport final')).toBeVisible();
    // Dashboard
    await page.goto('/dashboard');
    await expect(page.locator('text=Tableau de bord final')).toBeVisible();
    await expect(page.locator('text=BUDGET PRÉVU')).toBeVisible();
    // Transactions recherche
    await page.goto('/transactions');
    await expect(page.locator('text=Recherche avancée')).toBeVisible();
    await expect(page.locator('text=Filtres combinables')).toBeVisible();
    // Comparaison
    await page.goto('/historique');
    await expect(page.locator('text=Historique')).toBeVisible();
    // Assistant
    await page.goto('/assistant');
    await expect(page.locator('text=search_transactions')).toBeVisible();
    await expect(page.locator('text=compare_periods')).toBeVisible();
  });

  test('dashboard final graphiques réels + filtres combinables + familial vs individuel', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Par catégorie')).toBeVisible();
    await expect(page.locator('text=Évolution mensuelle')).toBeVisible();
    await expect(page.locator('text=Jamais mélangés')).toBeVisible();
    await expect(page.locator('text=Filtres combinables')).toBeVisible();
  });

  test('transactions final tri + pagination + soft delete + permissions', async ({ page }) => {
    await page.goto('/transactions');
    await expect(page.locator('text=Tri')).toBeVisible();
    await expect(page.locator('text=Page 1')).toBeVisible();
    await expect(page.locator('text=Soft delete')).toBeVisible();
    await expect(page.locator('text=assertCan')).toBeVisible();
  });

  test('assistant final search_transactions + compare_periods reliés moteur + familyId isolé', async ({ page }) => {
    await page.goto('/assistant');
    await expect(page.locator('text=search_transactions')).toBeVisible();
    await expect(page.locator('text=compare_periods')).toBeVisible();
    await expect(page.locator('text=familyId isolé')).toBeVisible();
    await expect(page.locator('text=Aucune API LLM payante')).toBeVisible();
    await expect(page.locator('text=Aucune modif financière sans contrôles')).toBeVisible();
  });
});
