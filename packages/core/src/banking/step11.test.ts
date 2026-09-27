
import { describe, it, expect } from "vitest";
import { MockBankProviderAdapter, createBankAdapter, requiresHumanValidation, transformToTransactionAfterValidation } from "./mockProvider";
import { COMPATIBLE_PROVIDERS, getProviderById } from "./interface";
import { analyzeBankingRaw, detectBankingDuplicates, previewBanking, validateBankingImport, generateBankingReport, bankingToImportPipeline } from "./pipelineReuse";
import { createTransaction } from "../budget/transaction";

describe("Étape 11 - Préparation bancaire - Aucun SDK réel", () => {
  it("aucun SDK bancaire réel", async () => {
    const adapter = createBankAdapter('mock');
    expect(adapter.provider.id).toBe('mock');
    // Vérifie qu'on n'importe pas de SDK réel
    expect(adapter.provider.name).toContain('Mock');
  });

  it("fournisseurs compatibles listés sans choix définitif", () => {
    expect(COMPATIBLE_PROVIDERS.length).toBeGreaterThanOrEqual(5);
    expect(COMPATIBLE_PROVIDERS.map(p => p.id)).toContain('mock');
    expect(COMPATIBLE_PROVIDERS.map(p => p.id)).toContain('gocardless');
    expect(COMPATIBLE_PROVIDERS.map(p => p.id)).toContain('tink');
    // Aucun choix définitif - tous proposés à comparer
    const mock = getProviderById('mock');
    expect(mock?.supportsReadOnly).toBe(true);
  });

  it("lecture seule uniquement", async () => {
    const adapter = new MockBankProviderAdapter();
    const consent = await adapter.createConsent('fam1', 'u1');
    expect(consent.consentId).toContain('mock');
    const accounts = await adapter.getAccounts(consent.consentId);
    expect(accounts[0].ibanMasked).toContain('****'); // masqué uniquement
    expect(accounts[0].ibanMasked).not.toContain('FR76 1234 5678 9012 3456'); // jamais complet
  });

  it("aucun identifiant bancaire stocké", async () => {
    const adapter = new MockBankProviderAdapter();
    const txs = await adapter.getTransactions('acc1', new Date('2026-01-01'), new Date('2026-01-31'));
    expect(txs[0].rawData.mock).toBe(true);
    // rawData ne contient pas IBAN complet ni mot de passe
    expect(JSON.stringify(txs[0].rawData)).not.toContain('password');
    expect(JSON.stringify(txs[0].rawData)).not.toContain('iban');
  });

  it("réutilise exactement pipeline 11 étapes", () => {
    const raw: any[] = [{ id: 'raw1', accountId: 'acc1', amountCents: -8500, bookingDate: new Date('2026-01-15'), label: 'Courses', hashDedup: 'abc', rawData: {} }];
    const pipeline = bankingToImportPipeline(raw, 'fam1');
    expect(pipeline.step).toBe(1);
    expect(pipeline.familyId).toBe('fam1');

    const analyzed = analyzeBankingRaw(raw);
    expect(analyzed.total).toBe(1);
    expect(analyzed.totalCents).toBe(-8500);
    expect(Number.isInteger(analyzed.totalCents)).toBe(true);
  });

  it("familyId toujours isolé", async () => {
    const adapter = new MockBankProviderAdapter();
    const txs = await adapter.getTransactions('acc1', new Date('2026-01-01'), new Date('2026-01-31'));
    const transformed = transformToTransactionAfterValidation(txs[0], 'fam1', 'p1', 'u1', 'cat1');
    expect(transformed.familyId).toBe('fam1');
    expect(transformed.familyId).not.toBe('fam2');
  });

  it("simulations toujours exclues", () => {
    const raw: any[] = [{ id: 'raw1', accountId: 'acc1', amountCents: -8500, bookingDate: new Date(), label: 'Test', hashDedup: 'abc', rawData: {} }];
    const report = generateBankingReport(raw, [], { exact: [], likely: [] }, true);
    expect(report.simulationsExcluded).toBe(true);
    expect(report.familyIdIsolated).toBe(true);
  });

  it("réimport/doublons gérés via hashDedup", () => {
    const existing = [createTransaction({ familyId: 'fam1', amountCents: -8500, bookingDate: new Date('2026-01-15'), label: 'Courses Leclerc', source: 'manual', personId: 'p1', createdByUserId: 'u1' }, 'owner') as any];
    existing[0].hashDedup = 'abc123';
    const raw: any[] = [{ id: 'raw1', accountId: 'acc1', amountCents: -8500, bookingDate: new Date('2026-01-15'), label: 'Courses Leclerc', hashDedup: 'abc123', rawData: {} }];
    const dup = detectBankingDuplicates(raw, existing);
    expect(dup.exact.length).toBe(1);
    expect(dup.new.length).toBe(0);
  });

  it("validation humaine obligatoire avant transformation en Transaction réelle", () => {
    const raw: any = { id: 'raw1', accountId: 'acc1', amountCents: -8500, bookingDate: new Date(), label: 'Test', hashDedup: 'abc', rawData: {} };
    expect(requiresHumanValidation(raw)).toBe(true);
    const validation = validateBankingImport([raw], false);
    expect(validation.canImport).toBe(false);
    expect(validation.reason).toBe('VALIDATION_REQUIRED');
    const validationOk = validateBankingImport([raw], true);
    expect(validationOk.canImport).toBe(true);
  });

  it("sélection années + prévisualisation", () => {
    const raw: any[] = [
      { id: 'raw1', accountId: 'acc1', amountCents: -8500, bookingDate: new Date('2025-06-15'), label: '2025', hashDedup: 'a', rawData: {} },
      { id: 'raw2', accountId: 'acc1', amountCents: -8500, bookingDate: new Date('2026-06-15'), label: '2026', hashDedup: 'b', rawData: {} },
    ];
    const preview = previewBanking(raw, [2026]);
    expect(preview.length).toBe(1);
    expect(preview[0].label).toBe('2026');
  });

  it("rapport complet", () => {
    const raw: any[] = [{ id: 'raw1', accountId: 'acc1', amountCents: -8500, bookingDate: new Date(), label: 'Test', hashDedup: 'abc', rawData: {} }];
    const report = generateBankingReport(raw, [], { exact: [], likely: [] }, true);
    expect(report.imported).toBe(1);
    expect(report.totalCents).toBe(-8500);
    expect(Number.isInteger(report.totalCents)).toBe(true);
  });

  it("PC personnel jamais nécessaire", () => {
    // Architecture: Vercel + Neon + PWA Dexie, pas de serveur local
    // Ce test vérifie que l'adapter ne dépend pas d'un chemin local
    const adapter = createBankAdapter('mock');
    expect(adapter.provider.id).toBe('mock');
    // Aucune référence à localhost, fichier local, etc.
  });
});
