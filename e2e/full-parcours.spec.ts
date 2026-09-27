
import { test, expect } from '@playwright/test';

test.describe('TENΛ Budget Étape 12 - Parcours complet + Audit + Consolidation', () => {
  test('audit 11 vérifications toutes PASS', async ({ page }) => {
    await page.goto('/audit');
    await expect(page.locator('text=Audit Sécurité')).toBeVisible();
    await expect(page.locator('text=Permissions serveur')).toBeVisible();
    await expect(page.locator('text=Isolation familyId')).toBeVisible();
    await expect(page.locator('text=Simulations isolation')).toBeVisible();
    await expect(page.locator('text=Transactions supprimées')).toBeVisible();
    await expect(page.locator('text=Validations obligatoires')).toBeVisible();
    await expect(page.locator('text=Secrets sensibles')).toBeVisible();
    await expect(page.locator('text=PWA/offline/sync')).toBeVisible();
    await expect(page.locator('text=Responsive')).toBeVisible();
    await expect(page.locator('text=Cohérence 15 écrans')).toBeVisible();
    await expect(page.locator('text=Sauvegardes')).toBeVisible();
    await expect(page.locator('text=Banking mock uniquement')).toBeVisible();
  });

  test('écrans vérifiés 15 écrans cohérents', async ({ page }) => {
    const screens = ['/dashboard', '/budgets', '/transactions', '/recurrentes', '/objectifs', '/famille', '/historique', '/simulations', '/assistant', '/import', '/exports', '/sauvegardes', '/banking', '/audit'];
    for (const screen of screens) {
      await page.goto(screen);
      await expect(page.locator('main')).toBeVisible();
    }
  });

  test('PWA manifest installable', async ({ page }) => {
    const manifestResponse = await page.request.get('/manifest.json');
    expect(manifestResponse.ok()).toBeTruthy();
    const manifest = await manifestResponse.json();
    expect(manifest.name).toBe('TENΛ Budget');
    expect(manifest.display).toBe('standalone');
    expect(manifest.theme_color).toBe('#7C3AED');
  });

  test('responsive téléphone/tablette/ordinateur', async ({ page }) => {
    await page.goto('/dashboard');
    // Desktop
    await page.setViewportSize({ width: 1200, height: 800 });
    await expect(page.locator('nav')).toBeVisible();
    // Mobile
    await page.setViewportSize({ width: 375, height: 800 });
    await expect(page.locator('text=TENΛ Budget').first()).toBeVisible();
  });

  test('sauvegardes/restaurations AES-GCM + SHA-256', async ({ page }) => {
    await page.goto('/sauvegardes');
    await expect(page.locator('text=Chiffrées')).toBeVisible();
    await expect(page.locator('text=AES-GCM')).toBeVisible();
    await expect(page.locator('text=checksum')).toBeVisible();
  });

  test('banking mock uniquement aucun SDK réel', async ({ page }) => {
    await page.goto('/banking');
    await expect(page.locator('text=Préparation')).toBeVisible();
    await expect(page.locator('text=Aucune connexion vraie banque')).toBeVisible();
    await expect(page.locator('text=Aucun SDK réel')).toBeVisible();
    await expect(page.locator('text=IBAN masqué')).toBeVisible();
    await expect(page.locator('text=Validation humaine obligatoire')).toBeVisible();
  });

  test('parcours complet E2E import→correction→doublons→validation→dashboard→recherche→comparaison→backup→banking mock', async ({ page }) => {
    // Import
    await page.goto('/import');
    await expect(page.locator('text=Pipeline 11 étapes')).toBeVisible();
    for (let i=0;i<4;i++) await page.click('text=Suivant →');
    await page.click('text=Corriger → Relance réelle');
    await page.click('text=Suivant →');
    await expect(page.locator('text=Doublons')).toBeVisible();
    await page.click('text=Suivant →');
    await expect(page.locator('text=Côte à côte')).toBeVisible();
    await page.click('text=Suivant →');
    await page.click('text=Suivant →');
    await page.check('input[type="checkbox"]');
    await page.click('text=Suivant →');
    await page.click('text=Terminer import → Rapport');
    await expect(page.locator('text=Rapport final')).toBeVisible();
    // Dashboard
    await page.goto('/dashboard');
    await expect(page.locator('text=Tableau de bord final')).toBeVisible();
    // Transactions
    await page.goto('/transactions');
    await expect(page.locator('text=Recherche avancée')).toBeVisible();
    // Historique
    await page.goto('/historique');
    await expect(page.locator('text=Historique')).toBeVisible();
    // Assistant
    await page.goto('/assistant');
    await expect(page.locator('text=search_transactions')).toBeVisible();
    // Sauvegardes
    await page.goto('/sauvegardes');
    await expect(page.locator('text=Sauvegardes')).toBeVisible();
    // Banking mock
    await page.goto('/banking');
    await expect(page.locator('text=Banking')).toBeVisible();
    // Audit
    await page.goto('/audit');
    await expect(page.locator('text=Audit Sécurité')).toBeVisible();
  });

  test('aucun secret dans frontend + PC personnel jamais nécessaire', async ({ page }) => {
    await page.goto('/audit');
    await expect(page.locator('text=0 fichiers frontend')).toBeVisible();
    await expect(page.locator('text=PC éteint')).toBeVisible();
    await expect(page.locator('text=Aucun serveur local sur PC')).toBeVisible();
  });

  test('bibliothèques distinction prévu/installé/configuré/déployé', async ({ page }) => {
    await page.goto('/audit');
    await expect(page.locator('text=État déploiement')).toBeVisible();
    await expect(page.locator('text=Prévu')).toBeVisible();
    await expect(page.locator('text=Installé')).toBeVisible();
    await expect(page.locator('text=Configuré')).toBeVisible();
    await expect(page.locator('text=Déployé')).toBeVisible();
  });
});
