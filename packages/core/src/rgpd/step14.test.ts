
import { describe, it, expect } from "vitest";
import { anonymizeTransaction, shouldAnonymize, hardDeleteTransaction, runAnonymizationJob } from "./anonymization";
import { REGISTRY, verifyRegistry } from "./registry";

describe("Étape 14 - RGPD - Anonymisation + Suppression définitive + Registre", () => {
  it("anonymisation après 30j isDeleted", () => {
    const tx: any = { id: 'tx1', familyId: 'fam1', amountCents: 8500, label: 'Courses', isDeleted: true, deletedAt: new Date(Date.now() - 31*24*60*60*1000) };
    expect(shouldAnonymize(tx)).toBe(true);
    const result = anonymizeTransaction(tx);
    expect(result.anonymized).toBe(true);
    expect(result.anonymizedLabel).toBe('ANONYMIZED');
  });

  it("anonymisation refuse <30j", () => {
    const tx: any = { id: 'tx1', familyId: 'fam1', amountCents: 8500, label: 'Courses', isDeleted: true, deletedAt: new Date() };
    expect(shouldAnonymize(tx)).toBe(false);
    expect(() => anonymizeTransaction(tx)).toThrow("ANONYMIZATION_REQUIRES_30_DAYS");
  });

  it("hard delete encadré owner + confirmation + 30j + familyId", () => {
    const tx: any = { id: 'tx1', familyId: 'fam1', amountCents: 8500, label: 'Courses', isDeleted: true, deletedAt: new Date(Date.now() - 31*24*60*60*1000) };
    expect(hardDeleteTransaction(tx, 'member', 'fam1', true).deleted).toBe(false);
    expect(hardDeleteTransaction(tx, 'owner', 'fam1', false).deleted).toBe(false);
    expect(hardDeleteTransaction(tx, 'owner', 'fam2', true).deleted).toBe(false);
    expect(hardDeleteTransaction(tx, 'owner', 'fam1', true).deleted).toBe(true);
  });

  it("runAnonymizationJob", () => {
    const txs: any[] = [
      { id: 'tx1', familyId: 'fam1', amountCents: 8500, label: 'Courses', isDeleted: true, deletedAt: new Date(Date.now() - 31*24*60*60*1000) },
      { id: 'tx2', familyId: 'fam1', amountCents: 6000, label: 'Essence', isDeleted: true, deletedAt: new Date() },
      { id: 'tx3', familyId: 'fam1', amountCents: 80000, label: 'Loyer', isDeleted: false },
    ];
    const result = runAnonymizationJob(txs);
    expect(result.anonymized.length).toBe(1);
    expect(result.pending.length).toBe(1);
  });

  it("registre 6 activités familyId isolé + isDeleted exclu", () => {
    expect(REGISTRY.length).toBe(6);
    expect(REGISTRY.every(r => r.familyIdIsolated && r.isDeletedExcluded)).toBe(true);
  });

  it("verifyRegistry", () => {
    const checks = verifyRegistry();
    expect(checks.length).toBe(6);
    expect(checks.every(c => c.status)).toBe(true);
  });
});
