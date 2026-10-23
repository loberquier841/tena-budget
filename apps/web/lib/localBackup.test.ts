import { beforeEach, describe, expect, it, vi } from 'vitest';

const stores = vi.hoisted(() => ({
  createBackup: vi.fn(),
  encryptBackup: vi.fn(),
  getLocalBudgets: vi.fn(),
  getLocalSavingContributions: vi.fn(),
  getLocalSavingGoals: vi.fn(),
  getLocalTransactions: vi.fn(),
  getLocalUserProfile: vi.fn(),
  getLocalBackupTransactions: vi.fn(),
  getLocalBackupSavingGoals: vi.fn(),
  getLocalOnboardingProgress: vi.fn(),
}));

vi.mock('@tena/core/backup/backup', () => ({
  createBackup: stores.createBackup,
  encryptBackup: stores.encryptBackup,
}));
vi.mock('@tena/core/sync/dexie', () => ({
  getLocalBudgets: stores.getLocalBudgets,
  getLocalSavingContributions: stores.getLocalSavingContributions,
  getLocalBackupSavingGoals: stores.getLocalBackupSavingGoals,
  getLocalBackupTransactions: stores.getLocalBackupTransactions,
  getLocalOnboardingProgress: stores.getLocalOnboardingProgress,
  getLocalUserProfile: stores.getLocalUserProfile,
}));

import { createEncryptedLocalBackup } from './localBackup';

describe('createEncryptedLocalBackup', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    stores.getLocalTransactions.mockResolvedValue([{ id: 'tx-imported', source: 'import', amountCents: -2450, label: 'Courses importées' }]);
    stores.getLocalBudgets.mockResolvedValue([{ id: 'budget-1' }]);
    stores.getLocalSavingGoals.mockResolvedValue([{ id: 'goal-1' }]);
    stores.getLocalSavingContributions.mockResolvedValue([{ id: 'contribution-1' }]);
    stores.getLocalUserProfile.mockResolvedValue({ id: 'primary' });
    stores.getLocalOnboardingProgress.mockResolvedValue(undefined);
    stores.getLocalBackupTransactions.mockResolvedValue([{ id: 'tx-imported', source: 'import', amountCents: -2450, label: 'Courses importées' }]);
    stores.getLocalBackupSavingGoals.mockResolvedValue([{ id: 'goal-1' }]);
    stores.createBackup.mockImplementation(async (input) => ({
      ...input,
      version: '2.0',
      createdAt: '2026-10-23T00:00:00.000Z',
      checksum: 'checksum',
    }));
    stores.encryptBackup.mockResolvedValue({ familyId: 'local-family', data: 'encrypted' });
  });

  it('uses only local records, preserves the profile and encrypts before returning counts', async () => {
    const result = await createEncryptedLocalBackup('local-family', 'password123');

    expect(stores.getLocalBackupTransactions).toHaveBeenCalledWith('local-family');
    expect(stores.getLocalBudgets).toHaveBeenCalledWith('local-family');
    expect(stores.createBackup).toHaveBeenCalledWith(expect.objectContaining({
      familyId: 'local-family',
      transactions: [{ id: 'tx-imported', source: 'import', amountCents: -2450, label: 'Courses importées' }],
      budgets: [{ id: 'budget-1' }],
      goals: [{ id: 'goal-1' }],
      savingContributions: [{ id: 'contribution-1' }],
      userProfile: { id: 'primary' },
      categories: [],
      persons: [],
      recurringRules: [],
    }), 'owner');
    expect(stores.encryptBackup).toHaveBeenCalledWith(expect.objectContaining({ checksum: 'checksum' }), 'password123');
    expect(result.counts).toEqual({ transactions: 1, deletedTransactions: 0, budgets: 1, goals: 1, contributions: 1, profile: 1 });
  });

  it('sauvegarde la progression chiffrée du questionnaire si aucun profil terminé existe', async () => {
    const progress = { id: 'primary', status: 'in-progress' };
    stores.getLocalUserProfile.mockResolvedValue(undefined);
    stores.getLocalOnboardingProgress.mockResolvedValue(progress);
    await createEncryptedLocalBackup('local-family', 'password123');
    expect(stores.createBackup).toHaveBeenCalledWith(expect.objectContaining({ userProfile: progress }), 'owner');
  });
});
