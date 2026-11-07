import { describe, it, expect } from "vitest";
import { maskIban, savingsProgress, envelopeRemaining, netWorth, totalBalanceCents, isConsentValid, revokeConsent, dedupHash } from "./domain";
import { autoCategorize, detectSubscriptions, detectUnusual, forecastCashflow, generateAlerts, spendingByCategory } from "./intelligence";

describe("banking domain", () => {
  it("mask iban", () => {
    expect(maskIban("FR76 1234 5678 9012 3456 7890 123")).toContain("****");
    expect(maskIban("FR76 1234 5678 9012 3456 7890 123")).not.toContain("1234 5678");
  });
  it("savings progress clamped", () => {
    expect(savingsProgress({ id: 'g', familyId: 'f', name: 'x', targetCents: 10000, currentCents: 5000, currency: 'EUR', createdAt: new Date() })).toBe(0.5);
    expect(savingsProgress({ id: 'g', familyId: 'f', name: 'x', targetCents: 0, currentCents: 5000, currency: 'EUR', createdAt: new Date() })).toBe(0);
  });
  it("envelope remaining", () => {
    expect(envelopeRemaining({ id: 'e', familyId: 'f', name: 'x', budgetCents: 1000, spentCents: 300, currency: 'EUR' })).toBe(700);
  });
  it("net worth", () => {
    expect(netWorth({ id: 's', familyId: 'f', takenAt: new Date(), totalAssetsCents: 10000, totalLiabilitiesCents: 3000, currency: 'EUR', breakdown: [] })).toBe(7000);
  });
  it("total balance", () => {
    expect(totalBalanceCents([{ id: 'a', familyId: 'f', userId: 'u', type: 'checking', name: 'x', ibanMasked: 'x', currency: 'EUR', balanceCents: 100, openedAt: new Date(), isExternal: false }] as any)).toBe(100);
  });
  it("consent validity", () => {
    const c: any = { id: 'c', familyId: 'f', userId: 'u', providerId: 'mock', status: 'active', scopes: [], expiresAt: new Date(Date.now() + 10000), createdAt: new Date() };
    expect(isConsentValid(c)).toBe(true);
    const r = revokeConsent(c);
    expect(r.status).toBe('revoked');
    expect(isConsentValid(r)).toBe(false);
  });
  it("dedup hash", () => {
    expect(dedupHash({ accountId: 'a', amountCents: -100, label: 'x', executedAt: new Date('2026-01-01') })).toContain('a');
  });
});

describe("intelligence", () => {
  it("auto categorize", () => {
    expect(autoCategorize("Carrefour Market")).toBe("alimentation");
    expect(autoCategorize("Netflix")).toBe("loisirs");
    expect(autoCategorize("foo")).toBe("autre");
  });
  it("spending by category", () => {
    const r = spendingByCategory([{ amountCents: -500, label: 'a', date: new Date(), category: 'food' }, { amountCents: 1000, label: 'b', date: new Date() }]);
    expect(r.food).toBe(500);
  });
  it("detect subscriptions", () => {
    const base = new Date('2026-01-01');
    const txs = [0, 1, 2].map(i => ({ amountCents: -999, label: 'Netflix', date: new Date(base.getTime() + i * 30 * 86400000) }));
    expect(detectSubscriptions(txs).length).toBe(1);
  });
  it("forecast cashflow", () => {
    const txs = [{ amountCents: -100, label: 'x', date: new Date() }];
    expect(forecastCashflow(txs, 2).length).toBe(2);
  });
  it("generate alerts", () => {
    const txs = [{ amountCents: -10000, label: 'x', date: new Date() }];
    const a = generateAlerts(txs, 1000);
    expect(a.some(x => x.level === 'critical')).toBe(true);
  });
});
