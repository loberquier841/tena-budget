import { db } from '@tena/core/sync/dexie';
import { getLocalUserProfile } from '@tena/core/sync/dexie';

const LOCAL_FAMILY_KEY = 'tena-budget.local-family-id';

/** Use an existing local space, or give a completed local profile a stable first space. */
export function resolveLocalFamilyIds(existingIds: string[], hasCompletedProfile: boolean, storedPrimaryId?: string, createId: () => string = () => `family_local_${crypto.randomUUID()}`): string[] {
  const ids = [...new Set(existingIds.filter(Boolean))].sort();
  if (ids.length || !hasCompletedProfile) return ids;
  return [storedPrimaryId || createId()];
}

/** Local family ids stay unencrypted so Dexie can scope records before decrypting them. */
export async function getLocalFamilyIds(): Promise<string[]> {
  const [transactions, budgets, goals, profile] = await Promise.all([
    db.transactions.toArray(),
    db.budgets.toArray(),
    db.savingGoals.toArray(),
    getLocalUserProfile(),
  ]);
  const ids = new Set<string>();
  for (const transaction of transactions) if (transaction.familyId) ids.add(transaction.familyId);
  for (const budget of budgets) if (budget.familyId) ids.add(budget.familyId);
  for (const goal of goals) if (goal.familyId) ids.add(goal.familyId);
  const existingIds = [...ids].sort();
  if (existingIds.length || !profile || typeof window === 'undefined') return existingIds;

  let primaryId = window.localStorage.getItem(LOCAL_FAMILY_KEY);
  if (!primaryId) {
    primaryId = resolveLocalFamilyIds(existingIds, true)[0];
    window.localStorage.setItem(LOCAL_FAMILY_KEY, primaryId);
  }
  return resolveLocalFamilyIds(existingIds, true, primaryId);
}
