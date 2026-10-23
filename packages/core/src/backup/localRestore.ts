import { decryptBackup, restoreBackup, type BackupData, type EncryptedBackup } from './backup';
import { isLocalVaultUnlocked } from '../localVault';
import { validateOnboardingAnswers } from '../product/profile';
import {
  db,
  decodeLocalRecord,
  encodeLocalRecord,
  type LocalBudget,
  type LocalSavingContribution,
  type LocalSavingGoal,
  type LocalTransaction,
  type SyncQueueItem,
} from '../sync/dexie';

export interface PreparedLocalRestore {
  backup: BackupData;
  conflicts: string[];
  profileDisposition: 'none' | 'add_backup_profile' | 'keep_local_profile' | 'replace_onboarding_progress';
  expectedProfilePayload: string | null;
  counts: { transactions: number; deletedTransactions: number; budgets: number; goals: number; contributions: number; profile: number };
}

function requireUniqueIds(records: any[] | undefined, label: string): void {
  const seen = new Set<string>();
  for (const record of records ?? []) {
    if (!record || typeof record.id !== 'string' || !record.id.trim()) {
      throw new Error(`BACKUP_RECORD_ID_INVALID:${label}`);
    }
    if (!seen.add(record.id)) throw new Error(`BACKUP_DUPLICATE_ID:${label}:${record.id}`);
  }
}

function parseDate(value: unknown, field: string): Date {
  const date = value instanceof Date ? value : new Date(String(value ?? ''));
  if (!Number.isFinite(date.getTime())) throw new Error(`BACKUP_DATE_INVALID:${field}`);
  return date;
}

function validateBackupShape(backup: BackupData): void {
  if (!backup || typeof backup.familyId !== 'string' || !backup.familyId.trim() ||
      !Array.isArray(backup.transactions) || !Array.isArray(backup.budgets) ||
      !Array.isArray(backup.categories)) throw new Error('BACKUP_FORMAT_INVALID');
  if (backup.version !== '2.0') throw new Error(`BACKUP_VERSION_UNSUPPORTED:${String(backup.version)}`);

  if ((backup.categories?.length ?? 0) > 0 || (backup.persons?.length ?? 0) > 0 ||
      (backup.recurringRules?.length ?? 0) > 0) {
    throw new Error('BACKUP_CONTENT_UNSUPPORTED_BY_LOCAL_WEB_STORAGE');
  }

  requireUniqueIds(backup.transactions, 'transactions');
  requireUniqueIds(backup.budgets, 'budgets');
  requireUniqueIds(backup.goals, 'goals');
  requireUniqueIds(backup.savingContributions, 'savingContributions');

  const goalIds = new Set((backup.goals ?? []).map((goal: any) => goal.id));
  for (const transaction of backup.transactions as any[]) {
    if (transaction.familyId !== backup.familyId || typeof transaction.label !== 'string' || !Number.isSafeInteger(transaction.amountCents) ||
        transaction.amountCents === 0 || typeof transaction.isDeleted !== 'boolean' || !transaction.id ||
        (transaction.source != null && !['manual', 'import', 'bank'].includes(transaction.source))) {
      throw new Error('BACKUP_TRANSACTION_INVALID');
    }
    parseDate(transaction.bookingDate, 'bookingDate');
    if (transaction.deletedAt != null) parseDate(transaction.deletedAt, 'deletedAt');
  }
  for (const budget of backup.budgets as any[]) {
    if (budget.familyId !== backup.familyId || !Number.isSafeInteger(budget.amountCents) || !Number.isInteger(budget.year) || !budget.id) {
      throw new Error('BACKUP_BUDGET_INVALID');
    }
    if (budget.month != null && (!Number.isInteger(budget.month) || budget.month < 1 || budget.month > 12)) {
      throw new Error('BACKUP_BUDGET_PERIOD_INVALID');
    }
  }
  for (const goal of backup.goals ?? []) {
    if (!goal || goal.familyId !== backup.familyId || typeof goal.name !== 'string' || !goal.name.trim() ||
        !Number.isSafeInteger(goal.targetCents) || goal.targetCents <= 0 ||
        !Number.isSafeInteger(goal.currentCents) || goal.currentCents < 0 || typeof goal.isDeleted !== 'boolean') {
      throw new Error('BACKUP_GOAL_INVALID');
    }
    parseDate(goal.createdAt, 'goal.createdAt');
    parseDate(goal.updatedAt, 'goal.updatedAt');
    if (goal.deletedAt != null) parseDate(goal.deletedAt, 'goal.deletedAt');
  }
  for (const contribution of backup.savingContributions ?? []) {
    if (!contribution || contribution.familyId !== backup.familyId || !goalIds.has(contribution.goalId) ||
        !Number.isSafeInteger(contribution.amountCents) || contribution.amountCents === 0 ||
        typeof contribution.createdByUserId !== 'string') throw new Error('BACKUP_CONTRIBUTION_INVALID');
    parseDate(contribution.bookingDate, 'contribution.bookingDate');
  }
  if (backup.userProfile) {
    const profile = backup.userProfile as any;
    const validProgress = profile.status === 'in-progress' && typeof profile.startedAt === 'string' &&
      Number.isFinite(Date.parse(profile.startedAt)) && Number.isInteger(profile.currentStep) &&
      profile.currentStep >= 0 && profile.currentStep <= 4;
    const validCompletedProfile = typeof profile.createdAt === 'string' && Number.isFinite(Date.parse(profile.createdAt)) &&
      typeof profile.completedAt === 'string' && Number.isFinite(Date.parse(profile.completedAt));
    if (profile.id !== 'primary' || profile.schemaVersion !== 1 ||
        typeof profile.updatedAt !== 'string' || !Number.isFinite(Date.parse(profile.updatedAt)) ||
        (!validProgress && !validCompletedProfile) ||
        !profile.dashboard || typeof profile.dashboard.compact !== 'boolean' || !Array.isArray(profile.dashboard.visibleCards)) {
      throw new Error('PROFILE_SCHEMA_UNSUPPORTED');
    }
    try { validateOnboardingAnswers(profile.answers); }
    catch { throw new Error('PROFILE_SCHEMA_UNSUPPORTED'); }
  }
}

async function readExistingBackupRows(familyId: string) {
  const [transactionRows, budgetRows, goalRows, contributionRows, userProfileRecord] = await Promise.all([
    db.transactions.where('familyId').equals(familyId).toArray(),
    db.budgets.where('familyId').equals(familyId).toArray(),
    db.savingGoals.where('familyId').equals(familyId).toArray(),
    db.savingContributions.where('familyId').equals(familyId).toArray(),
    db.userProfiles.get('primary'),
  ]);
  const [transactions, budgets, goals, savingContributions] = await Promise.all([
    Promise.all(transactionRows.map((row) => decodeLocalRecord('transactions', row))),
    Promise.all(budgetRows.map((row) => decodeLocalRecord('budgets', row))),
    Promise.all(goalRows.map((row) => decodeLocalRecord('savingGoals', row))),
    Promise.all(contributionRows.map((row) => decodeLocalRecord('savingContributions', row))),
  ]);
  const userProfile = userProfileRecord
    ? (await decodeLocalRecord('userProfiles', userProfileRecord)).payload
    : undefined;
  return { transactions, budgets, categories: [], goals, savingContributions, userProfile, userProfileRecord };
}

async function preflight(backup: BackupData): Promise<{
  conflicts: string[];
  profileDisposition: PreparedLocalRestore['profileDisposition'];
  expectedProfilePayload: string | null;
}> {
  validateBackupShape(backup);
  const existing = await readExistingBackupRows(backup.familyId);
  const result = await restoreBackup(backup, existing, 'owner', { overwrite: false });
  let profileDisposition: PreparedLocalRestore['profileDisposition'] = 'none';
  if (backup.userProfile) {
    const localProfile = existing.userProfile;
    if (!localProfile) profileDisposition = 'add_backup_profile';
    else if (typeof localProfile === 'object' && 'status' in localProfile && localProfile.status === 'in-progress') profileDisposition = 'replace_onboarding_progress';
    else profileDisposition = 'keep_local_profile';
  }
  const profilePayload = existing.userProfileRecord?.payload;
  return {
    conflicts: [...result.conflicts],
    profileDisposition,
    expectedProfilePayload: profilePayload === undefined ? null : JSON.stringify(profilePayload),
  };
}

export async function prepareLocalBackupRestore(payload: unknown, password: string): Promise<PreparedLocalRestore> {
  if (!isLocalVaultUnlocked()) throw new Error('LOCAL_VAULT_LOCKED');
  if (!payload || typeof payload !== 'object') throw new Error('BACKUP_FORMAT_INVALID');
  const backup = await decryptBackup(payload as EncryptedBackup, password);
  const { conflicts, profileDisposition, expectedProfilePayload } = await preflight(backup);
  return {
    backup,
    conflicts,
    profileDisposition,
    expectedProfilePayload,
    counts: {
      transactions: backup.transactions.length,
      deletedTransactions: backup.transactions.filter((row: any) => row.isDeleted).length,
      budgets: backup.budgets.length,
      goals: backup.goals?.length ?? 0,
      contributions: backup.savingContributions?.length ?? 0,
      profile: backup.userProfile ? 1 : 0,
    },
  };
}

export async function restorePreparedLocalBackup(prepared: PreparedLocalRestore): Promise<PreparedLocalRestore['counts']> {
  if (!isLocalVaultUnlocked()) throw new Error('LOCAL_VAULT_LOCKED');
  const { backup } = prepared;
  const check = await preflight(backup);
  if (check.conflicts.length) throw new Error(`RESTORE_CONFLICT:${check.conflicts.join(', ')}`);
  if (check.profileDisposition !== prepared.profileDisposition || check.expectedProfilePayload !== prepared.expectedProfilePayload) {
    throw new Error('RESTORE_CONFLICT:PROFILE_CHANGED_SINCE_PREVIEW');
  }

  const now = new Date();
  const transactions: LocalTransaction[] = (backup.transactions as any[]).map((row) => ({
    ...row,
    bookingDate: parseDate(row.bookingDate, 'bookingDate'),
    createdAt: row.createdAt ? parseDate(row.createdAt, 'createdAt') : parseDate(row.bookingDate, 'bookingDate'),
    updatedAt: row.updatedAt ? parseDate(row.updatedAt, 'updatedAt') : now,
    deletedAt: row.deletedAt ? parseDate(row.deletedAt, 'deletedAt') : undefined,
    source: row.source ?? 'manual',
    syncStatus: 'pending',
  }));
  const budgets: LocalBudget[] = (backup.budgets as any[]).map((row) => ({
    ...row,
    updatedAt: row.updatedAt ? parseDate(row.updatedAt, 'budget.updatedAt') : now,
    syncStatus: 'pending',
  }));
  const goals: LocalSavingGoal[] = (backup.goals ?? []).map((row: any) => ({
    ...row,
    createdAt: parseDate(row.createdAt, 'goal.createdAt'),
    updatedAt: parseDate(row.updatedAt, 'goal.updatedAt'),
    deletedAt: row.deletedAt ? parseDate(row.deletedAt, 'goal.deletedAt') : undefined,
    syncStatus: 'pending',
  }));
  const goalIds = new Set(goals.map((goal) => goal.id));
  const contributions: LocalSavingContribution[] = (backup.savingContributions ?? []).map((row: any) => ({
    ...row,
    familyId: backup.familyId,
    bookingDate: parseDate(row.bookingDate, 'contribution.bookingDate'),
    syncStatus: 'pending',
  }));
  if (contributions.some((row) => !goalIds.has(row.goalId))) throw new Error('BACKUP_CONTRIBUTION_INVALID');

  const queueItems: SyncQueueItem[] = [
    ...transactions.map((row) => ({ entity: 'transaction' as const, entityId: row.id, payload: row })),
    ...budgets.map((row) => ({ entity: 'budget' as const, entityId: row.id, payload: row })),
    ...goals.map((row) => ({ entity: 'savingGoal' as const, entityId: row.id, payload: row })),
    ...contributions.map((row) => ({ entity: 'savingContribution' as const, entityId: row.id, payload: row })),
  ].map((item, index) => ({
    id: `sync_restore_${Date.now()}_${index}_${crypto.randomUUID()}`,
    familyId: backup.familyId,
    entity: item.entity,
    entityId: item.entityId,
    operation: 'create' as const,
    payload: item.payload,
    createdAt: now,
    attempts: 0,
  }));

  const [storedTransactions, storedBudgets, storedGoals, storedContributions, storedQueue, storedProfile] = await Promise.all([
    Promise.all(transactions.map((row) => encodeLocalRecord('transactions', row))),
    Promise.all(budgets.map((row) => encodeLocalRecord('budgets', row))),
    Promise.all(goals.map((row) => encodeLocalRecord('savingGoals', row))),
    Promise.all(contributions.map((row) => encodeLocalRecord('savingContributions', row))),
    Promise.all(queueItems.map((row) => encodeLocalRecord('syncQueue', row))),
    backup.userProfile
      ? encodeLocalRecord('userProfiles', { id: 'primary' as const, payload: backup.userProfile })
      : Promise.resolve(undefined),
  ]);

  await db.transaction(
    'rw', [db.transactions, db.budgets, db.savingGoals, db.savingContributions, db.syncQueue, db.userProfiles],
    async () => {
      if (storedTransactions.length) await db.transactions.bulkAdd(storedTransactions);
      if (storedBudgets.length) await db.budgets.bulkAdd(storedBudgets);
      if (storedGoals.length) await db.savingGoals.bulkAdd(storedGoals);
      if (storedContributions.length) await db.savingContributions.bulkAdd(storedContributions);
      if (storedQueue.length) await db.syncQueue.bulkAdd(storedQueue);
      if (storedProfile) {
        const currentProfile = await db.userProfiles.get('primary');
        const currentPayload = currentProfile?.payload;
        if ((currentPayload === undefined ? null : JSON.stringify(currentPayload)) !== prepared.expectedProfilePayload) {
          throw new Error('RESTORE_CONFLICT:PROFILE_CHANGED_SINCE_PREVIEW');
        }
        if (prepared.profileDisposition === 'add_backup_profile' && !currentProfile) await db.userProfiles.add(storedProfile);
        if (prepared.profileDisposition === 'replace_onboarding_progress' && currentProfile) await db.userProfiles.put(storedProfile);
      }
    },
  );
  return prepared.counts;
}
