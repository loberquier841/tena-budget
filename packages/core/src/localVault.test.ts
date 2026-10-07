import { afterEach, describe, expect, it } from "vitest";
import { activateLocalVault, createLocalVault, decryptLocalValue, encryptLocalValue, isEncryptedLocalValue, lockLocalVault, unlockLocalVault } from "./localVault";
import { decodeLocalRecord, encodeLocalRecord, LocalTransaction } from "./sync/dexie";

afterEach(() => lockLocalVault());

describe("local vault cryptography", () => {
  it("uses a passphrase-derived key and encrypts values with authenticated encryption", async () => {
    const { metadata, key } = await createLocalVault("phrase longue et privée 2026");
    activateLocalVault(key);
    const encrypted = await encryptLocalValue({ label: "Loyer confidentiel", amountCents: -95000, bookingDate: "2026-10-07" });

    expect(isEncryptedLocalValue(encrypted)).toBe(true);
    expect(encrypted).not.toContain("Loyer confidentiel");
    lockLocalVault();
    await expect(decryptLocalValue(encrypted)).rejects.toThrow("LOCAL_VAULT_LOCKED");

    const unlockedKey = await unlockLocalVault(metadata, "phrase longue et privée 2026");
    activateLocalVault(unlockedKey);
    await expect(decryptLocalValue(encrypted)).resolves.toEqual({ label: "Loyer confidentiel", amountCents: -95000, bookingDate: "2026-10-07" });
  });

  it("rejects wrong passphrases and tampered ciphertext", async () => {
    const { metadata, key } = await createLocalVault("phrase secrète de test 2026");
    activateLocalVault(key);
    const encrypted = await encryptLocalValue("secret");

    await expect(unlockLocalVault(metadata, "phrase incorrecte 2026")).rejects.toThrow("LOCAL_VAULT_PASSWORD_INVALID");
    const tampered = `${encrypted.slice(0, -2)}AA`;
    await expect(decryptLocalValue(tampered)).rejects.toThrow("LOCAL_VAULT_DATA_AUTHENTICATION_FAILED");
    await expect(decryptLocalValue(encrypted, "different-record-field")).rejects.toThrow("LOCAL_VAULT_DATA_AUTHENTICATION_FAILED");
  });

  it("requires an explicit strong local passphrase", async () => {
    await expect(createLocalVault("short")).rejects.toThrow("LOCAL_VAULT_PASSPHRASE_TOO_SHORT");
  });

  it("encrypts existing transaction records in place, resumes idempotently, and restores typed dates", async () => {
    const { key } = await createLocalVault("phrase héritage migration 2026");
    activateLocalVault(key);
    const legacy: LocalTransaction = {
      id: "legacy-tx-1", familyId: "family-test", amountCents: -12345,
      bookingDate: new Date("2026-10-07T10:00:00.000Z"), label: "Libellé hérité",
      categoryId: "Maison", personId: "person-test", isDeleted: false,
      createdAt: new Date("2026-10-07T09:00:00.000Z"), createdByUserId: "owner-test",
      syncStatus: "pending", updatedAt: new Date("2026-10-07T10:00:00.000Z"),
    };
    const migrated = await encodeLocalRecord("transactions", legacy);
    const resumed = await encodeLocalRecord("transactions", migrated);
    const restored = await decodeLocalRecord("transactions", resumed);

    expect(migrated.amountCents).not.toBe(legacy.amountCents);
    expect(migrated.label).not.toContain("Libellé hérité");
    expect(resumed).toEqual(migrated);
    expect(restored).toEqual(legacy);
  });

  it("encrypts sensitive copies in sync queues and conflict logs", async () => {
    const { key } = await createLocalVault("phrase queue conflict 2026");
    activateLocalVault(key);
    const queue = { id: "queue-1", familyId: "family-test", entity: "transaction" as const, entityId: "tx-1", operation: "create" as const, payload: { label: "Loyer privé", amountCents: -95000 }, createdAt: new Date(), attempts: 0 };
    const conflict = { id: "conflict-1", familyId: "family-test", entity: "transaction", entityId: "tx-1", localVersion: { label: "Loyer privé" }, serverVersion: { amountCents: -95000 }, resolution: "pending" as const };
    const encryptedQueue = await encodeLocalRecord("syncQueue", queue);
    const encryptedConflict = await encodeLocalRecord("conflicts", conflict);

    expect(JSON.stringify(encryptedQueue)).not.toContain("Loyer privé");
    expect(JSON.stringify(encryptedConflict)).not.toContain("95000");
    await expect(decodeLocalRecord("syncQueue", encryptedQueue)).resolves.toEqual(queue);
    await expect(decodeLocalRecord("conflicts", encryptedConflict)).resolves.toEqual(conflict);
  });

  it("chiffre le profil questionnaire dans le coffre au repos", async () => {
    const { key } = await createLocalVault("phrase profil local 2026");
    activateLocalVault(key);
    const profile = { id: "primary" as const, schemaVersion: 1 as const, createdAt: "2026-10-07T12:00:00.000Z", updatedAt: "2026-10-07T12:00:00.000Z", completedAt: "2026-10-07T12:00:00.000Z", answers: { householdMode: "personal", incomePattern: "variable", budgetExperience: "starting", priorities: ["save"], wantedFeatures: ["transactions"], notificationPreference: "balanced" }, dashboard: { visibleCards: ["goals", "spending"], compact: false } };
    const stored = await encodeLocalRecord("userProfiles", { id: "primary" as const, payload: profile });
    expect(JSON.stringify(stored)).not.toContain("variable");
    expect(JSON.stringify(stored)).not.toContain("spending");
    await expect(decodeLocalRecord("userProfiles", stored)).resolves.toEqual({ id: "primary", payload: profile });
  });

  it("chiffre aussi les réponses intermédiaires du questionnaire", async () => {
    const { key } = await createLocalVault("phrase progression locale 2026");
    activateLocalVault(key);
    const progress = { id: "primary" as const, schemaVersion: 1 as const, status: "in-progress" as const, currentStep: 2, startedAt: "2026-10-07T12:00:00.000Z", updatedAt: "2026-10-07T12:05:00.000Z", answers: { householdMode: "family", incomePattern: "variable", budgetExperience: "starting", priorities: ["save"], wantedFeatures: ["transactions"], notificationPreference: "balanced" }, dashboard: { visibleCards: ["goals", "spending"], compact: false } };
    const stored = await encodeLocalRecord("userProfiles", { id: "primary" as const, payload: progress });
    expect(JSON.stringify(stored)).not.toContain("variable");
    expect(JSON.stringify(stored)).not.toContain("family");
    await expect(decodeLocalRecord("userProfiles", stored)).resolves.toEqual({ id: "primary", payload: progress });
  });
});
