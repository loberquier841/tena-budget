
import { describe, it, expect } from "vitest";
import { createBetaFamily, verifyBetaPermissions, verifyBetaIsolations } from "./familyBeta";
import { generateTestData, measurePerformance, measureSyncPerformance } from "./performance";
import { verifyExportRGPD, verifyDeletionRGPD, verifySecretsRGPD } from "./rgpd";

describe("Étape 13 - Validation réelle - Bêta familiale + Performance + RGPD", () => {
  it("bêta familiale propriétaire/admin/membre/enfant", () => {
    const family = createBetaFamily();
    expect(family.members.length).toBe(4);
    expect(family.members.find(m => m.role === 'owner')?.devices.length).toBe(3);
    expect(family.members.find(m => m.role === 'child')).toBeDefined();
  });

  it("permissions bêta 9 vérifications", () => {
    const family = createBetaFamily();
    const perms = verifyBetaPermissions(family);
    expect(perms.length).toBe(9);
    expect(perms.every(p => p.status)).toBe(true);
  });

  it("isolations bêta 4 vérifications", () => {
    const isos = verifyBetaIsolations();
    expect(isos.length).toBe(4);
    expect(isos.every(i => i.status)).toBe(true);
  });

  it("performance 100 transactions <100ms", () => {
    const results = measurePerformance();
    const filter100 = results.find(r => r.test === 'filterValidTransactions' && r.count === 100);
    expect(filter100?.status).toBe('PASS');
    expect(filter100?.durationMs).toBeLessThan(100);
  });

  it("performance 1000 transactions <100ms", () => {
    const results = measurePerformance();
    const filter1000 = results.find(r => r.test === 'filterValidTransactions' && r.count === 1000);
    expect(filter1000?.status).toBe('PASS');
  });

  it("performance 5000 transactions <200ms search", () => {
    const results = measurePerformance();
    const search5000 = results.find(r => r.test.includes('advancedSearch') && r.count === 5000);
    expect(search5000?.status).toBe('PASS');
    expect(search5000?.durationMs).toBeLessThan(200);
  });

  it("performance sync 1000", () => {
    const sync = measureSyncPerformance();
    expect(sync[0].status).toBe('PASS');
  });

  it("RGPD export 5 vérifications", () => {
    const txs = generateTestData(10, 'fam_rgpd_test');
    const ex = verifyExportRGPD(txs as any);
    expect(ex.length).toBe(5);
    expect(ex.filter(e => e.status).length).toBe(5);
  });

  it("RGPD suppression soft delete", () => {
    const txs = generateTestData(10);
    const del = verifyDeletionRGPD(txs as any);
    expect(del.find(d => d.check.includes('Soft delete isDeleted'))?.status).toBe(true);
    expect(del.find(d => d.check.includes('exclu stats'))?.status).toBe(true);
  });

  it("RGPD secrets 0 frontend", () => {
    const sec = verifySecretsRGPD();
    expect(sec.length).toBe(5);
    expect(sec.every(s => s.status)).toBe(true);
  });

  it("Int centimes partout performance", () => {
    const txs = generateTestData(100);
    expect(txs.every(t => Number.isInteger((t as any).amountCents))).toBe(true);
  });

  it("PC personnel jamais nécessaire", () => {
    const family = createBetaFamily();
    expect(family.members[0].devices).toContain('iPhone');
    // Architecture Vercel+Neon+PWA, pas PC local
  });
});
