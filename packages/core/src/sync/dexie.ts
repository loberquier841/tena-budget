
import Dexie, { Table } from 'dexie';
import type { SavingContribution, SavingGoal } from '../budget/savings';
import { restoreTransaction, softDeleteTransaction, type Transaction } from '../budget/transaction';
import type { Role } from '../permissions/permissions';
import type { OnboardingProgress, UserProfile } from '../product/profile';
import { activateLocalVault, createLocalVault, decryptLocalValue, encryptLocalValue, isEncryptedLocalValue, LocalVaultMetadata, lockLocalVault, unlockLocalVault } from '../localVault';

export interface LocalTransaction {
  id: string;
  familyId: string;
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
}

export interface LocalSavingContribution extends SavingContribution {
  familyId: string;
  syncStatus: 'synced' | 'pending' | 'conflict';
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
  transactions: ['amountCents', 'bookingDate', 'label', 'categoryId', 'personId', 'deletedAt', 'createdAt', 'createdByUserId'],
  budgets: ['amountCents', 'categoryId', 'personId'],
  savingGoals: ['personId', 'name', 'targetCents', 'currentCents', 'deletedAt'],
  savingContributions: ['goalId', 'amountCents', 'bookingDate', 'note', 'createdByUserId'],
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
  }
}

export const db = new TenaDatabase();

export interface LocalVaultStatus {
  configured: boolean;
  migrationComplete: boolean;
  hasExistingData: boolean;
}

export async function getLocalVaultStatus(): Promise<LocalVaultStatus> {
  const metadata = await db.vaultMetadata.get('primary');
  const counts = await Promise.all([db.transactions.count(), db.budgets.count(), db.savingGoals.count(), db.savingContributions.count(), db.syncQueue.count(), db.conflicts.count(), db.userProfiles.count()]);
  return { configured: Boolean(metadata), migrationComplete: metadata?.migrationState === 'complete', hasExistingData: counts.some(count => count > 0) };
}

async function migrateTable<T extends { id: string }>(tableName: keyof typeof encryptedFields, table: Table<T>): Promise<void> {
  const records = await table.toArray();
  for (const record of records) {
    const encoded = await encodeLocalRecord(tableName, record as T & Record<string, any>);
    await table.put(encoded);
  }
}

export async function migrateLocalDatabase(): Promise<void> {
  const metadata = await db.vaultMetadata.get('primary');
  if (!metadata) throw new Error('LOCAL_VAULT_NOT_CONFIGURED');
  if (metadata.migrationState === 'complete') return;
  await migrateTable('transactions', db.transactions);
  await migrateTable('budgets', db.budgets);
  await migrateTable('savingGoals', db.savingGoals);
  await migrateTable('savingContributions', db.savingContributions);
  await migrateTable('syncQueue', db.syncQueue);
  await migrateTable('conflicts', db.conflicts);
  await db.vaultMetadata.put({ ...metadata, migrationState: 'complete' });
}

export async function createLocalVaultAndMigrate(passphrase: string): Promise<void> {
  if (await db.vaultMetadata.get('primary')) throw new Error('LOCAL_VAULT_ALREADY_CONFIGURED');
  const { metadata, key } = await createLocalVault(passphrase);
  await db.vaultMetadata.put(metadata);
  activateLocalVault(key);
  await migrateLocalDatabase();
}

export async function unlockLocalDatabase(passphrase: string): Promise<void> {
  const metadata = await db.vaultMetadata.get('primary');
  if (!metadata) throw new Error('LOCAL_VAULT_NOT_CONFIGURED');
  const key = await unlockLocalVault(metadata, passphrase);
  activateLocalVault(key);
  await migrateLocalDatabase();
}

export function lockLocalDatabase(): void { lockLocalVault(); }

async function getDecrypted<T extends Record<string, any>>(tableName: keyof typeof encryptedFields, table: Table<any>, id: string): Promise<T | undefined> {
  const record = await table.get(id);
  return record ? decodeLocalRecord(tableName, record) : undefined;
}

export async function getLocalSavingContributions(familyId: string): Promise<LocalSavingContribution[]> {
  const records = await db.savingContributions.where('familyId').equals(familyId).toArray();
  return Promise.all(records.map(record => decodeLocalRecord('savingContributions', record)));
}

export async function getLocalSyncQueue(familyId: string): Promise<SyncQueueItem[]> {
  const rows = await db.syncQueue.where('familyId').equals(familyId).toArray();
  return Promise.all(rows.map(row => decodeLocalRecord('syncQueue', row)));
}

export async function getLocalConflicts(familyId: string): Promise<ConflictLog[]> {
  const rows = await db.conflicts.where('familyId').equals(familyId).toArray();
  return Promise.all(rows.map(row => decodeLocalRecord('conflicts', row)));
}

export async function getLocalConflict(id: string): Promise<ConflictLog | undefined> {
  return getDecrypted<ConflictLog>('conflicts', db.conflicts, id);
}

export async function putLocalConflict(conflict: ConflictLog): Promise<void> {
  await db.conflicts.add(await encodeLocalRecord('conflicts', conflict));
}

export async function putLocalSyncQueueItem(item: SyncQueueItem): Promise<void> {
  await db.syncQueue.add(await encodeLocalRecord('syncQueue', item));
}

export async function updateLocalSyncQueueAttempts(id: string, attempts: number): Promise<void> {
  await db.syncQueue.update(id, { attempts });
}

export async function removeLocalSyncQueueItem(id: string): Promise<void> {
  await db.syncQueue.delete(id);
}

export async function updateLocalEntitySyncStatus(entity: SyncQueueItem['entity'], id: string, syncStatus: 'synced' | 'conflict'): Promise<void> {
  const table = entity === 'transaction' ? db.transactions : entity === 'savingGoal' ? db.savingGoals : entity === 'savingContribution' ? db.savingContributions : undefined;
  const tableName = entity === 'transaction' ? 'transactions' : entity === 'savingGoal' ? 'savingGoals' : entity === 'savingContribution' ? 'savingContributions' : undefined;
  if (!table || !tableName) return;
  const record = await table.get(id);
  if (!record) return;
  const decoded = await decodeLocalRecord(tableName, record as any);
  await table.put(await encodeLocalRecord(tableName, { ...decoded, syncStatus }) as any);
}

export async function updateLocalConflict(conflict: ConflictLog): Promise<void> {
  await db.conflicts.put(await encodeLocalRecord('conflicts', conflict));
}

export async function getLocalUserProfile(): Promise<UserProfile | undefined> {
  const record = await db.userProfiles.get('primary');
  if (!record) return undefined;
  const payload = (await decodeLocalRecord('userProfiles', record)).payload;
  return 'completedAt' in payload ? payload : undefined;
}

export async function getLocalOnboardingProgress(): Promise<OnboardingProgress | undefined> {
  const record = await db.userProfiles.get('primary');
  if (!record) return undefined;
  const payload = (await decodeLocalRecord('userProfiles', record)).payload;
  return 'status' in payload && payload.status === 'in-progress' ? payload : undefined;
}

export async function saveLocalOnboardingProgress(progress: OnboardingProgress): Promise<void> {
  if (progress.id !== 'primary' || progress.schemaVersion !== 1 || progress.status !== 'in-progress' || !Number.isInteger(progress.currentStep) || progress.currentStep < 0 || progress.currentStep > 4) {
    throw new Error('ONBOARDING_PROGRESS_INVALID');
  }
  const existing = await db.userProfiles.get('primary');
  if (existing) {
    const current = (await decodeLocalRecord('userProfiles', existing)).payload;
    if ('completedAt' in current) return;
  }
  await db.userProfiles.put(await encodeLocalRecord('userProfiles', { id: 'primary', payload: progress }));
}

export async function saveLocalUserProfile(profile: UserProfile): Promise<void> {
  if (profile.id !== 'primary' || profile.schemaVersion !== 1) throw new Error('PROFILE_SCHEMA_UNSUPPORTED');
  await db.userProfiles.put(await encodeLocalRecord('userProfiles', { id: 'primary', payload: profile }));
}

// Offline-first: source de vérité locale
export async function saveLocalTransaction(tx: LocalTransaction): Promise<void> {
  const saved = { ...tx, syncStatus: 'pending' as const, updatedAt: new Date() };
  const [stored, queue] = await Promise.all([encodeLocalRecord('transactions', saved), encodeLocalRecord<SyncQueueItem>('syncQueue', {
    id: `sync_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: tx.familyId,
    entity: 'transaction',
    entityId: tx.id,
    operation: 'create',
    payload: saved,
    createdAt: new Date(),
    attempts: 0,
  })]);
  await db.transaction('rw', db.transactions, db.syncQueue, async () => {
    await db.transactions.put(stored);
    await db.syncQueue.add(queue);
  });
}

export async function getLocalTransactions(familyId: string): Promise<LocalTransaction[]> {
  const rows = await db.transactions.where('familyId').equals(familyId).toArray();
  const items = await Promise.all(rows.map(row => decodeLocalRecord('transactions', row)));
  return items.filter(transaction => !transaction.isDeleted).sort((a, b) => b.bookingDate.getTime() - a.bookingDate.getTime());
}

export async function getLocalDeletedTransactions(familyId: string): Promise<LocalTransaction[]> {
  const rows = await db.transactions.where('familyId').equals(familyId).toArray();
  const items = (await Promise.all(rows.map(row => decodeLocalRecord('transactions', row)))).filter(transaction => transaction.isDeleted);
  return items.sort((a, b) => (b.deletedAt?.getTime() ?? 0) - (a.deletedAt?.getTime() ?? 0));
}

function asCoreTransaction(transaction: LocalTransaction): Transaction {
  return {
    ...transaction,
    source: 'manual',
    createdAt: transaction.createdAt ?? transaction.bookingDate,
    updatedAt: transaction.updatedAt,
    createdByUserId: transaction.createdByUserId ?? 'local-owner',
  };
}

async function queueTransactionUpdate(transaction: LocalTransaction): Promise<void> {
  const timestamp = new Date();
  const payload = { ...transaction, syncStatus: 'pending' as const, updatedAt: timestamp };
  const [stored, queue] = await Promise.all([encodeLocalRecord('transactions', payload), encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: transaction.familyId,
      entity: 'transaction',
      entityId: transaction.id,
      operation: 'update',
      payload,
      createdAt: timestamp,
      attempts: 0,
    })]);
  await db.transaction('rw', db.transactions, db.syncQueue, async () => {
    await db.transactions.put(stored);
    await db.syncQueue.add(queue);
  });
}

export async function softDeleteLocalTransaction(id: string, familyId: string, role: Role): Promise<LocalTransaction> {
  const transaction = await getDecrypted<LocalTransaction>('transactions', db.transactions, id);
  if (!transaction || transaction.familyId !== familyId) throw new Error('TX_NOT_FOUND');
  const deleted = softDeleteTransaction(asCoreTransaction(transaction), role);
  const local: LocalTransaction = {
    ...transaction,
    isDeleted: true,
    deletedAt: deleted.deletedAt,
    syncStatus: 'pending',
    updatedAt: deleted.updatedAt,
  };
  await queueTransactionUpdate(local);
  return local;
}

export async function restoreLocalTransaction(id: string, familyId: string, role: Role): Promise<LocalTransaction> {
  const transaction = await getDecrypted<LocalTransaction>('transactions', db.transactions, id);
  if (!transaction || transaction.familyId !== familyId) throw new Error('TX_NOT_FOUND');
  const restored = restoreTransaction(asCoreTransaction(transaction), familyId, role);
  const local: LocalTransaction = {
    ...transaction,
    isDeleted: false,
    deletedAt: undefined,
    syncStatus: 'pending',
    updatedAt: restored.updatedAt,
  };
  await queueTransactionUpdate(local);
  return local;
}

export async function getLocalBudgets(familyId: string): Promise<LocalBudget[]> {
  const rows = await db.budgets.where('familyId').equals(familyId).toArray();
  const budgets = await Promise.all(rows.map(row => decodeLocalRecord('budgets', row)));
  return budgets.sort((a, b) => b.year - a.year || (b.month ?? 0) - (a.month ?? 0));
}

export async function saveLocalBudget(budget: LocalBudget): Promise<void> {
  const existing = await db.budgets.get(budget.id);
  const timestamp = new Date();
  const saved = { ...budget, syncStatus: 'pending' as const, updatedAt: timestamp };

  const [stored, queue] = await Promise.all([encodeLocalRecord('budgets', saved), encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: budget.familyId,
      entity: 'budget',
      entityId: budget.id,
      operation: existing ? 'update' : 'create',
      payload: saved,
      createdAt: timestamp,
      attempts: 0,
  })]);
  await db.transaction('rw', db.budgets, db.syncQueue, async () => {
    await db.budgets.put(stored);
    await db.syncQueue.add(queue);
  });
}

export async function getLocalSavingGoals(familyId: string): Promise<LocalSavingGoal[]> {
  const rows = await db.savingGoals.where('familyId').equals(familyId).toArray();
  const goals = await Promise.all(rows.map(row => decodeLocalRecord('savingGoals', row)));
  return goals.filter(goal => !goal.isDeleted).sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
}

export async function saveLocalSavingGoal(goal: SavingGoal, contribution?: SavingContribution): Promise<void> {
  const existing = await db.savingGoals.get(goal.id);
  const timestamp = new Date();
  const saved: LocalSavingGoal = { ...goal, syncStatus: 'pending', updatedAt: timestamp };
  const savedContribution: LocalSavingContribution | undefined = contribution ? { ...contribution, familyId: goal.familyId, syncStatus: 'pending' } : undefined;
  const [storedGoal, storedContribution, goalQueue, contributionQueue] = await Promise.all([
    encodeLocalRecord('savingGoals', saved),
    savedContribution ? encodeLocalRecord('savingContributions', savedContribution) : Promise.resolve(undefined),
    encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: goal.familyId, entity: 'savingGoal', entityId: goal.id,
      operation: existing ? 'update' : 'create', payload: saved, createdAt: timestamp, attempts: 0,
    }),
    savedContribution ? encodeLocalRecord<SyncQueueItem>('syncQueue', {
      id: `sync_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      familyId: goal.familyId, entity: 'savingContribution', entityId: contribution!.id,
      operation: 'create', payload: savedContribution, createdAt: timestamp, attempts: 0,
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
