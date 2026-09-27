
import Dexie, { Table } from 'dexie';

export interface LocalTransaction {
  id: string;
  familyId: string;
  amountCents: number;
  bookingDate: Date;
  label: string;
  categoryId?: string;
  personId?: string;
  isDeleted: boolean;
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

export interface SyncQueueItem {
  id: string;
  familyId: string;
  entity: 'transaction' | 'budget' | 'category';
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

class TenaDatabase extends Dexie {
  transactions!: Table<LocalTransaction>;
  budgets!: Table<LocalBudget>;
  syncQueue!: Table<SyncQueueItem>;
  conflicts!: Table<ConflictLog>;

  constructor() {
    super('TenaBudgetDB');
    this.version(1).stores({
      transactions: 'id, familyId, personId, categoryId, bookingDate, syncStatus, updatedAt',
      budgets: 'id, familyId, personId, categoryId, year, syncStatus',
      syncQueue: 'id, familyId, entity, entityId, createdAt',
      conflicts: 'id, familyId, entity, entityId, resolution',
    });
  }
}

export const db = new TenaDatabase();

// Offline-first: source de vérité locale
export async function saveLocalTransaction(tx: LocalTransaction): Promise<void> {
  await db.transactions.put({ ...tx, syncStatus: 'pending', updatedAt: new Date() });
  await db.syncQueue.add({
    id: `sync_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: tx.familyId,
    entity: 'transaction',
    entityId: tx.id,
    operation: 'create',
    payload: tx,
    createdAt: new Date(),
    attempts: 0,
  });
}

export async function getLocalTransactions(familyId: string): Promise<LocalTransaction[]> {
  return db.transactions.where('familyId').equals(familyId).filter(t => !t.isDeleted).toArray();
}
