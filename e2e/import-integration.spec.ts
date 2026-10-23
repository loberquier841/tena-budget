import { test, expect } from '@playwright/test';
import { Buffer } from 'node:buffer';
import { readFile } from 'node:fs/promises';

async function completeOnboarding(page: import('@playwright/test').Page) {
  await page.goto('/onboarding');
  const passphrases = page.locator('input[type="password"]');
  await passphrases.nth(0).fill('integration passphrase 2026');
  await passphrases.nth(1).fill('integration passphrase 2026');
  await page.getByRole('button', { name: 'Créer le coffre et continuer' }).click();
  await page.getByText('Personnel — Je gère mes finances seul(e)').click();
  await page.getByRole('button', { name: 'Suivant →' }).click();
  await page.getByText('Revenus réguliers — Salaire fixe ou revenus prévisibles').click();
  await page.getByRole('button', { name: 'Suivant →' }).click();
  await page.getByText('Débutant(e) — Je commence à budgétiser').click();
  await page.getByRole('button', { name: 'Suivant →' }).click();
  await page.getByRole('checkbox').first().check({ force: true });
  await page.getByText('Contrôler mes dépenses', { exact: false }).click();
  await expect(page.getByRole('button', { name: 'Suivant →' })).toBeEnabled();
  await page.getByRole('button', { name: 'Suivant →' }).click();
  await page.getByRole('button', { name: 'Suivant →' }).click();
  await page.getByText('Équilibré', { exact: false }).click();
  await page.getByRole('button', { name: 'Voir le récapitulatif' }).click();
  await page.getByRole('button', { name: 'Créer mon profil' }).click();
  await page.getByRole('button', { name: 'Accéder au tableau de bord' }).click();
  await expect(page).toHaveURL(/dashboard/);
  await expect(page.getByRole('heading', { name: 'Alertes de budget' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Aucun objectif d’épargne' })).toHaveCount(0);
}

async function transactionCount(page: import('@playwright/test').Page) {
  return page.evaluate(() => new Promise<number>((resolve, reject) => {
    const request = indexedDB.open('TenaBudgetDB');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const database = request.result;
      const count = database.transaction('transactions', 'readonly').objectStore('transactions').count();
      count.onsuccess = () => { resolve(count.result); database.close(); };
      count.onerror = () => reject(count.error);
    };
  }));
}

async function objectStoreCount(page: import('@playwright/test').Page, storeName: string) {
  return page.evaluate((name) => new Promise<number>((resolve, reject) => {
    const request = indexedDB.open('TenaBudgetDB');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const database = request.result;
      const count = database.transaction(name, 'readonly').objectStore(name).count();
      count.onsuccess = () => { resolve(count.result); database.close(); };
      count.onerror = () => reject(count.error);
    };
  }), storeName);
}

const csvFile = {
  name: 'releve.csv', mimeType: 'text/csv',
  buffer: Buffer.from('Date;Libellé;Montant;Catégorie\n2026-10-12;Courses importées;-24,50;Alimentation', 'utf8'),
};

test('questionnaire → import → sauvegarde → restauration chiffrée et récupération dans un nouvel espace', async ({ page, browser }) => {
  await completeOnboarding(page);
  await page.getByRole('link', { name: /Importer/ }).first().click();
  await expect(page.getByText('Crée d’abord une transaction ou un budget local')).toHaveCount(0);
  const fileInput = page.locator('input[type="file"]').first();

  await fileInput.setInputFiles(csvFile);
  await expect(page.getByText('Courses importées')).toBeVisible();
  await expect(page.getByText('Prêt')).toBeVisible();
  const addCsv = page.getByRole('button', { name: 'Ajouter 1 transaction(s)' });

  page.once('dialog', dialog => dialog.dismiss());
  await addCsv.click();
  expect(await transactionCount(page)).toBe(0);

  await page.evaluate(() => {
    const prototype = IDBObjectStore.prototype as IDBObjectStore & { __originalAdd?: IDBObjectStore['add'] };
    prototype.__originalAdd = prototype.add;
    prototype.add = function () { throw new DOMException('test write failure', 'QuotaExceededError'); };
  });
  page.once('dialog', dialog => dialog.accept());
  await addCsv.click();
  await expect(page.getByRole('status')).toContainText('Import annulé');
  expect(await transactionCount(page)).toBe(0);
  await page.evaluate(() => {
    const prototype = IDBObjectStore.prototype as IDBObjectStore & { __originalAdd?: IDBObjectStore['add'] };
    if (prototype.__originalAdd) prototype.add = prototype.__originalAdd;
    delete prototype.__originalAdd;
  });

  page.once('dialog', dialog => dialog.accept());
  await addCsv.click();
  await expect(page.getByRole('status')).toContainText('1 transaction(s) ajoutée(s) localement');
  expect(await transactionCount(page)).toBe(1);
  const encryptedRecord = await page.evaluate(() => new Promise<{ label: string; amountCents: string; source: string }>((resolve, reject) => {
    const request = indexedDB.open('TenaBudgetDB');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const database = request.result;
      const rows = database.transaction('transactions', 'readonly').objectStore('transactions').getAll();
      rows.onsuccess = () => { resolve(rows.result[0] as { label: string; amountCents: string; source: string }); database.close(); };
      rows.onerror = () => reject(rows.error);
    };
  }));
  expect(encryptedRecord.label).toMatch(/^tena:v1:/);
  expect(encryptedRecord.amountCents).toMatch(/^tena:v1:/);
  expect(encryptedRecord.source).toBe('import');

  await fileInput.setInputFiles(csvFile);
  await expect(page.getByText('Déjà présent')).toBeVisible();
  await expect(page.getByRole('button', { name: /Ajouter 0 transaction/ })).toBeDisabled();
  await fileInput.setInputFiles({ name: 'cassé.csv', mimeType: 'text/csv', buffer: Buffer.from('Date;Libellé;Montant\n2026-10-12;"ligne cassée;12') });
  await expect(page.getByRole('status')).toContainText('guillemet qui n’est pas refermé');
  expect(await transactionCount(page)).toBe(1);

  const ExcelJS = require('../packages/import-engine/node_modules/exceljs');
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet('Transactions');
  worksheet.addRow(['Date', 'Libellé', 'Montant', 'Catégorie']);
  worksheet.addRow([new Date('2026-10-13T12:00:00Z'), 'Train importé', -9.8, 'Transport']);
  const xlsx = await workbook.xlsx.writeBuffer();
  await fileInput.setInputFiles({ name: 'releve.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', buffer: Buffer.from(xlsx) });
  await expect(page.getByText('Train importé')).toBeVisible();
  page.once('dialog', dialog => dialog.accept());
  await page.getByRole('button', { name: 'Ajouter 1 transaction(s)' }).click();
  await expect(page.getByRole('status')).toContainText('1 transaction(s) ajoutée(s) localement');
  expect(await transactionCount(page)).toBe(2);

  await page.getByRole('link', { name: /Tableau de bord/ }).click();
  await expect(page.getByText('Courses importées')).toBeVisible();
  await expect(page.getByText('Train importé')).toBeVisible();
  await expect(page.getByText('34.30', { exact: false }).first()).toBeVisible();

  await page.locator('nav a[href="/transactions"]').first().click();
  await expect(page.getByRole('cell', { name: 'Courses importées' })).toBeVisible();
  await expect(page.getByRole('cell', { name: 'Train importé' })).toBeVisible();

  await page.evaluate(() => new Promise<void>((resolve, reject) => {
    const open = indexedDB.open('TenaBudgetDB');
    open.onerror = () => reject(open.error);
    open.onsuccess = () => {
      const db = open.result;
      const rows = db.transaction('transactions', 'readonly').objectStore('transactions').getAll();
      rows.onerror = () => reject(rows.error);
      rows.onsuccess = () => {
        const row = rows.result[0] as { familyId: string };
        const date = new Date('2026-10-01T00:00:00');
        const write = db.transaction('budgets', 'readwrite');
        write.objectStore('budgets').add({ id: 'e2e-budget', familyId: row.familyId, amountCents: 10000, year: date.getFullYear(), month: date.getMonth() + 1, categoryId: 'Alimentation', syncStatus: 'synced', updatedAt: date });
        write.oncomplete = () => { db.close(); resolve(); };
        write.onerror = () => reject(write.error);
      };
    };
  }));
  await page.locator('nav a[href="/budgets"]').first().click();
  const budgetRow = page.getByRole('row').filter({ hasText: 'Alimentation' });
  await expect(budgetRow).toContainText('24,50');
  await expect(budgetRow).toContainText('75,50');

  await page.locator('nav a[href="/sauvegardes"]').first().evaluate((link: HTMLAnchorElement) => link.click());
  await page.locator('section').first().getByLabel('Mot de passe de la sauvegarde').fill('backup-pass-2026');
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Chiffrer et télécharger' }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/\.tenla\.enc$/);
  await expect(page.getByText('Contenu : 2 transactions')).toBeVisible();
  const backupPath = await download.path();
  if (!backupPath) throw new Error('Le navigateur n’a pas fourni le fichier de sauvegarde téléchargé.');
  const encryptedBackup = JSON.parse((await readFile(backupPath)).toString('utf8'));

  await page.goto('/dashboard');
  await expect(page).toHaveURL(/onboarding/);
  await page.getByLabel('Phrase secrète').fill('mauvaise phrase secrète 2026');
  await page.getByRole('button', { name: 'Déverrouiller mon espace' }).click();
  await expect(page.locator('p[role="alert"]')).toContainText('Phrase secrète incorrecte');
  expect(await transactionCount(page)).toBe(2);
  await page.getByLabel('Phrase secrète').fill('integration passphrase 2026');
  await page.getByRole('button', { name: 'Déverrouiller mon espace' }).click();
  await expect(page).toHaveURL(/dashboard/);
  await expect(page.getByText('Courses importées')).toBeVisible();
  await page.locator('nav a[href="/sauvegardes"]').first().evaluate((link: HTMLAnchorElement) => link.click());

  // Empty the local stores but keep the vault metadata so this is a true restore into the same device vault.
  await page.evaluate(() => new Promise<void>((resolve, reject) => {
    const request = indexedDB.open('TenaBudgetDB');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const database = request.result;
      const names = ['transactions', 'budgets', 'savingGoals', 'savingContributions', 'syncQueue', 'conflicts', 'userProfiles'];
      const transaction = database.transaction(names, 'readwrite');
      for (const name of names) transaction.objectStore(name).clear();
      transaction.oncomplete = () => { database.close(); resolve(); };
      transaction.onerror = () => reject(transaction.error);
      transaction.onabort = () => reject(transaction.error ?? new Error('clear aborted'));
    };
  }));
  expect(await transactionCount(page)).toBe(0);

  // A reload must lock the vault. Unlock, then test malformed, corrupted, wrong-password and cancelled restores.
  await page.goto('/dashboard');
  await expect(page).toHaveURL(/onboarding/);
  await expect(page.getByRole('heading', { name: 'TENΛ Budget — Déverrouiller' })).toBeVisible();
  await page.getByLabel('Phrase secrète').fill('integration passphrase 2026');
  await page.getByRole('button', { name: 'Déverrouiller mon espace' }).click();
  await expect(page.getByText('TENΛ Budget — Déverrouiller')).toHaveCount(0);
  await page.locator('nav a[href="/sauvegardes"]').first().evaluate((link: HTMLAnchorElement) => link.click());
  const restoreFileInput = page.locator('input[type="file"]');
  const backupPasswordInput = page.getByLabel('Mot de passe de la sauvegarde').last();
  await backupPasswordInput.fill('backup-pass-2026');
  const inspectButton = page.getByRole('button', { name: 'Déchiffrer et vérifier' });

  await restoreFileInput.setInputFiles({ name: 'invalide.tenla.enc', mimeType: 'application/json', buffer: Buffer.from('{pas du json') });
  await inspectButton.click();
  await expect(page.locator('p[role="alert"]').first()).toContainText('Impossible de vérifier ce fichier');
  expect(await transactionCount(page)).toBe(0);

  const corruptedBackup = { ...encryptedBackup, data: `${encryptedBackup.data[0] === 'A' ? 'B' : 'A'}${encryptedBackup.data.slice(1)}` };
  await restoreFileInput.setInputFiles({ name: 'corrompue.tenla.enc', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(corruptedBackup)) });
  await inspectButton.click();
  await expect(page.locator('p[role="alert"]').first()).toContainText('Impossible de vérifier ce fichier');
  expect(await transactionCount(page)).toBe(0);

  await restoreFileInput.setInputFiles({ name: 'tena-budget.tenla.enc', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(encryptedBackup)) });
  await backupPasswordInput.fill('wrong-backup-password');
  await inspectButton.click();
  await expect(page.locator('p[role="alert"]').first()).toContainText('Impossible de vérifier ce fichier');
  expect(await transactionCount(page)).toBe(0);

  await backupPasswordInput.fill('backup-pass-2026');
  await inspectButton.click();
  await expect(page.getByText(/Aperçu : 2 transactions \(dont 0 dans la corbeille\), 1 budgets, 0 objectifs, 0 versements/)).toBeVisible();
  await expect(page.getByText('Profil questionnaire inclus : il sera ajouté.')).toBeVisible();
  await page.getByRole('button', { name: 'Annuler l’aperçu' }).click();
  await expect(page.getByRole('status').first()).toContainText('Aperçu annulé');
  expect(await transactionCount(page)).toBe(0);

  await inspectButton.click();
  await expect(page.getByRole('button', { name: 'Ajouter ces données à mon stockage local' })).toBeVisible();
  await page.getByRole('button', { name: 'Ajouter ces données à mon stockage local' }).click();
  await expect(page.getByRole('status').first()).toContainText('Restauration terminée');
  expect(await transactionCount(page)).toBe(2);
  expect(await objectStoreCount(page, 'syncQueue')).toBe(3);

  await restoreFileInput.setInputFiles({ name: 'tena-budget.tenla.enc', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(encryptedBackup)) });
  await backupPasswordInput.fill('backup-pass-2026');
  await inspectButton.click();
  await expect(page.locator('ul[role="alert"]')).toContainText('Transaction');
  await expect(page.getByRole('button', { name: 'Ajouter ces données à mon stockage local' })).toHaveCount(0);
  expect(await transactionCount(page)).toBe(2);

  // Another full navigation drops the in-memory key; imported rows and restored profile must remain.
  await page.goto('/dashboard');
  await expect(page).toHaveURL(/onboarding/);
  await expect(page.getByRole('heading', { name: 'TENΛ Budget — Déverrouiller' })).toBeVisible();
  await page.getByLabel('Phrase secrète').fill('integration passphrase 2026');
  await page.getByRole('button', { name: 'Déverrouiller mon espace' }).click();
  await expect(page).toHaveURL(/dashboard/);
  await expect(page.getByText(/• personal/)).toBeVisible();
  await expect(page.getByText('Courses importées')).toBeVisible();
  await expect(page.getByText('Train importé')).toBeVisible();
  expect(await objectStoreCount(page, 'syncQueue')).toBe(3);
  await page.locator('nav a[href="/budgets"]').first().evaluate((link: HTMLAnchorElement) => link.click());
  await expect(page).toHaveURL(/budgets/);
  const restoredBudgetRow = page.getByRole('row', { name: /2026-10 Alimentation/ });
  await expect(restoredBudgetRow).toContainText('24,50');
  await expect(restoredBudgetRow).toContainText('75,50');

  // Recovery with a new vault proves the backup password is independent from the lost old-vault phrase.
  const recoveryContext = await browser.newContext();
  try {
    const recoveryPage = await recoveryContext.newPage();
    await recoveryPage.goto('/onboarding');
    const recoveryPassphrases = recoveryPage.locator('input[type="password"]');
    await recoveryPassphrases.nth(0).fill('new recovery vault phrase 2026');
    await recoveryPassphrases.nth(1).fill('new recovery vault phrase 2026');
    await recoveryPage.getByRole('button', { name: 'Créer le coffre et continuer' }).click();
    await expect(recoveryPage.getByText('Personnel — Je gère mes finances seul(e)')).toBeVisible();
    await recoveryPage.locator('nav a[href="/sauvegardes"]').first().evaluate((link: HTMLAnchorElement) => link.click());
    await recoveryPage.locator('input[type="file"]').setInputFiles({
      name: 'tena-budget.tenla.enc', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(encryptedBackup)),
    });
    await recoveryPage.getByLabel('Mot de passe de la sauvegarde').last().fill('backup-pass-2026');
    await recoveryPage.getByRole('button', { name: 'Déchiffrer et vérifier' }).click();
    await expect(recoveryPage.getByText(/Profil questionnaire inclus : il remplacera la progression inachevée/)).toBeVisible();
    const progressCipherBefore = await recoveryPage.evaluate(() => new Promise<string>((resolve, reject) => {
      const request = indexedDB.open('TenaBudgetDB');
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const database = request.result;
        const read = database.transaction('userProfiles', 'readonly').objectStore('userProfiles').get('primary');
        read.onerror = () => reject(read.error);
        read.onsuccess = () => { resolve(read.result.payload as string); database.close(); };
      };
    }));
    recoveryPage.once('dialog', (dialog) => dialog.dismiss());
    await recoveryPage.getByRole('button', { name: 'Ajouter ces données à mon stockage local' }).click();
    await expect(recoveryPage.getByRole('status').first()).toContainText('Restauration annulée');
    expect(await transactionCount(recoveryPage)).toBe(0);
    const progressCipherAfter = await recoveryPage.evaluate(() => new Promise<string>((resolve, reject) => {
      const request = indexedDB.open('TenaBudgetDB');
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const database = request.result;
        const read = database.transaction('userProfiles', 'readonly').objectStore('userProfiles').get('primary');
        read.onerror = () => reject(read.error);
        read.onsuccess = () => { resolve(read.result.payload as string); database.close(); };
      };
    }));
    expect(progressCipherAfter).toBe(progressCipherBefore);
    recoveryPage.once('dialog', (dialog) => dialog.accept());
    await recoveryPage.getByRole('button', { name: 'Ajouter ces données à mon stockage local' }).click();
    await expect(recoveryPage.getByRole('status').first()).toContainText('Restauration terminée');
    await recoveryPage.locator('nav a[href="/dashboard"]').first().evaluate((link: HTMLAnchorElement) => link.click());
    await expect(recoveryPage).toHaveURL(/dashboard/);
    await expect(recoveryPage.getByText('Courses importées')).toBeVisible();
    await expect(recoveryPage.getByText('Train importé')).toBeVisible();
  } finally {
    await recoveryContext.close();
  }
});
