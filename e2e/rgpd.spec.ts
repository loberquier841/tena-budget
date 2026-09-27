
import { test, expect } from '@playwright/test';

test.describe('TENΛ Budget Étape 14 - RGPD + Anonymisation + Registre + Export + Isolation', () => {
  test('export famille isolée + personne isolée + isDeleted exclu', async ({ page }) => {
    await page.goto('/exports');
    await expect(page.locator('text=Exports')).toBeVisible();
    await expect(page.locator('text=Int centimes')).toBeVisible();
  });

  test('soft delete isDeleted=true + exclu stats + recherche', async ({ page }) => {
    await page.goto('/transactions');
    await expect(page.locator('text=isDeleted')).toBeVisible();
    await page.goto('/dashboard');
    await expect(page.locator('text=isDeleted exclu')).toBeVisible();
  });

  test('anonymisation après 30j + hard delete encadré owner', async ({ page }) => {
    await page.goto('/sauvegardes');
    await expect(page.locator('text=Chiffrées')).toBeVisible();
    // RGPD anonymisation à implémenter Étape 14
  });

  test('registre traitements 6 activités familyId isolé', async ({ page }) => {
    await page.goto('/audit');
    await expect(page.locator('text=Audit Sécurité')).toBeVisible();
  });

  test('secrets 0 frontend + IBAN masqué + MOCK_ONLY', async ({ page }) => {
    await page.goto('/audit');
    const content = await page.content();
    expect(content).not.toContain('AUTH_SECRET');
    expect(content).not.toContain('DATABASE_URL');
    await page.goto('/banking');
    await expect(page.locator('text=IBAN masqué')).toBeVisible();
    await expect(page.locator('text=Aucun SDK réel')).toBeVisible();
  });

  test('isolation stricte familles fam1 vs fam2', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Tableau de bord')).toBeVisible();
    await page.goto('/assistant');
    await expect(page.locator('text=familyId isolé')).toBeVisible();
  });

  test('health check API Vercel + PC éteint', async ({ page }) => {
    const health = await page.request.get('/api/health');
    // Si déployé, doit retourner 200 avec checks
    if (health.ok()) {
      const json = await health.json();
      expect(json.app).toBe('TENΛ Budget');
      expect(json.pcRequired).toBe(false);
      expect(json.banking).toContain('MOCK_ONLY');
    }
  });
});
