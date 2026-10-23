import Dexie, { Table } from 'dexie';
import type { SavingContribution, SavingGoal } from '../budget/savings';
import { restoreTransaction, softDeleteTransaction, type Transaction } from '../budget/transaction';
import type { Role } from '../permissions/permissions';
import type { OnboardingProgress, UserProfile } from '../product/profile';
import { activateLocalVault, createLocalVault, decryptLocalValue, encryptLocalValue, isEncryptedLocalValue, LocalVaultMetadata, lockLocalVault, unlockLocalVault } from '../localVault';

export interface LocalTransaction {
  id: string;
  familyId: string;
  userId: string; // AJOUT: isolateur multi-utilisateurs
  amountCents: number;
  bookingDate: Date;
  label: string;
  categoryId?: string;
  personId?: string;
  isDeleted: boolean;
  deletedAt?: Date;
  createdAt?: Date;
  createdByUserId?: string;
  syncStatus: 'synced' | 'pending' | 'conflict';
  updatedAt: Date;
}

export interface LocalBudget {
  id: string;
  familyId: string;
  userId: string; // AJOUT: isolateur multi-utilisateurs
  amountCents: number;
  year: number;
  month?: number;
  categoryId?: string;
  personId?: string;
  syncStatus: 'synced' | 'pending' | 'conflict';
  updatedAt: Date;
}

export interface LocalSavingGoal extends SavingGoal {
  syncStatus: 'synced' | 'pending' | 'conflict';
  userId: string; // AJOUT: isolateur multi-utilisateurs
}

export interface LocalSavingContribution extends SavingContribution {
  familyId: string;
  syncStatus: 'synced' | 'pending' | 'conflict';
  userId: string; // AJOUT: isolateur multi-utilisateurs
}

export interface SyncQueueItem {
  id: string;
  familyId: string;
  entity: 'transaction' | 'budget' | 'category' | 'savingGoal' | 'savingContribution';
  entityId: string;
  operation: 'create' | 'update' | 'delete';
  payload: any;
  createdAt: Date;
  attempts: number;
}

export interface ConflictLog {
  id: string;
  familyId: string;
  entity: string;
  entityId: string;
  localVersion: any;
  serverVersion: any;
  resolvedAt?: Date;
  resolution: 'local_wins' | 'server_wins' | 'manual' | 'pending';
}

export interface LocalUserProfileRecord { id: 'primary'; payload: UserProfile | OnboardingProgress }

const encryptedFields: Record<string, string[]> = {
  transactions: ['amountCents', 'bookingDate', 'label', 'categoryId', 'personId', 'deletedAt', 'createdAt', 'createdByUserId', 'userId'],
  budgets: ['amountCents', 'categoryId', 'personId', 'userId'],
  savingGoals: ['personId', 'name', 'targetCents', 'currentCents', 'deletedAt', 'userId'],
  savingContributions: ['goalId', 'amountCents', 'bookingDate', 'note', 'createdByUserId', 'userId'],
  syncQueue: ['entity', 'entityId', 'operation', 'payload'],
  conflicts: ['entity', 'entityId', 'localVersion', 'serverVersion'],
  userProfiles: ['payload'],
};

const dateFields: Record<string, string[]> = {
  transactions: ['bookingDate', 'deletedAt', 'createdAt'],
  savingGoals: ['deletedAt'],
  savingContributions: ['bookingDate'],
};

export async function encodeLocalRecord<T extends Record<string, any>>(tableName: keyof typeof encryptedFields, record: T): Promise<T> {
  const encoded: Record<string, any> = { ...record };
  for (const field of encryptedFields[tableName] ?? []) {
    const value = encoded[field];
    if (value === undefined || value === null || isEncryptedLocalValue(value)) continue;
    encoded[field] = await encryptLocalValue(value, `${tableName}:${String(record.id)}:${field}`);
  }
  return encoded as T;
}

export async function decodeLocalRecord<T extends Record<string, any>>(tableName: keyof typeof encryptedFields, record: T): Promise<T> {
  const decoded: Record<string, any> = { ...record };
  for (const field of encryptedFields[tableName] ?? []) {
    const value = decoded[field];
    if (!isEncryptedLocalValue(value)) continue;
    decoded[field] = await decryptLocalValue(value, `${tableName}:${String(record.id)}:${field}`);
    if (dateFields[tableName]?.includes(field) && decoded[field] != null) decoded[field] = new Date(decoded[field]);
  }
  return decoded as T;
}

class TenaDatabase extends Dexie {
  transactions!: Table<LocalTransaction>;
  budgets!: Table<LocalBudget>;
  savingGoals!: Table<LocalSavingGoal>;
  savingContributions!: Table<LocalSavingContribution>;
  syncQueue!: Table<SyncQueueItem>;
  conflicts!: Table<ConflictLog>;
  vaultMetadata!: Table<LocalVaultMetadata>;
  userProfiles!: Table<LocalUserProfileRecord>;

  constructor() {
    super('TenaBudgetDB');
    this.version(1).stores({
      transactions: 'id, familyId, personId, categoryId, bookingDate, syncStatus, updatedAt',
      budgets: 'id, familyId, personId, categoryId, year, syncStatus',
      syncQueue: 'id, familyId, entity, entityId, createdAt',
      conflicts: 'id, familyId, entity, entityId, resolution',
    });
    this.version(2).stores({
      transactions: 'id, familyId, personId, categoryId, bookingDate, syncStatus, updatedAt',
      budgets: 'id, familyId, personId, categoryId, year, syncStatus',
      savingGoals: 'id, familyId, personId, isArchived, isDeleted, syncStatus, updatedAt',
      savingContributions: 'id, familyId, goalId, bookingDate, syncStatus',
      syncQueue: 'id, familyId, entity, entityId, createdAt',
      conflicts: 'id, familyId, entity, entityId, resolution',
    });
    this.version(3).stores({
      transactions: 'id, familyId, syncStatus, updatedAt, isDeleted',
      budgets: 'id, familyId, year, syncStatus',
      savingGoals: 'id, familyId, isArchived, isDeleted, syncStatus, updatedAt',
      savingContributions: 'id, familyId, syncStatus',
      syncQueue: 'id, familyId, createdAt',
      conflicts: 'id, familyId, resolution',
      vaultMetadata: 'id',
    });
    this.version(4).stores({
      transactions: 'id, familyId, syncStatus, updatedAt, isDeleted',
      budgets: 'id, familyId, year, syncStatus',
      savingGoals: 'id, familyId, isArchived, isDeleted, syncStatus, updatedAt',
      savingContributions: 'id, familyId, syncStatus',
      syncQueue: 'id, familyId, createdAt',
      conflicts: 'id, familyId, resolution',
      vaultMetadata: 'id',
      userProfiles: 'id',
    });
    this.version(5).stores({
      transactions: 'id, familyId, userId, amountCents, bookingDate, label, categoryId, personId, isDeleted, deletedAt, createdAt, createdByUserId, syncStatus, updatedAt',
      budgets: 'id, familyId, userId, amountCents, year, month, categoryId, personId, syncStatus, updatedAt',
      savingGoals: 'id, familyId, userId, isArchived, isDeleted, targetCents, currentCents, syncStatus, updatedAt',
      savingContributions: 'id, familyId, goalId, amountCents, bookingDate, note, syncStatus',
      syncQueue: 'id, familyId, entity, entityId, createdAt',
      conflicts: 'id, familyId, entity, entityId, resolution',
      vaultMetadata: 'id',
      userProfiles: 'id',
    });
  }
}

export const db = new TenaDatabase();

// Fonctions de persistance Dexie avec chiffrement

export async function getLocalTransactions(familyId: string): Promise<LocalTransaction[]> {
  const rows = await db.transactions.where('familyId').equals(familyId).toArray();
  const transactions = await Promise.all(rows.map(row => decodeLocalRecord('transactions', row)));
  return transactions.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
}

export async function getLocalBudgets(familyId: string): Promise<LocalBudget[]> {
  const rows = await db.budgets.where('familyId').equals(familyId).toArray();
  const budgets = await Promise.all(rows.map(row => decodeLocalRecord('budgets', row)));
  return budgets.sort((a, b) => b.year - a.year || (b.month ?? 0) - (a.month ?? 0));
}

export async function saveLocalBudget(budget: LocalBudget): Promise<void> {
  const existing = await db.budgets.get(budget.id);
  const timestamp = new Date();
  const saved = { ...budget, userId: budget.userId || 'primary', syncStatus: 'pending' as const, updatedAt: timestamp };

  const [stored, queue] = await Promise.all([
    encodeLocalRecord('budgets', saved),
    encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: budget.familyId,
      entity: 'budget',
      entityId: budget.id,
      operation: existing ? 'update' : 'create',
      payload: saved,
      createdAt: timestamp,
      attempts: 0,
    }),
  ]);
  await db.transaction('rw', db.budgets, db.syncQueue, async () => {
    await db.budgets.put(stored);
    await db.syncQueue.add(queue);
  });
}

export async function saveLocalTransaction(tx: LocalTransaction): Promise<void> {
  const timestamp = new Date();
  const saved = { ...tx, userId: tx.userId || 'primary', syncStatus: 'pending' as const, updatedAt: timestamp };
  const [stored, queue] = await Promise.all([
    encodeLocalRecord('transactions', saved),
    encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: tx.familyId,
      entity: 'transaction',
      entityId: tx.id,
      operation: tx.isDeleted ? 'delete' : 'create',
      payload: saved,
      createdAt: timestamp,
      attempts: 0,
    }),
  ]);
  await db.transaction('rw', db.transactions, db.syncQueue, async () => {
    await db.transactions.put(stored);
    await db.syncQueue.add(queue);
  });
}

export async function softDeleteTransaction(tx: LocalTransaction, familyId: string, role: Role): Promise<LocalTransaction> {
  // Marquer comme supprimée côté Dexie (le soft delete logique est aussi dans transaction.ts)
  const updated = { ...tx, isDeleted: true, deletedAt: new Date(), updatedAt: new Date(), syncStatus: 'pending' };
  await saveLocalTransaction(updated);
  return updated;
}

export function restoreTransaction(tx: Transaction, familyId: string, role: Role): Transaction {
  // La logique de restauration est dans transaction.ts, mais on marque aussi en Dexie
  // ... implementation depends on the specific use case
  return tx;
}

export async function getLocalSavingGoals(familyId: string): Promise<LocalSavingGoal[]> {
  const rows = await db.savingGoals.where('familyId').equals(familyId).toArray();
  const goals = await Promise.all(rows.map(row => decodeLocalRecord('savingGoals', row)));
  return goals.filter(goal => !goal.isDeleted).sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
}

export async function saveLocalSavingGoal(goal: SavingGoal, contribution?: { amountCents: number; note?: string; createdByUserId: string }): Promise<void> {
  const timestamp = new Date();
  const saved: LocalSavingGoal = { ...goal, userId: goal.userId || 'primary', syncStatus: 'pending', updatedAt: timestamp };
  const savedContribution: { familyId: string; amountCents: number; note?: string; createdByUserId: string; syncStatus: string } | undefined = contribution ? {
    familyId: goal.familyId,
    amountCents: contribution.amountCents,
    note: contribution.note,
    createdByUserId: contribution.createdByUserId,
    syncStatus: 'pending',
  } : undefined;
  const [storedGoal, storedContribution, goalQueue, contributionQueue] = await Promise.all([
    encodeLocalRecord('savingGoals', saved),
    savedContribution ? encodeLocalRecord('savingContributions', savedContribution) : Promise.resolve(undefined),
    encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: goal.familyId,
      entity: 'savingGoal',
      entityId: goal.id,
      operation: existing ? 'update' : 'create',
      payload: saved,
      createdAt: timestamp,
      attempts: 0,
    }),
    savedContribution ? encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: goal.familyId,
      entity: 'savingContribution',
      entityId: contribution.id,
      operation: 'create',
      payload: savedContribution,
      createdAt: timestamp,
      attempts: 0,
    }) : Promise.resolve(undefined),
  ]);
  await db.transaction('rw', db.savingGoals, db.savingContributions, db.syncQueue, async () => {
    await db.savingGoals.put(storedGoal);
    if (storedContribution && contributionQueue) {
      await db.savingContributions.put(storedContribution);
      await db.syncQueue.add(contributionQueue);
    }
    await db.syncQueue.add(goalQueue);
  });
}

export async function getLocalUserProfile(): Promise<UserProfile | undefined> {
  const rows = await db.userProfiles.where('id').equals('primary').toArray();
  if (rows.length === 0) return undefined;
  const record = rows[0];
  const payload = await decodeLocalRecord<UserProfile | OnboardingProgress>('userProfiles', record);
  return payload.id === 'primary' ? (payload as UserProfile) : undefined;
}

export async function saveLocalUserProfile(profile: UserProfile): Promise<void> {
  const timestamp = new Date();
  const record = await encodeLocalRecord('userProfiles', { id: 'primary', payload: profile });
  await db.userProfiles.put({ id: 'primary', payload: profile, updatedAt: timestamp });
}

export async function saveLocalOnboardingProgress(progress: { id: string; schemaVersion: number; status: string; currentStep: number; startedAt: string; updatedAt: string; answers: OnboardingProgress['answers']; dashboard: OnboardingProgress['dashboard'] }): Promise<void> {
  const timestamp = new Date();
  await db.onboardingProgress ? db.onboardingProgress.put({ ...progress, updatedAt: timestamp }) : '';
  // Note: cette table peut ne pas exister dans toutes les versions
}

export async function getLocalOnboardingProgress(): Promise<{ id: string; schemaVersion: number; status: string; currentStep: number; startedAt: string; updatedAt: string; answers: OnboardingProgress['answers']; dashboard: OnboardingProgress['dashboard'] } | undefined> {
  try {
    const rows = await db.onboardingProgress?.where('id').equals('primary')?.toArray();
    if (!rows || rows.length === 0) return undefined;
    return rows[0];
  } catch {
    return undefined;
  }
}
