import { createBackup, encryptBackup } from '@tena/core/backup/backup';
export { prepareLocalBackupRestore, restorePreparedLocalBackup, type PreparedLocalRestore } from '@tena/core/backup/localRestore';
import {
  getLocalBackupSavingGoals,
  getLocalBackupTransactions,
  getLocalBudgets,
  getLocalSavingContributions,
  getLocalOnboardingProgress,
  getLocalUserProfile,
} from '@tena/core/sync/dexie';

export async function createEncryptedLocalBackup(familyId: string, password: string) {
  const [transactions, budgets, goals, contributions, userProfile, onboardingProgress] = await Promise.all([
    getLocalBackupTransactions(familyId),
    getLocalBudgets(familyId),
    getLocalBackupSavingGoals(familyId),
    getLocalSavingContributions(familyId),
    getLocalUserProfile(),
    getLocalOnboardingProgress(),
  ]);

  const backup = await createBackup({
    familyId,
    transactions,
    budgets,
    categories: [],
    persons: [],
    goals,
    savingContributions: contributions,
    recurringRules: [],
    userProfile: userProfile ?? onboardingProgress,
  }, 'owner');

  return {
    encrypted: await encryptBackup(backup, password),
    counts: {
      transactions: backup.transactions.length,
      deletedTransactions: backup.transactions.filter((transaction: any) => transaction.isDeleted).length,
      budgets: backup.budgets.length,
      goals: backup.goals.length,
      contributions: backup.savingContributions?.length ?? 0,
      profile: backup.userProfile ? 1 : 0,
    },
  };
}
