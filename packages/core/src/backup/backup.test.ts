import { describe, it, expect, vi } from "vitest";
import {
  encryptBackup,
  decryptBackup,
  createBackup,
  BackupData,
  EncryptedBackup,
} from "./backup";
import { Role } from "../permissions/permissions";

describe("Backup encryption improvements", () => {
  const role: Role = "owner";

  const rawBackupInput = {
    familyId: "fam1",
    transactions: [],
    budgets: [],
    categories: [],
    persons: [],
    goals: [],
    savingContributions: [],
    recurringRules: [],
    userProfile: undefined,
  };

  it("should enforce minimum password length of 12", async () => {
    const backup = await createBackup(rawBackupInput, role);
    await expect(encryptBackup(backup, "short")).rejects.toThrow(
      "BACKUP_PASSWORD_MIN_12"
    );
    await expect(encryptBackup(backup, "123456789011")).resolves.not.toThrow();
  });

  it("should encrypt with new iteration count and store it", async () => {
    const backup = await createBackup(rawBackupInput, role);
    const encrypted = await encryptBackup(backup, "ValidPass123!");
    expect(encrypted.iterations).toBe(310_000);
  });

  it("should decrypt backup encrypted with new iteration count", async () => {
    const backup = await createBackup(rawBackupInput, role);
    const password = "ValidPass123!";
    const encrypted = await encryptBackup(backup, password);
    const decrypted = await decryptBackup(encrypted, password);
    expect(decrypted).toEqual(backup);
  });
});