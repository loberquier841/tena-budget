import { describe, expect, it } from "vitest";
import {
  createBackup,
  encryptBackup,
  decryptBackup,
  restoreBackup,
  generateChecksum,
  testBackupRestoreCycle,
  type BackupData,
  type EncryptedBackup,
} from "./backup";
import type { Role } from "../permissions/permissions";

const role: Role = "owner";
const familyId = "fam1";
const password = "MotDePasseBackup123";

const baseInput = {
  familyId,
  transactions: [
    { id: "tx-1", familyId, amountCents: 1000, label: "Courses", isDeleted: false, bookingDate: new Date("2026-01-01") },
    { id: "tx-2", familyId, amountCents: -500, label: "Café", isDeleted: true, bookingDate: new Date("2026-01-02") },
  ],
  budgets: [{ id: "bud-1", familyId, type: "annual" as const, year: 2026, amountCents: 400000 }],
  categories: [{ id: "cat-1", familyId, name: "Alimentation" }],
  persons: [{ id: "p-1", familyId, name: "Alice" }],
  goals: [
    { id: "goal-1", familyId, name: "Vacances", targetCents: 200000, currentCents: 50000, isDeleted: false },
    { id: "goal-2", familyId, name: "Vélo", targetCents: 100000, currentCents: 0, isDeleted: true },
  ],
  savingContributions: [
    { id: "cont-1", goalId: "goal-1", amountCents: 50000, bookingDate: new Date("2026-01-05"), createdByUserId: "u1" },
    { id: "cont-2", goalId: "goal-2", amountCents: 10000, bookingDate: new Date("2026-01-06"), createdByUserId: "u1" },
  ],
  recurringRules: [],
};

describe("Sauvegardes et restaurations (backup.ts)", () => {
  describe("generateChecksum", () => {
    it("produit un checksum SHA-256 déterministe sur 64 hex", async () => {
      const a = await generateChecksum("payload stable");
      const b = await generateChecksum("payload stable");
      expect(a).toBe(b);
      expect(a).toMatch(/^[0-9a-f]{64}$/);
    });

    it("diffère si la donnée change", async () => {
      const a = await generateChecksum("A");
      const b = await generateChecksum("B");
      expect(a).not.toBe(b);
    });
  });

  describe("createBackup", () => {
    it("crée une sauvegarde version 2.0 avec checksum et filtre les supprimés", async () => {
      const backup = await createBackup(baseInput, role);
      expect(backup.version).toBe("2.0");
      expect(backup.familyId).toBe(familyId);
      expect(typeof backup.checksum).toBe("string");
      expect(backup.checksum.length).toBeGreaterThan(0);
      expect(backup.transactions.find((t) => t.id === "tx-2")).toBeUndefined();
      expect(backup.transactions.length).toBe(1);
      expect(backup.goals.find((g) => g.id === "goal-2")).toBeUndefined();
      expect(backup.goals.length).toBe(1);
    });

    it("exclut les versements dont l'objectif est supprimé", async () => {
      const backup = await createBackup(baseInput, role);
      const contIds = backup.savingContributions?.map((c) => c.id) ?? [];
      expect(contIds).toContain("cont-1");
      expect(contIds).not.toContain("cont-2");
    });

    it("rejette un familyId manquant", async () => {
      await expect(createBackup({ ...baseInput, familyId: "" } as any, role)).rejects.toThrow("BACKUP_FAMILY_REQUIRED");
    });

    it("rejette un enregistrement d'une autre famille (BACKUP_FAMILY_MISMATCH)", async () => {
      await expect(
        createBackup(
          {
            ...baseInput,
            budgets: [...baseInput.budgets, { id: "bud-x", familyId: "autre", type: "annual", year: 2026, amountCents: 1000 }],
          },
          role,
        ),
      ).rejects.toThrow("BACKUP_FAMILY_MISMATCH");
    });

    it("inclut le profil utilisateur quand il est fourni", async () => {
      const profile = {
        id: "primary" as const,
        schemaVersion: 1,
        createdAt: "2026-10-07T12:00:00.000Z",
        updatedAt: "2026-10-07T12:00:00.000Z",
        completedAt: "2026-10-07T12:00:00.000Z",
        answers: {
          householdMode: "personal",
          incomePattern: "variable",
          budgetExperience: "starting",
          priorities: ["save"],
          wantedFeatures: ["transactions"],
          notificationPreference: "balanced",
        },
        dashboard: { visibleCards: ["goals", "spending"], compact: false },
      };
      const backup = await createBackup({ ...baseInput, userProfile: profile }, role);
      expect(backup.userProfile).toEqual(profile);
    });
  });
  describe("encryptBackup / decryptBackup", () => {
    let backup: BackupData;

    beforeAll(async () => {
      backup = await createBackup(baseInput, role);
    });

    it("rejette un mot de passe inférieur à 8 caractères (BACKUP_PASSWORD_MIN_8)", async () => {
      await expect(encryptBackup(backup, "court")).rejects.toThrow("BACKUP_PASSWORD_MIN_8");
      await expect(encryptBackup(backup, "")).rejects.toThrow("BACKUP_PASSWORD_MIN_8");
    });

    it("chiffre puis déchiffre sans perte (aller-retour)", async () => {
      const encrypted = await encryptBackup(backup, password);
      expect(encrypted).toMatchObject<Partial<EncryptedBackup>>({
        version: "2.0",
        familyId,
      });
      expect(typeof encrypted.iv).toBe("string");
      expect(typeof encrypted.salt).toBe("string");
      expect(typeof encrypted.data).toBe("string");
      expect(JSON.stringify(encrypted)).not.toContain(password);

      const decrypted = await decryptBackup(encrypted, password);
      expect(decrypted.checksum).toBe(backup.checksum);
      expect(decrypted.transactions.length).toBe(backup.transactions.length);
      expect(decrypted.goals.length).toBe(backup.goals.length);
    });

    it("échoue le déchiffrement avec un mauvais mot de passe", async () => {
      const encrypted = await encryptBackup(backup, password);
      await expect(decryptBackup(encrypted, "MauvaisMotDePasse123")).rejects.toThrow();
    });

    it("détecte une altération du corps chiffré (intégrité)", async () => {
      const encrypted = await encryptBackup(backup, password);
      const tampered: EncryptedBackup = {
        ...encrypted,
        data: encrypted.data.slice(0, -2) === encrypted.data ? encrypted.data + "AA" : encrypted.data.slice(0, -2) + "AA",
      };
      await expect(decryptBackup(tampered, password)).rejects.toThrow();
    });

    it("rejette un format d'entrée invalide au déchiffrement", async () => {
      await expect(decryptBackup({} as EncryptedBackup, password)).rejects.toThrow("BACKUP_FORMAT_INVALID");
    });
  describe("restoreBackup", () => {
    let encrypted: EncryptedBackup;

    beforeAll(async () => {
      const backup = await createBackup(baseInput, role);
      encrypted = await encryptBackup(backup, password);
    });

    const existingEmpty = { transactions: [], budgets: [], categories: [] };

    it("restaure avec succès quand il n'y a pas de conflit", async () => {
      const decrypted = await decryptBackup(encrypted, password);
      const result = await restoreBackup(decrypted, existingEmpty, role, { overwrite: false });
      expect(result.conflicts).toEqual([]);
      expect(result.toCreate.transactions).toBe(baseInput.transactions.filter((t) => !t.isDeleted).length);
      expect(result.toCreate.budgets).toBe(1);
      expect(result.toCreate.categories).toBe(1);
    });

    it("détecte les conflits d'IDs quand overwrite est false", async () => {
      const decrypted = await decryptBackup(encrypted, password);
      const existingWithTx = { transactions: [{ id: "tx-1", familyId }], budgets: [], categories: [] };
      const result = await restoreBackup(decrypted, existingWithTx, role, { overwrite: false });
      expect(result.conflicts.length).toBeGreaterThan(0);
      expect(result.conflicts[0]).toContain("tx-1");
      expect(result.toCreate.transactions).toBe(0);
    });

    it("passe outre les conflits quand overwrite est true", async () => {
      const decrypted = await decryptBackup(encrypted, password);
      const existingWithTx = { transactions: [{ id: "tx-1", familyId }], budgets: [], categories: [] };
      const result = await restoreBackup(decrypted, existingWithTx, role, { overwrite: true });
      expect(result.conflicts).toEqual([]);
      expect(result.toCreate.transactions).toBeGreaterThan(0);
    });

    it("rejette le format invalide (BACKUP_FORMAT_INVALID)", async () => {
      await expect(restoreBackup(null as any, existingEmpty, role, { overwrite: false })).rejects.toThrow("BACKUP_FORMAT_INVALID");
      await expect(restoreBackup({ familyId } as any, existingEmpty, role, { overwrite: false })).rejects.toThrow("BACKUP_FORMAT_INVALID");
    });

    it("détecte une altération du checksum (BACKUP_INTEGRITY_FAILED)", async () => {
      const decrypted = await decryptBackup(encrypted, password);
      const corrupted: BackupData = { ...decrypted, checksum: "0".repeat(64) };
      await expect(restoreBackup(corrupted, existingEmpty, role, { overwrite: false })).rejects.toThrow("BACKUP_INTEGRITY_FAILED");
    });

    it("rejette un désaccord de famille entre backup et métadonnées (BACKUP_METADATA_MISMATCH)", async () => {
      const decrypted = await decryptBackup(encrypted, password);
      const metaMismatch: EncryptedBackup = { ...encrypted, familyId: "autre-famille" };
      await expect(decryptBackup(metaMismatch, password)).rejects.toThrow("BACKUP_METADATA_MISMATCH");
    });
  });

  describe("testBackupRestoreCycle", () => {
    it("valide un cycle complet sauvegarde -> chiffrement -> déchiffrement -> restauration", async () => {
      const ok = await testBackupRestoreCycle(baseInput, password, role);
      expect(ok).toBe(true);
    });
  });
});
  });