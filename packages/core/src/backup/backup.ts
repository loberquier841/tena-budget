
import { Role, assertCan } from "../permissions/permissions";
import type { UserProfile } from "../product/profile";

// Sauvegardes chiffrées - Web Crypto API native (AES-GCM 256) - aucune clé exposée frontend/logs
const BACKUP_PBKDF2_ITERATIONS = 310_000;

export interface BackupData {
  version: string;
  familyId: string;
  createdAt: string;
  transactions: any[];
  budgets: any[];
  categories: any[];
  persons: any[];
  goals: any[];
  savingContributions?: any[];
  recurringRules: any[];
  userProfile?: UserProfile;
  checksum: string; // SHA-256 pour intégrité
}

export interface EncryptedBackup {
  iv: string; // base64
  salt: string; // base64
  data: string; // base64 ciphertext
  version: string;
  familyId: string;
  createdAt: string;
  iterations?: number; // PBKDF2 iterations used for encryption
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

// Génère checksum SHA-256 pour intégrité
export async function generateChecksum(data: string): Promise<string> {
  const encoder = new TextEncoder();
  const buffer = encoder.encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

export async function createBackup(input: { familyId: string; transactions: any[]; budgets: any[]; categories: any[]; persons: any[]; goals: any[]; savingContributions?: any[]; recurringRules: any[]; userProfile?: UserProfile }, role: Role): Promise<BackupData> {
  assertCan(role, "budget:read");
  if (!input.familyId) throw new Error("BACKUP_FAMILY_REQUIRED");
  const collections = [input.transactions, input.budgets, input.categories, input.persons, input.goals, input.savingContributions ?? [], input.recurringRules];
  if (collections.some(records => records.some((record: any) => record?.familyId && record.familyId !== input.familyId))) throw new Error("BACKUP_FAMILY_MISMATCH");
  const activeGoalIds = new Set(input.goals.filter((goal: any) => !goal.isDeleted).map((goal: any) => goal.id));
  // Filtre isDeleted = false pour backup propre, mais garde deleted si besoin restauration
  const backup: BackupData = {
    version: "2.0",
    familyId: input.familyId,
    createdAt: new Date().toISOString(),
    transactions: input.transactions.filter((t: any) => !t.isDeleted),
    budgets: input.budgets,
    categories: input.categories,
    persons: input.persons,
    goals: input.goals.filter((goal: any) => !goal.isDeleted),
    savingContributions: (input.savingContributions ?? []).filter((contribution: any) => activeGoalIds.has(contribution.goalId)),
    recurringRules: input.recurringRules,
    ...(input.userProfile ? { userProfile: input.userProfile } : {}),
    checksum: "",
  };
  const jsonWithoutChecksum = JSON.stringify({ ...backup, checksum: "" });
  backup.checksum = await generateChecksum(jsonWithoutChecksum);
  return backup;
}

export async function encryptBackup(backup: BackupData, password: string): Promise<EncryptedBackup> {
  if (!password || password.length < 12) throw new Error("BACKUP_PASSWORD_MIN_12");
  const encoder = new TextEncoder();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));

  const keyMaterial = await crypto.subtle.importKey('raw', encoder.encode(password), { name: 'PBKDF2' }, false, ['deriveKey']);
  const key = await crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: BACKUP_PBKDF2_ITERATIONS, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt']
  );

  const dataBuffer = encoder.encode(JSON.stringify(backup));
  const encryptedBuffer = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, dataBuffer);

  return {
    iv: bytesToBase64(iv),
    salt: bytesToBase64(salt),
    data: bytesToBase64(new Uint8Array(encryptedBuffer)),
    version: backup.version,
    familyId: backup.familyId,
    createdAt: backup.createdAt,
    iterations: BACKUP_PBKDF2_ITERATIONS,
  };
}

export async function decryptBackup(encrypted: EncryptedBackup, password: string): Promise<BackupData> {
  if (!password || !encrypted?.iv || !encrypted?.salt || !encrypted?.data || !encrypted.familyId) throw new Error("BACKUP_FORMAT_INVALID");
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  const salt = base64ToBytes(encrypted.salt);
  const iv = base64ToBytes(encrypted.iv);
  const data = base64ToBytes(encrypted.data);

  const keyMaterial = await crypto.subtle.importKey('raw', encoder.encode(password), { name: 'PBKDF2' }, false, ['deriveKey']);
  const iterations = encrypted.iterations ?? 100000;
  const key = await crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt']
  );

  const decryptedBuffer = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, data);
  const json = decoder.decode(decryptedBuffer);
  let backup: BackupData;
  try {
    backup = JSON.parse(json) as BackupData;
  } catch {
    throw new Error("BACKUP_FORMAT_INVALID");
  }

  // Validation intégrité
  const checksum = backup.checksum;
  const jsonWithoutChecksum = JSON.stringify({ ...backup, checksum: "" });
  const computed = await generateChecksum(jsonWithoutChecksum);
  if (computed !== checksum) throw new Error("BACKUP_INTEGRITY_FAILED: checksum mismatch");
  if (backup.familyId !== encrypted.familyId || backup.version !== encrypted.version) throw new Error("BACKUP_METADATA_MISMATCH");

  return backup;
}

export async function restoreBackup(backup: BackupData, existing: { transactions: any[]; budgets: any[]; categories: any[]; goals?: any[]; savingContributions?: any[] }, role: Role, options: { overwrite: boolean }): Promise<{ toCreate: { transactions: number; budgets: number; categories: number; goals: number; savingContributions: number }; conflicts: string[] }> {
  assertCan(role, "budget:write");
  if (!backup || !backup.familyId || !Array.isArray(backup.transactions) || !Array.isArray(backup.budgets) || !Array.isArray(backup.categories)) {
    throw new Error("BACKUP_FORMAT_INVALID");
  }
  const jsonWithoutChecksum = JSON.stringify({ ...backup, checksum: "" });
  if (await generateChecksum(jsonWithoutChecksum) !== backup.checksum) throw new Error("BACKUP_INTEGRITY_FAILED: checksum mismatch");
  for (const records of [backup.transactions, backup.budgets, backup.categories, backup.persons ?? [], backup.goals ?? [], backup.savingContributions ?? [], backup.recurringRules ?? []]) {
    if (records.some((record: any) => record?.familyId && record.familyId !== backup.familyId)) throw new Error("BACKUP_FAMILY_MISMATCH");
  }
  // Restauration sans écraser silencieusement
  const conflicts: string[] = [];

  if (!options.overwrite) {
    // Détecte conflits: IDs existants
    const existingTxIds = new Set(existing.transactions.map((t: any) => t.id));
    const existingBudgetIds = new Set(existing.budgets.map((b: any) => b.id));
    const existingCatIds = new Set(existing.categories.map((c: any) => c.id));
    const existingGoalIds = new Set((existing.goals ?? []).map((g: any) => g.id));
    const existingContributionIds = new Set((existing.savingContributions ?? []).map((c: any) => c.id));

    for (const tx of backup.transactions) {
      if (existingTxIds.has(tx.id)) conflicts.push(`Transaction ${tx.id} existe déjà`);
    }
    for (const b of backup.budgets) {
      if (existingBudgetIds.has(b.id)) conflicts.push(`Budget ${b.id} existe déjà`);
    }
    for (const c of backup.categories) {
      if (existingCatIds.has(c.id)) conflicts.push(`Catégorie ${c.id} existe déjà`);
    }
    for (const goal of backup.goals ?? []) {
      if (existingGoalIds.has(goal.id)) conflicts.push(`Objectif ${goal.id} existe déjà`);
    }
    for (const contribution of backup.savingContributions ?? []) {
      if (existingContributionIds.has(contribution.id)) conflicts.push(`Versement ${contribution.id} existe déjà`);
    }

    if (conflicts.length > 0) {
      return { toCreate: { transactions: 0, budgets: 0, categories: 0, goals: 0, savingContributions: 0 }, conflicts };
    }
  }

  // Aucune clé sensible exposée dans logs - on ne log pas password
  return {
    toCreate: {
      transactions: backup.transactions.length,
      budgets: backup.budgets.length,
      categories: backup.categories.length,
      goals: backup.goals?.length ?? 0,
      savingContributions: backup.savingContributions?.length ?? 0,
    },
    conflicts: [],
  };
}

export async function testBackupRestoreCycle(input: any, password: string, role: Role): Promise<boolean> {
  const backup = await createBackup(input, role);
  const encrypted = await encryptBackup(backup, password);
  const decrypted = await decryptBackup(encrypted, password);
  const restored = await restoreBackup(decrypted, { transactions: [], budgets: [], categories: [] }, role, { overwrite: false });
  return restored.toCreate.transactions === input.transactions.length && decrypted.checksum === backup.checksum;
}
