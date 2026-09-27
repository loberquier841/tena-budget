
import { Role, assertCan } from "../permissions/permissions";

// Sauvegardes chiffrées - Web Crypto API native (AES-GCM 256) - aucune clé exposée frontend/logs

export interface BackupData {
  version: string;
  familyId: string;
  createdAt: string;
  transactions: any[];
  budgets: any[];
  categories: any[];
  persons: any[];
  goals: any[];
  recurringRules: any[];
  checksum: string; // SHA-256 pour intégrité
}

export interface EncryptedBackup {
  iv: string; // base64
  salt: string; // base64
  data: string; // base64 ciphertext
  version: string;
  familyId: string;
  createdAt: string;
}

// Génère checksum SHA-256 pour intégrité
export async function generateChecksum(data: string): Promise<string> {
  const encoder = new TextEncoder();
  const buffer = encoder.encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

export async function createBackup(input: { familyId: string; transactions: any[]; budgets: any[]; categories: any[]; persons: any[]; goals: any[]; recurringRules: any[] }, role: Role): Promise<BackupData> {
  assertCan(role, "budget:read");
  // Filtre isDeleted = false pour backup propre, mais garde deleted si besoin restauration
  const backup: BackupData = {
    version: "1.0",
    familyId: input.familyId,
    createdAt: new Date().toISOString(),
    transactions: input.transactions.filter((t: any) => !t.isDeleted),
    budgets: input.budgets,
    categories: input.categories,
    persons: input.persons,
    goals: input.goals,
    recurringRules: input.recurringRules,
    checksum: "",
  };
  const jsonWithoutChecksum = JSON.stringify({ ...backup, checksum: "" });
  backup.checksum = await generateChecksum(jsonWithoutChecksum);
  return backup;
}

export async function encryptBackup(backup: BackupData, password: string): Promise<EncryptedBackup> {
  if (!password || password.length < 8) throw new Error("BACKUP_PASSWORD_MIN_8");
  const encoder = new TextEncoder();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));

  const keyMaterial = await crypto.subtle.importKey('raw', encoder.encode(password), { name: 'PBKDF2' }, false, ['deriveKey']);
  const key = await crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt']
  );

  const dataBuffer = encoder.encode(JSON.stringify(backup));
  const encryptedBuffer = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, dataBuffer);

  return {
    iv: Buffer.from(iv).toString('base64'),
    salt: Buffer.from(salt).toString('base64'),
    data: Buffer.from(encryptedBuffer).toString('base64'),
    version: backup.version,
    familyId: backup.familyId,
    createdAt: backup.createdAt,
  };
}

export async function decryptBackup(encrypted: EncryptedBackup, password: string): Promise<BackupData> {
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  const salt = Buffer.from(encrypted.salt, 'base64');
  const iv = Buffer.from(encrypted.iv, 'base64');
  const data = Buffer.from(encrypted.data, 'base64');

  const keyMaterial = await crypto.subtle.importKey('raw', encoder.encode(password), { name: 'PBKDF2' }, false, ['deriveKey']);
  const key = await crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt']
  );

  const decryptedBuffer = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, data);
  const json = decoder.decode(decryptedBuffer);
  const backup: BackupData = JSON.parse(json);

  // Validation intégrité
  const checksum = backup.checksum;
  const jsonWithoutChecksum = JSON.stringify({ ...backup, checksum: "" });
  const computed = await generateChecksum(jsonWithoutChecksum);
  if (computed !== checksum) throw new Error("BACKUP_INTEGRITY_FAILED: checksum mismatch");

  return backup;
}

export async function restoreBackup(backup: BackupData, existing: { transactions: any[]; budgets: any[]; categories: any[] }, role: Role, options: { overwrite: boolean }): Promise<{ toCreate: { transactions: number; budgets: number; categories: number }; conflicts: string[] }> {
  assertCan(role, "budget:write");
  // Validation intégrité déjà faite dans decryptBackup
  // Restauration sans écraser silencieusement
  const conflicts: string[] = [];

  if (!options.overwrite) {
    // Détecte conflits: IDs existants
    const existingTxIds = new Set(existing.transactions.map((t: any) => t.id));
    const existingBudgetIds = new Set(existing.budgets.map((b: any) => b.id));
    const existingCatIds = new Set(existing.categories.map((c: any) => c.id));

    for (const tx of backup.transactions) {
      if (existingTxIds.has(tx.id)) conflicts.push(`Transaction ${tx.id} existe déjà`);
    }
    for (const b of backup.budgets) {
      if (existingBudgetIds.has(b.id)) conflicts.push(`Budget ${b.id} existe déjà`);
    }
    for (const c of backup.categories) {
      if (existingCatIds.has(c.id)) conflicts.push(`Catégorie ${c.id} existe déjà`);
    }

    if (conflicts.length > 0) {
      return { toCreate: { transactions: 0, budgets: 0, categories: 0 }, conflicts };
    }
  }

  // Aucune clé sensible exposée dans logs - on ne log pas password
  return {
    toCreate: {
      transactions: backup.transactions.length,
      budgets: backup.budgets.length,
      categories: backup.categories.length,
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
