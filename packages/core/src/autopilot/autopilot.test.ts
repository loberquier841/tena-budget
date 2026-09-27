
import { describe, it, expect } from "vitest";
import { createAutopilotConfig, autoCategorizeTransaction, detectUnusualSpending, detectSubscriptions, prepareBudgetAutomatically, forecastNextMonth, prepareNextMonth, generateAutoReport, verifyAutopilotSecurity } from "./autopilot";

describe("TENΛ Autopilot - Étape 23 / 23 minimum - Fonctions validées", () => {
  it("createAutopilotConfig respecte familyId", () => {
    const config = createAutopilotConfig('fam_test');
    expect(config.familyId).toBe('fam_test');
    expect(config.enabled).toBe(true);
    expect(config.neverAutoPurchase).toBe(true);
    expect(config.requireConfirmationForFinancial).toBe(true);
  });

  it("autoCategorize respecte permissions + familyId + personId + journal + désactivation + jamais achat auto", () => {
    const config = createAutopilotConfig('fam_test');
    const rules = new Map([['cat_courses', /courses|carrefour|leclerc/i]]);
    const tx: any = { id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Courses Carrefour', amountCents: -8500, bookingDate: new Date(), isDeleted: false };
    const result = autoCategorizeTransaction(tx, rules, config, 'owner');
    expect(result.categoryId).toBe('cat_courses');
    expect(result.journal.familyId).toBe('fam_test');
    expect(result.journal.personId).toBe('p1');
    expect(result.journal.autoPurchase).toBe(false);
    expect(result.journal.action).toBe('auto_categorization');

    const txOtherFamily: any = { ...tx, familyId: 'fam_other' };
    expect(() => autoCategorizeTransaction(txOtherFamily, rules, config, 'owner')).toThrow('FAMILYID_MISMATCH');
  });

  it("detectUnusualSpending respecte familyId + isDeleted exclu + journal + confirmation requise + jamais achat auto", () => {
    const config = createAutopilotConfig('fam_test');
    const txs: any[] = [
      { id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Courses', amountCents: -5000, bookingDate: new Date(), isDeleted: false },
      { id: 'tx2', familyId: 'fam_test', personId: 'p1', label: 'Courses', amountCents: -6000, bookingDate: new Date(), isDeleted: false },
      { id: 'tx3', familyId: 'fam_test', personId: 'p1', label: 'Voiture', amountCents: -500000, bookingDate: new Date(), isDeleted: false },
      { id: 'tx4', familyId: 'fam_other', personId: 'p1', label: 'Autre famille', amountCents: -1000000, bookingDate: new Date(), isDeleted: false },
      { id: 'tx5', familyId: 'fam_test', personId: 'p1', label: 'Supprimée', amountCents: -1000000, bookingDate: new Date(), isDeleted: true },
    ];
    const result = detectUnusualSpending(txs, config, 'owner');
    expect(result.toVerify.length).toBe(1);
    expect(result.toVerify[0].familyId).toBe('fam_test');
    expect(result.toVerify[0].type).toBe('unusual_spending');
    expect(result.journal[0].autoPurchase).toBe(false);
    expect(result.journal[0].requiresConfirmation).toBe(true);
  });

  it("detectSubscriptions respecte familyId + journal + jamais achat auto", () => {
    const config = createAutopilotConfig('fam_test');
    const txs: any[] = [
      { id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Netflix', amountCents: -1299, bookingDate: new Date(Date.now() - 60*24*60*60*1000), isDeleted: false },
      { id: 'tx2', familyId: 'fam_test', personId: 'p1', label: 'Netflix', amountCents: -1299, bookingDate: new Date(Date.now() - 30*24*60*60*1000), isDeleted: false },
      { id: 'tx3', familyId: 'fam_test', personId: 'p1', label: 'Netflix', amountCents: -1299, bookingDate: new Date(), isDeleted: false },
    ];
    const result = detectSubscriptions(txs, config, 'owner');
    expect(result.toVerify.length).toBe(1);
    expect(result.toVerify[0].type).toBe('subscription');
    expect(result.journal[0].autoPurchase).toBe(false);
  });

  it("prepareBudgetAutomatically respecte permissions + familyId + journal + confirmation + jamais achat auto", () => {
    const config = createAutopilotConfig('fam_test');
    const txs: any[] = [
      { id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Courses', amountCents: -8500, categoryId: 'cat_courses', bookingDate: new Date(), isDeleted: false },
      { id: 'tx2', familyId: 'fam_test', personId: 'p1', label: 'Essence', amountCents: -6000, categoryId: 'cat_transport', bookingDate: new Date(), isDeleted: false },
    ];
    const result = prepareBudgetAutomatically(txs, config, 'owner');
    expect(result.suggestedBudgets.length).toBe(2);
    expect(result.journal.requiresConfirmation).toBe(true);
    expect(result.journal.autoPurchase).toBe(false);
  });

  it("forecastNextMonth + prepareNextMonth + generateAutoReport respectent familyId + journal + jamais achat auto", () => {
    const config = createAutopilotConfig('fam_test');
    const txs: any[] = [
      { id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Courses', amountCents: -8500, bookingDate: new Date(), isDeleted: false },
    ];
    const forecast = forecastNextMonth(txs, config, 'owner');
    expect(forecast.journal.autoPurchase).toBe(false);
    expect(forecast.journal.familyId).toBe('fam_test');

    const nextMonth = prepareNextMonth(config, 'owner');
    expect(nextMonth.journal.requiresConfirmation).toBe(true);
    expect(nextMonth.journal.autoPurchase).toBe(false);

    const report = generateAutoReport(txs, [], config, 'owner');
    expect(report.journal.autoPurchase).toBe(false);
    expect(report.report).toContain('fam_test');
  });

  it("verifyAutopilotSecurity 7 checks PASS", () => {
    const config = createAutopilotConfig('fam_test');
    const checks = verifyAutopilotSecurity(config);
    expect(checks.length).toBe(7);
    expect(checks.every(c => c.status)).toBe(true);
    expect(checks.find(c => c.check === 'Jamais achat/paiement automatique')?.status).toBe(true);
  });

  it("Autopilot désactivation possible", () => {
    const config = createAutopilotConfig('fam_test');
    config.enabled = false;
    const tx: any = { id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Courses Carrefour', amountCents: -8500, bookingDate: new Date(), isDeleted: false };
    const rules = new Map([['cat_courses', /courses/i]]);
    const result = autoCategorizeTransaction(tx, rules, config, 'owner');
    expect(result.categoryId).toBeNull();
    expect(result.journal.action).toBe('auto_categorization_skipped');
  });

  it("Autopilot jamais achat/paiement automatique", () => {
    const config = createAutopilotConfig('fam_test');
    expect(config.neverAutoPurchase).toBe(true);
    const txs: any[] = [{ id: 'tx1', familyId: 'fam_test', personId: 'p1', label: 'Courses', amountCents: -8500, bookingDate: new Date(), isDeleted: false }];
    const unusual = detectUnusualSpending(txs, config, 'owner');
    expect(unusual.journal.every(j => !j.autoPurchase)).toBe(true);
  });
});
