
import { getLocalConflict, getLocalConflicts, getLocalSyncQueue, putLocalConflict, putLocalSyncQueueItem, removeLocalSyncQueueItem, SyncQueueItem, ConflictLog, updateLocalConflict, updateLocalEntitySyncStatus, updateLocalSyncQueueAttempts } from "./dexie";

// Synchronisation Dexie ↔ serveur - ne jamais perdre silencieusement une donnée

export interface SyncResult {
  synced: number;
  conflicts: ConflictLog[];
  failed: SyncQueueItem[];
}

export async function syncWithServer(familyId: string, serverFetch: (item: SyncQueueItem) => Promise<{ success: boolean; serverVersion?: any; conflict?: boolean }>): Promise<SyncResult> {
  const queue = await getLocalSyncQueue(familyId);
  let synced = 0;
  const conflicts: ConflictLog[] = [];
  const failed: SyncQueueItem[] = [];

  for (const item of queue) {
    try {
      const result = await serverFetch(item);
      if (result.success) {
        await removeLocalSyncQueueItem(item.id);
        // Marque synced
        if (item.entity === 'transaction') {
          await updateLocalEntitySyncStatus(item.entity, item.entityId, 'synced');
        } else if (item.entity === 'savingGoal') {
          await updateLocalEntitySyncStatus(item.entity, item.entityId, 'synced');
        } else if (item.entity === 'savingContribution') {
          await updateLocalEntitySyncStatus(item.entity, item.entityId, 'synced');
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
        await putLocalConflict(conflict);
        conflicts.push(conflict);
        // Marque conflict
        if (item.entity === 'transaction') {
          await updateLocalEntitySyncStatus(item.entity, item.entityId, 'conflict');
        } else if (item.entity === 'savingGoal') {
          await updateLocalEntitySyncStatus(item.entity, item.entityId, 'conflict');
        } else if (item.entity === 'savingContribution') {
          await updateLocalEntitySyncStatus(item.entity, item.entityId, 'conflict');
        }
      } else {
        // Échec temporaire
        await updateLocalSyncQueueAttempts(item.id, item.attempts + 1);
        failed.push(item);
      }
    } catch (e) {
      await updateLocalSyncQueueAttempts(item.id, item.attempts + 1);
      failed.push(item);
    }
  }

  return { synced, conflicts, failed };
}

export async function resolveConflict(conflictId: string, resolution: 'local_wins' | 'server_wins' | 'manual', manualData?: any): Promise<void> {
  const conflict = await getLocalConflict(conflictId);
  if (!conflict) throw new Error("CONFLICT_NOT_FOUND");
  // Conserve trace même après résolution
  await updateLocalConflict({ ...conflict, resolution, resolvedAt: new Date(), localVersion: manualData || conflict.localVersion });
  if (resolution === 'local_wins') {
    // Re-queue local version
    await putLocalSyncQueueItem({
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
  return (await getLocalSyncQueue(familyId)).length;
}

export async function getConflicts(familyId: string): Promise<ConflictLog[]> {
  return (await getLocalConflicts(familyId)).filter(c => c.resolution === 'pending');
}
