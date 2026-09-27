
import { describe, it, expect } from "vitest";
import { runFullAudit } from "./audit";

describe("Étape 12 - Audit sécurité complet", () => {
  it("audit permissions serveur 37 occurrences", () => {
    const audits = runFullAudit();
    const perm = audits.find(a => a.check === 'Permissions côté serveur');
    expect(perm?.status).toBe('PASS');
    expect(perm?.details).toContain('37');
  });

  it("audit isolation familyId", () => {
    const audits = runFullAudit();
    const iso = audits.find(a => a.check === 'Isolation familyId');
    expect(iso?.status).toBe('PASS');
    expect(iso?.details).toContain('familyId');
  });

  it("audit simulations isolation sim_/simtx_", () => {
    const audits = runFullAudit();
    const sim = audits.find(a => a.check === 'Simulations isolation');
    expect(sim?.status).toBe('PASS');
    expect(sim?.details).toContain('sim_');
  });

  it("audit transactions supprimées isDeleted", () => {
    const audits = runFullAudit();
    const del = audits.find(a => a.check === 'Transactions supprimées');
    expect(del?.status).toBe('PASS');
    expect(del?.details).toContain('isDeleted');
  });

  it("audit validations obligatoires", () => {
    const audits = runFullAudit();
    const val = audits.find(a => a.check === 'Validations obligatoires');
    expect(val?.status).toBe('PASS');
    expect(val?.details).toContain('VALIDATION_REQUIRED');
  });

  it("audit secrets aucun dans frontend", () => {
    const audits = runFullAudit();
    const sec = audits.find(a => a.check === 'Secrets et données sensibles');
    expect(sec?.status).toBe('PASS');
    expect(sec?.details).toContain('0 fichiers frontend');
  });

  it("audit PWA/offline/sync", () => {
    const audits = runFullAudit();
    const pwa = audits.find(a => a.check === 'PWA/offline/sync');
    expect(pwa?.status).toBe('PASS');
    expect(pwa?.details).toContain('Dexie');
  });

  it("audit responsive", () => {
    const audits = runFullAudit();
    const resp = audits.find(a => a.check === 'Responsive téléphone/tablette/ordinateur');
    expect(resp?.status).toBe('PASS');
  });

  it("audit cohérence 15 écrans", () => {
    const audits = runFullAudit();
    const coh = audits.find(a => a.check === 'Cohérence écrans');
    expect(coh?.status).toBe('PASS');
    expect(coh?.filesChecked).toBe(15);
  });

  it("audit backup/restore AES-GCM + SHA-256", () => {
    const audits = runFullAudit();
    const backup = audits.find(a => a.check === 'Sauvegardes/restaurations');
    expect(backup?.status).toBe('PASS');
    expect(backup?.details).toContain('AES-GCM');
    expect(backup?.details).toContain('SHA-256');
  });

  it("audit banking mock uniquement", () => {
    const audits = runFullAudit();
    const bank = audits.find(a => a.check === 'Module bancaire mock uniquement');
    expect(bank?.status).toBe('PASS');
    expect(bank?.details).toContain('MOCK_ONLY');
  });

  it("audit complet 11 vérifications toutes PASS", () => {
    const audits = runFullAudit();
    expect(audits.length).toBe(11);
    expect(audits.every(a => a.status === 'PASS')).toBe(true);
  });
});
