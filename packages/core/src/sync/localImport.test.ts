import 'fake-indexeddb/auto';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { activateLocalVault, createLocalVault, lockLocalVault } from '../localVault';
import { db, getLocalSyncQueue, getLocalTransactions, importLocalTransactionsBatch } from './dexie';

const familyId = 'local-import-test';

async function clearTables() {
  await db.open();
  await db.transaction('rw', db.transactions, db.syncQueue, async () => {
    await Promise.all([db.transactions.clear(), db.syncQueue.clear()]);
  });
}

beforeEach(async () => {
  await clearTables();
  const { key } = await createLocalVault('import test passphrase');
  activateLocalVault(key);
});
afterEach(async () => { await clearTables(); lockLocalVault(); vi.restoreAllMocks(); });

describe('import LocalTransaction en lot', () => {
  it('ajoute les transactions chiffrées et leurs tâches de synchronisation ensemble', async () => {
    const imported = await importLocalTransactionsBatch([
      { familyId, label: 'Courses', bookingDate: new Date('2026-03-12T00:00:00Z'), amountCents: -2450, categoryId: 'Alimentation' },
      { familyId, label: 'Salaire', bookingDate: new Date('2026-03-01T00:00:00Z'), amountCents: 210000, categoryId: undefined },
    ]);
    expect(imported).toHaveLength(2);
    expect((await getLocalTransactions(familyId)).map(row => row.label)).toContain('Courses');
    expect(await getLocalSyncQueue(familyId)).toHaveLength(2);
    const stored = await db.transactions.get(imported[0].id);
    expect(stored?.label).toMatch(/^tena:v1:/);
    expect(stored?.amountCents).toMatch(/^tena:v1:/);
    expect(stored?.source).toBe('import');
  });

  it('refuse un lot invalide avant toute écriture', async () => {
    await expect(importLocalTransactionsBatch([
      { familyId, label: 'Valide', bookingDate: new Date(), amountCents: 100, categoryId: undefined },
      { familyId, label: 'Invalide', bookingDate: new Date(), amountCents: 0, categoryId: undefined },
    ])).rejects.toThrow('LOCAL_IMPORT_AMOUNT_INVALID');
    expect(await db.transactions.count()).toBe(0);
    expect(await db.syncQueue.count()).toBe(0);
  });

  it('annule la transaction si la file locale entre en conflit après insertion des lignes', async () => {
    const fixedId = '11111111-1111-4111-8111-111111111111';
    vi.spyOn(globalThis.crypto, 'randomUUID').mockReturnValue(fixedId);
    await db.syncQueue.add({ id: `sync_tx_import_${fixedId}`, familyId, entity: 'transaction', entityId: 'existing', operation: 'create', payload: {}, createdAt: new Date(), attempts: 0 });
    await expect(importLocalTransactionsBatch([
      { familyId, label: 'Courses', bookingDate: new Date(), amountCents: -300, categoryId: undefined },
    ])).rejects.toThrow();
    expect(await db.transactions.count()).toBe(0);
    expect(await db.syncQueue.count()).toBe(1);
  });
});
