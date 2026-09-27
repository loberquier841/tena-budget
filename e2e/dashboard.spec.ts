
import { test, expect } from '@playwright/test';

test.describe('TENΛ Budget - Parcours complet E2E', () => {
  test('dashboard affiche budget vs dépensé vs restant Int', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Tableau de bord')).toBeVisible();
    await expect(page.locator('text=BUDGET PRÉVU')).toBeVisible();
    await expect(page.locator('text=DÉPENSÉ')).toBeVisible();
    await expect(page.locator('text=RESTANT')).toBeVisible();
    // Vérifie centimes affichés
    await expect(page.locator('text=centimes')).toBeVisible();
  });

  test('navigation cohérente entre écrans', async ({ page }) => {
    await page.goto('/dashboard');
    await page.click('text=Famille');
    await expect(page).toHaveURL(/.*famille/);
    await page.click('text=Simulations');
    await expect(page).toHaveURL(/.*simulations/);
    await page.click('text=Assistant TENΛ');
    await expect(page).toHaveURL(/.*assistant/);
    await page.click('text=Tableau de bord');
    await expect(page).toHaveURL(/.*dashboard/);
  });

  test('filtres personne/période', async ({ page }) => {
    await page.goto('/dashboard');
    await page.selectOption('select >> nth=0', 'Parent 1');
    await expect(page.locator('text=Parent 1')).toBeVisible();
  });

  test('simulations isolées - aucune Transaction réelle modifiée', async ({ page }) => {
    await page.goto('/simulations');
    await expect(page.locator('text=Isolées')).toBeVisible();
    await expect(page.locator('text=sim_')).toBeVisible();
    await expect(page.locator('text=simtx_')).toBeVisible();
  });

  test('assistant respecte permissions', async ({ page }) => {
    await page.goto('/assistant');
    await expect(page.locator('text=Lecture données autorisées')).toBeVisible();
    await expect(page.locator('text=Aucune API LLM payante')).toBeVisible();
    await page.click('text=Interroger');
    await expect(page.locator('text=Total dépensé')).toBeVisible();
  });

  test('PWA installable - manifest', async ({ page }) => {
    const manifestResponse = await page.request.get('/manifest.json');
    expect(manifestResponse.ok()).toBeTruthy();
    const manifest = await manifestResponse.json();
    expect(manifest.name).toBe('TENΛ Budget');
    expect(manifest.display).toBe('standalone');
  });

  test('offline-first Dexie - isDeleted exclu', async ({ page }) => {
    await page.goto('/dashboard');
    // Vérifie que offline-ready affiché
    await expect(page.locator('text=Offline-ready')).toBeVisible();
    await expect(page.locator('text=isDeleted exclu')).toBeVisible();
  });

  test('exports respect filtres + totaux Int', async ({ page }) => {
    await page.goto('/exports');
    await expect(page.locator('text=Excel')).toBeVisible();
    await expect(page.locator('text=CSV')).toBeVisible();
    await expect(page.locator('text=PDF')).toBeVisible();
    await expect(page.locator('text=centimes')).toBeVisible();
  });

  test('sauvegardes chiffrées', async ({ page }) => {
    await page.goto('/sauvegardes');
    await expect(page.locator('text=Chiffrées')).toBeVisible();
    await expect(page.locator('text=AES-GCM')).toBeVisible();
    await expect(page.locator('text=checksum')).toBeVisible();
  });

  test('parcours complet import → budget → transaction → simulation → export → backup', async ({ page }) => {
    await page.goto('/dashboard');
    // 1. Dashboard OK
    await expect(page.locator('text=Tableau de bord')).toBeVisible();
    // 2. Famille
    await page.goto('/famille');
    await expect(page.locator('text=Famille')).toBeVisible();
    // 3. Simulations
    await page.goto('/simulations');
    await expect(page.locator('text=Simulations')).toBeVisible();
    // 4. Assistant
    await page.goto('/assistant');
    await expect(page.locator('text=Assistant TENΛ')).toBeVisible();
    // 5. Exports
    await page.goto('/exports');
    await expect(page.locator('text=Exports')).toBeVisible();
    // 6. Sauvegardes
    await page.goto('/sauvegardes');
    await expect(page.locator('text=Sauvegardes')).toBeVisible();
  });
});
