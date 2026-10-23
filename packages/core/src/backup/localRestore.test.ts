import 'fake-indexeddb/auto';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { activateLocalVault, createLocalVault, lockLocalVault } from '../localVault';
import { createUserProfile, type OnboardingAnswers, type OnboardingProgress } from '../product/profile';
import { db, getLocalBudgets, getLocalDeletedTransactions, getLocalOnboardingProgress, getLocalSavingContributions, getLocalSavingGoals, getLocalTransactions, getLocalUserProfile, saveLocalOnboardingProgress, saveLocalUserProfile } from '../sync/dexie';
import { createBackup, decryptBackup, encryptBackup, generateChecksum } from './backup';
import { createLocalBackup } from './local';
import { prepareLocalBackupRestore, restorePreparedLocalBackup } from './localRestore';

const familyId = 'restore-local-test';
const answers: OnboardingAnswers = {
  householdMode: 'personal', incomePattern: 'regular', budgetExperience: 'starting',
  priorities: ['save'], wantedFeatures: ['transactions'], notificationPreference: 'balanced',
};

async function clearLocalTables() {
  await db.open();
  await db.transaction('rw', [db.transactions, db.budgets, db.savingGoals, db.savingContributions, db.syncQueue, db.userProfiles], async () => {
    await Promise.all([
      db.transactions.clear(), db.budgets.clear(), db.savingGoals.clear(),
      db.savingContributions.clear(), db.syncQueue.clear(), db.userProfiles.clear(),
    ]);
  });
}

async function encryptedFixture(categories: any[] = [], options: { version?: string; omitTransactionFamily?: boolean; legacyOptionalFields?: boolean; onboardingProgress?: boolean; persons?: any[]; recurringRules?: any[] } = {}) {
  const goalCreatedAt = new Date('2026-01-01T00:00:00.000Z');
  const backup = await createBackup({
    familyId,
    transactions: [
      { id: 'tx-restore-1', familyId, amountCents: -1200, label: 'Courses importées', categoryId: 'Courses', source: 'import', bookingDate: new Date('2026-02-01T00:00:00.000Z'), isDeleted: false },
      { id: 'tx-restore-deleted', familyId, amountCents: -500, label: 'Transaction en corbeille', source: 'manual', bookingDate: new Date('2026-01-15T00:00:00.000Z'), isDeleted: true, deletedAt: new Date('2026-02-02T00:00:00.000Z') },
    ],
    budgets: [{ id: 'budget-restore-1', familyId, amountCents: 50000, year: 2026, month: 2 }],
    categories, persons: [],
    goals: [
      { id: 'goal-restore-1', familyId, name: 'Voyage', targetCents: 100000, currentCents: 10000, isArchived: false, isDeleted: false, createdAt: goalCreatedAt, updatedAt: goalCreatedAt },
      { id: 'goal-restore-deleted', familyId, name: 'Ancien projet', targetCents: 50000, currentCents: 5000, isArchived: false, isDeleted: true, deletedAt: goalCreatedAt, createdAt: goalCreatedAt, updatedAt: goalCreatedAt },
    ],
    savingContributions: [
      { id: 'contribution-restore-1', familyId, goalId: 'goal-restore-1', amountCents: 10000, bookingDate: goalCreatedAt, createdByUserId: 'local-owner' },
      { id: 'contribution-restore-deleted-goal', familyId, goalId: 'goal-restore-deleted', amountCents: 5000, bookingDate: goalCreatedAt, createdByUserId: 'local-owner' },
    ],
    recurringRules: [],
    userProfile: createUserProfile(answers, goalCreatedAt),
  }, 'owner');
  if (options.version) backup.version = options.version;
  if (options.omitTransactionFamily) delete backup.transactions[0].familyId;
  if (options.persons) backup.persons = options.persons;
  if (options.recurringRules) backup.recurringRules = options.recurringRules;
  if (options.legacyOptionalFields) {
    delete backup.savingContributions;
    delete backup.userProfile;
  }
  if (options.onboardingProgress) {
    const timestamp = goalCreatedAt.toISOString();
    backup.userProfile = {
      id: 'primary', schemaVersion: 1, status: 'in-progress', currentStep: 2,
      startedAt: timestamp, updatedAt: timestamp, answers,
      dashboard: { visibleCards: ['goals'], compact: false },
    };
  }
  backup.checksum = await generateChecksum(JSON.stringify({ ...backup, checksum: '' }));
  return encryptBackup(backup, 'backup-password-2026');
}

beforeEach(async () => {
  await clearLocalTables();
  const { key } = await createLocalVault('local vault test passphrase');
  activateLocalVault(key);
});

afterEach(async () => {
  await clearLocalTables();
  lockLocalVault();
});

describe('restauration locale d’une sauvegarde chiffrée', () => {
  it('vérifie, prévisualise et restaure les données dans IndexedDB chiffré', async () => {
    const encrypted = await encryptedFixture();
    const prepared = await prepareLocalBackupRestore(encrypted, 'backup-password-2026');

    expect(prepared.conflicts).toEqual([]);
    expect(prepared.counts).toEqual({ transactions: 2, deletedTransactions: 1, budgets: 1, goals: 2, contributions: 2, profile: 1 });
    expect(await restorePreparedLocalBackup(prepared)).toEqual(prepared.counts);
    expect((await getLocalTransactions(familyId)).map((row) => row.id)).toEqual(['tx-restore-1']);
    expect((await getLocalTransactions(familyId))[0]).toMatchObject({ label: 'Courses importées', categoryId: 'Courses', source: 'import', amountCents: -1200 });
    expect(await getLocalDeletedTransactions(familyId)).toMatchObject([{ id: 'tx-restore-deleted', isDeleted: true, label: 'Transaction en corbeille' }]);
    expect((await getLocalBudgets(familyId)).map((row) => row.amountCents)).toEqual([50000]);
    expect((await getLocalSavingGoals(familyId)).map((row) => row.name)).toEqual(['Voyage']);
    expect((await getLocalSavingContributions(familyId)).map((row) => row.id).sort()).toEqual(['contribution-restore-1', 'contribution-restore-deleted-goal']);
    expect(await db.syncQueue.where('familyId').equals(familyId).count()).toBe(7);
    expect((await db.syncQueue.toArray()).every((row) => typeof row.payload === 'string' && row.payload.startsWith('tena:v1:'))).toBe(true);
    const exported = await createLocalBackup(familyId, 'owner');
    expect(exported.transactions.map((row) => row.id).sort()).toEqual(['tx-restore-1', 'tx-restore-deleted']);
    expect(exported.goals.map((row) => row.id).sort()).toEqual(['goal-restore-1', 'goal-restore-deleted']);
    expect(exported.savingContributions).toHaveLength(2);
    const storedProfile = await db.userProfiles.get('primary');
    expect(storedProfile?.payload).toMatch(/^tena:v1:/);
    await db.close();
    await db.open();
    expect(await getLocalDeletedTransactions(familyId)).toHaveLength(1);
    expect(await getLocalSavingContributions(familyId)).toHaveLength(2);
    expect(await db.syncQueue.where('familyId').equals(familyId).count()).toBe(7);
  });

  it('accepte une ancienne sauvegarde 2.0 sans champs facultatifs et restaure la progression du questionnaire', async () => {
    const prepared = await prepareLocalBackupRestore(await encryptedFixture([], { legacyOptionalFields: true }), 'backup-password-2026');
    expect(prepared.counts.contributions).toBe(0);
    expect(prepared.counts.profile).toBe(0);
    await restorePreparedLocalBackup(prepared);
    expect(await getLocalSavingContributions(familyId)).toEqual([]);

    await clearLocalTables();
    const progressBackup = await prepareLocalBackupRestore(await encryptedFixture([], { onboardingProgress: true }), 'backup-password-2026');
    expect(progressBackup.counts.profile).toBe(1);
    await restorePreparedLocalBackup(progressBackup);
    expect(await getLocalOnboardingProgress()).toMatchObject({ status: 'in-progress', currentStep: 2 });
    expect((await createLocalBackup(familyId, 'owner')).userProfile).toMatchObject({ status: 'in-progress', currentStep: 2 });
  });

  it('détecte un conflit existant avant toute seconde écriture', async () => {
    const encrypted = await encryptedFixture();
    const first = await prepareLocalBackupRestore(encrypted, 'backup-password-2026');
    await restorePreparedLocalBackup(first);

    const second = await prepareLocalBackupRestore(encrypted, 'backup-password-2026');
    expect(second.conflicts).toContain('Transaction tx-restore-1 existe déjà');
    await expect(restorePreparedLocalBackup(second)).rejects.toThrow(/^RESTORE_CONFLICT:/);
    expect(await db.transactions.count()).toBe(2);
  });

  it('restaure les transactions importées en conservant le profil local déjà créé au questionnaire', async () => {
    const localProfile = createUserProfile(answers, new Date('2026-03-01T00:00:00.000Z'));
    await saveLocalUserProfile(localProfile);
    const encrypted = await encryptedFixture();
    const prepared = await prepareLocalBackupRestore(encrypted, 'backup-password-2026');
    expect(prepared.conflicts).toEqual([]);
    await restorePreparedLocalBackup(prepared);
    expect((await getLocalTransactions(familyId))[0]).toMatchObject({ source: 'import', label: 'Courses importées', amountCents: -1200 });
    expect((await getLocalUserProfile())?.completedAt).toBe(localProfile.completedAt);
  });

  it('remplace une progression inachevée par le profil sauvegardé uniquement après validation de l’aperçu', async () => {
    const now = new Date('2026-03-01T00:00:00.000Z').toISOString();
    const progress: OnboardingProgress = {
      id: 'primary', schemaVersion: 1, status: 'in-progress', currentStep: 1,
      startedAt: now, updatedAt: now, answers,
      dashboard: { visibleCards: [], compact: false },
    };
    await saveLocalOnboardingProgress(progress);
    const prepared = await prepareLocalBackupRestore(await encryptedFixture(), 'backup-password-2026');
    expect(prepared.profileDisposition).toBe('replace_onboarding_progress');
    expect(await restorePreparedLocalBackup(prepared)).toEqual(prepared.counts);
    expect(await getLocalOnboardingProgress()).toBeUndefined();
    expect((await getLocalUserProfile())?.completedAt).toBe('2026-01-01T00:00:00.000Z');
  });

  it('annule la restauration si la progression change après la prévisualisation', async () => {
    const now = new Date('2026-03-01T00:00:00.000Z').toISOString();
    await saveLocalOnboardingProgress({
      id: 'primary', schemaVersion: 1, status: 'in-progress', currentStep: 1,
      startedAt: now, updatedAt: now, answers,
      dashboard: { visibleCards: [], compact: false },
    });
    const prepared = await prepareLocalBackupRestore(await encryptedFixture(), 'backup-password-2026');
    await saveLocalOnboardingProgress({
      id: 'primary', schemaVersion: 1, status: 'in-progress', currentStep: 2,
      startedAt: now, updatedAt: new Date().toISOString(), answers,
      dashboard: { visibleCards: ['goals'], compact: false },
    });
    await expect(restorePreparedLocalBackup(prepared)).rejects.toThrow('RESTORE_CONFLICT:PROFILE_CHANGED_SINCE_PREVIEW');
    expect(await db.transactions.count()).toBe(0);
    expect((await getLocalOnboardingProgress())?.currentStep).toBe(2);
  });

  it('refuse un mot de passe incorrect sans écrire de donnée', async () => {
    const encrypted = await encryptedFixture();
    await expect(prepareLocalBackupRestore(encrypted, 'mauvais-mot-de-passe')).rejects.toThrow();
    expect(await db.transactions.count()).toBe(0);
  });

  it('refuse toute prévisualisation ou écriture lorsque le coffre local est verrouillé', async () => {
    const encrypted = await encryptedFixture();
    const prepared = await prepareLocalBackupRestore(encrypted, 'backup-password-2026');
    lockLocalVault();
    await expect(prepareLocalBackupRestore(encrypted, 'backup-password-2026')).rejects.toThrow('LOCAL_VAULT_LOCKED');
    await expect(restorePreparedLocalBackup(prepared)).rejects.toThrow('LOCAL_VAULT_LOCKED');
    expect(await db.transactions.count()).toBe(0);
    expect(await db.userProfiles.count()).toBe(0);
  });

  it('refuse une sauvegarde corrompue, une version inconnue et les lignes sans espace associé', async () => {
    const valid = await encryptedFixture();
    const corrupted = { ...valid, data: `${valid.data.slice(0, -3)}AAA` };
    await expect(prepareLocalBackupRestore(corrupted, 'backup-password-2026')).rejects.toThrow();
    await expect(prepareLocalBackupRestore(await encryptedFixture([], { version: '9.0' }), 'backup-password-2026'))
      .rejects.toThrow('BACKUP_VERSION_UNSUPPORTED:9.0');
    await expect(prepareLocalBackupRestore(await encryptedFixture([], { omitTransactionFamily: true }), 'backup-password-2026'))
      .rejects.toThrow('BACKUP_TRANSACTION_INVALID');
    expect(await db.transactions.count()).toBe(0);
  });

  it('annule atomiquement les écritures si une table échoue après le premier ajout', async () => {
    const prepared = await prepareLocalBackupRestore(await encryptedFixture(), 'backup-password-2026');
    const originalBulkAdd = db.budgets.bulkAdd.bind(db.budgets);
    db.budgets.bulkAdd = (() => Promise.reject(new Error('simulated budget write failure'))) as unknown as typeof db.budgets.bulkAdd;
    try {
      await expect(restorePreparedLocalBackup(prepared)).rejects.toThrow('simulated budget write failure');
    } finally {
      db.budgets.bulkAdd = originalBulkAdd;
    }
    expect(await db.transactions.count()).toBe(0);
    expect(await db.budgets.count()).toBe(0);
    expect(await db.savingGoals.count()).toBe(0);
    expect(await db.savingContributions.count()).toBe(0);
    expect(await db.syncQueue.count()).toBe(0);
    expect(await db.userProfiles.count()).toBe(0);
  });

  it('gère deux restaurations simultanées sans créer de doublon ni de restauration partielle', async () => {
    const prepared = await prepareLocalBackupRestore(await encryptedFixture(), 'backup-password-2026');
    const results = await Promise.allSettled([
      restorePreparedLocalBackup(prepared),
      restorePreparedLocalBackup(prepared),
    ]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'rejected')).toHaveLength(1);
    expect(await getLocalTransactions(familyId)).toHaveLength(1);
    expect(await getLocalBudgets(familyId)).toHaveLength(1);
    expect(await getLocalSavingGoals(familyId)).toHaveLength(1);
    expect(await getLocalSavingContributions(familyId)).toHaveLength(2);
  });

  it.each([
    ['catégories', () => encryptedFixture([{ id: 'category-1', familyId, name: 'Courses' }])],
    ['personnes', () => encryptedFixture([], { persons: [{ id: 'person-1', familyId, name: 'Alice' }] })],
    ['règles récurrentes', () => encryptedFixture([], { recurringRules: [{ id: 'recurring-1', familyId, label: 'Loyer' }] })],
  ])('refuse explicitement les %s que le stockage Web local ne sait pas conserver', async (_label, makeFixture) => {
    const encrypted = await makeFixture();
    await expect(prepareLocalBackupRestore(encrypted, 'backup-password-2026'))
      .rejects.toThrow('BACKUP_CONTENT_UNSUPPORTED_BY_LOCAL_WEB_STORAGE');
    expect(await db.transactions.count()).toBe(0);
    expect(await db.budgets.count()).toBe(0);
    expect(await db.userProfiles.count()).toBe(0);
  });
});
