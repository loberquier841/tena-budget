
import { db, SyncQueueItem, ConflictLog } from "./dexie";

// Synchronisation Dexie ↔ serveur - ne jamais perdre silencieusement une donnée

export interface SyncResult {
  synced: number;
  conflicts: ConflictLog[];
  failed: SyncQueueItem[];
}

export async function syncWithServer(familyId: string, serverFetch: (item: SyncQueueItem) => Promise<{ success: boolean; serverVersion?: any; conflict?: boolean }>): Promise<SyncResult> {
  const queue = await db.syncQueue.where('familyId').equals(familyId).toArray();
  let synced = 0;
  const conflicts: ConflictLog[] = [];
  const failed: SyncQueueItem[] = [];

  for (const item of queue) {
    try {
      const result = await serverFetch(item);
      if (result.success) {
        await db.syncQueue.delete(item.id);
        // Marque synced
        if (item.entity === 'transaction') {
          await db.transactions.update(item.entityId, { syncStatus: 'synced' as const });
        }
        synced++;
      } else if (result.conflict) {
        // Conflit: conserve trace, ne perd pas donnée
        const conflict: ConflictLog = {
          id: `conf_${Date.now()}`,
          familyId,
          entity: item.entity,
          entityId: item.entityId,
          localVersion: item.payload,
          serverVersion: result.serverVersion,
          resolution: 'pending',
        };
        await db.conflicts.add(conflict);
        conflicts.push(conflict);
        // Marque conflict
        if (item.entity === 'transaction') {
          await db.transactions.update(item.entityId, { syncStatus: 'conflict' as const });
        }
      } else {
        // Échec temporaire
        await db.syncQueue.update(item.id, { attempts: item.attempts + 1 });
        failed.push(item);
      }
    } catch (e) {
      await db.syncQueue.update(item.id, { attempts: item.attempts + 1 });
      failed.push(item);
    }
  }

  return { synced, conflicts, failed };
}

export async function resolveConflict(conflictId: string, resolution: 'local_wins' | 'server_wins' | 'manual', manualData?: any): Promise<void> {
  const conflict = await db.conflicts.get(conflictId);
  if (!conflict) throw new Error("CONFLICT_NOT_FOUND");
  // Conserve trace même après résolution
  await db.conflicts.update(conflictId, { resolution, resolvedAt: new Date(), localVersion: manualData || conflict.localVersion });
  if (resolution === 'local_wins') {
    // Re-queue local version
    await db.syncQueue.add({
      id: `sync_${Date.now()}`,
      familyId: conflict.familyId,
      entity: conflict.entity as any,
      entityId: conflict.entityId,
      operation: 'update',
      payload: conflict.localVersion,
      createdAt: new Date(),
      attempts: 0,
    });
  }
  // server_wins: on garde serveur, local sera écrasé au prochain fetch
}

export async function getPendingSyncCount(familyId: string): Promise<number> {
  return db.syncQueue.where('familyId').equals(familyId).count();
}

export async function getConflicts(familyId: string): Promise<ConflictLog[]> {
  return db.conflicts.where('familyId').equals(familyId).filter(c => c.resolution === 'pending').toArray();
}
