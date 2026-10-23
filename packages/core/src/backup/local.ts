import { Role, assertCan } from "../permissions/permissions";
import { BackupData, createBackup, restoreBackup } from "./backup";
import { validateOnboardingAnswers } from "../product/profile";
import { db, encodeLocalRecord, getLocalSavingContributions, getLocalBackupTransactions, getLocalBudgets, getLocalBackupSavingGoals, getLocalOnboardingProgress, getLocalUserProfile, LocalBudget, LocalSavingContribution, LocalSavingGoal, LocalTransaction, SyncQueueItem } from "../sync/dexie";

function queueItem(familyId: string, entity: SyncQueueItem["entity"], entityId: string, payload: unknown, createdAt: Date): SyncQueueItem {
  return {
    id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    familyId,
    entity,
    entityId,
    operation: "create",
    payload,
    createdAt,
    attempts: 0,
  };
}

export async function createLocalBackup(familyId: string, role: Role): Promise<BackupData> {
  assertCan(role, "budget:read");
  const [transactions, budgets, goals, contributions] = await Promise.all([
    getLocalBackupTransactions(familyId), getLocalBudgets(familyId), getLocalBackupSavingGoals(familyId), getLocalSavingContributions(familyId),
  ]);
  const [userProfile, onboardingProgress] = await Promise.all([getLocalUserProfile(), getLocalOnboardingProgress()]);

  return createBackup({
    familyId,
    transactions,
    budgets,
    categories: [],
    persons: [],
    goals,
    savingContributions: contributions,
    recurringRules: [],
    userProfile: userProfile ?? onboardingProgress,
  }, role);
}

function dateValue(value: unknown, label: string): Date {
  const date = value instanceof Date ? new Date(value) : new Date(String(value));
  if (!Number.isFinite(date.getTime())) throw new Error(`BACKUP_DATE_INVALID: ${label}`);
  return date;
}

function assertFamily(records: unknown[], familyId: string, entity: string): void {
  if (records.some((record: any) => !record || record.familyId !== familyId)) throw new Error(`BACKUP_FAMILY_MISMATCH: ${entity}`);
  const ids = records.map((record: any) => record.id);
  if (ids.some((id: unknown) => typeof id !== "string" || !id) || new Set(ids).size !== ids.length) throw new Error(`BACKUP_RECORD_INVALID: ${entity}`);
}

export async function restoreLocalBackup(backup: BackupData, familyId: string, role: Role): Promise<{
  restored: boolean;
  toCreate: { transactions: number; budgets: number; goals: number; savingContributions: number };
  conflicts: string[];
}> {
  assertCan(role, "budget:write");
  if (!backup || backup.familyId !== familyId) throw new Error("BACKUP_FAMILY_MISMATCH");
  if ((backup.categories?.length ?? 0) || (backup.persons?.length ?? 0) || (backup.recurringRules?.length ?? 0)) {
    throw new Error("BACKUP_UNSUPPORTED_DATA: this local database does not store categories, persons or recurring rules");
  }
  if (backup.userProfile && (backup.userProfile.id !== 'primary' || backup.userProfile.schemaVersion !== 1)) throw new Error('BACKUP_PROFILE_INVALID');
  if (backup.userProfile) validateOnboardingAnswers(backup.userProfile.answers);

  const transactions = backup.transactions.map((record: any) => ({
    ...record,
    bookingDate: dateValue(record.bookingDate, "transaction.bookingDate"),
    updatedAt: dateValue(record.updatedAt ?? record.bookingDate, "transaction.updatedAt"),
    isDeleted: record.isDeleted,
    deletedAt: record.deletedAt ? dateValue(record.deletedAt, "transaction.deletedAt") : undefined,
    syncStatus: "pending" as const,
  })) as LocalTransaction[];
  const budgets = backup.budgets.map((record: any) => ({
    ...record,
    updatedAt: dateValue(record.updatedAt ?? backup.createdAt, "budget.updatedAt"),
    syncStatus: "pending" as const,
  })) as LocalBudget[];
  const goals = (backup.goals ?? []).map((record: any) => ({
    ...record,
    createdAt: dateValue(record.createdAt, "goal.createdAt"),
    updatedAt: dateValue(record.updatedAt, "goal.updatedAt"),
    deletedAt: record.deletedAt ? dateValue(record.deletedAt, "goal.deletedAt") : undefined,
    syncStatus: "pending" as const,
  })) as LocalSavingGoal[];
  const contributions = (backup.savingContributions ?? []).map((record: any) => ({
    ...record,
    bookingDate: dateValue(record.bookingDate, "contribution.bookingDate"),
    syncStatus: "pending" as const,
  })) as LocalSavingContribution[];

  assertFamily(transactions, familyId, "transactions");
  assertFamily(budgets, familyId, "budgets");
  assertFamily(goals, familyId, "goals");
  assertFamily(contributions, familyId, "savingContributions");
  const goalIds = new Set(goals.map(goal => goal.id));
  if (contributions.some(contribution => !goalIds.has(contribution.goalId))) throw new Error("BACKUP_GOAL_REFERENCE_INVALID");

  const [existingTransactions, existingBudgets, existingGoals, existingContributions] = await Promise.all([
    db.transactions.where("familyId").equals(familyId).toArray(),
    db.budgets.where("familyId").equals(familyId).toArray(),
    db.savingGoals.where("familyId").equals(familyId).toArray(),
    db.savingContributions.where("familyId").equals(familyId).toArray(),
  ]);
  const existing = { transactions: existingTransactions, budgets: existingBudgets, categories: [], goals: existingGoals, savingContributions: existingContributions };
  const preview = await restoreBackup(backup, existing, role, { overwrite: false });
  if (preview.conflicts.length) return { restored: false, toCreate: { transactions: 0, budgets: 0, goals: 0, savingContributions: 0 }, conflicts: preview.conflicts };

  const timestamp = new Date();
  const queue = [
    ...transactions.map(record => queueItem(familyId, "transaction", record.id, record, timestamp)),
    ...budgets.map(record => queueItem(familyId, "budget", record.id, record, timestamp)),
    ...goals.map(record => queueItem(familyId, "savingGoal", record.id, record, timestamp)),
    ...contributions.map(record => queueItem(familyId, "savingContribution", record.id, record, timestamp)),
  ];
  const [storedTransactions, storedBudgets, storedGoals, storedContributions, storedQueue] = await Promise.all([
    Promise.all(transactions.map(record => encodeLocalRecord("transactions", record))),
    Promise.all(budgets.map(record => encodeLocalRecord("budgets", record))),
    Promise.all(goals.map(record => encodeLocalRecord("savingGoals", record))),
    Promise.all(contributions.map(record => encodeLocalRecord("savingContributions", record))),
    Promise.all(queue.map(record => encodeLocalRecord("syncQueue", record))),
  ]);
  const storedProfile = backup.userProfile ? await encodeLocalRecord('userProfiles', { id: 'primary' as const, payload: backup.userProfile }) : undefined;
  const result = await db.transaction<{ restored: boolean; conflicts: string[] }>("rw", [db.transactions, db.budgets, db.savingGoals, db.savingContributions, db.syncQueue, db.userProfiles], async () => {
    // Recheck IDs inside the write transaction to avoid racing another restore or write.
    const [txNow, budgetsNow, goalsNow, contributionsNow] = await Promise.all([
      db.transactions.where("familyId").equals(familyId).toArray(),
      db.budgets.where("familyId").equals(familyId).toArray(),
      db.savingGoals.where("familyId").equals(familyId).toArray(),
      db.savingContributions.where("familyId").equals(familyId).toArray(),
    ]);
    const conflicts = [
      ...transactions.filter(item => txNow.some(current => current.id === item.id)).map(item => `Transaction ${item.id} existe déjà`),
      ...budgets.filter(item => budgetsNow.some(current => current.id === item.id)).map(item => `Budget ${item.id} existe déjà`),
      ...goals.filter(item => goalsNow.some(current => current.id === item.id)).map(item => `Objectif ${item.id} existe déjà`),
      ...contributions.filter(item => contributionsNow.some(current => current.id === item.id)).map(item => `Versement ${item.id} existe déjà`),
    ];
    if (storedProfile && await db.userProfiles.get('primary')) conflicts.push('Un profil local existe déjà');
    if (conflicts.length) return { restored: false as const, conflicts };

    if (storedTransactions.length) await db.transactions.bulkAdd(storedTransactions);
    if (storedBudgets.length) await db.budgets.bulkAdd(storedBudgets);
    if (storedGoals.length) await db.savingGoals.bulkAdd(storedGoals);
    if (storedContributions.length) await db.savingContributions.bulkAdd(storedContributions);
    if (storedQueue.length) await db.syncQueue.bulkAdd(storedQueue);
    if (storedProfile) await db.userProfiles.add(storedProfile);
    return { restored: true as const, conflicts: [] as string[] };
  });

  if (!result.restored) return { restored: false, toCreate: { transactions: 0, budgets: 0, goals: 0, savingContributions: 0 }, conflicts: result.conflicts };
  return {
    restored: true,
    toCreate: { transactions: transactions.length, budgets: budgets.length, goals: goals.length, savingContributions: contributions.length },
    conflicts: [],
  };
}
