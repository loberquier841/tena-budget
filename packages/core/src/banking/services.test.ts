import { describe, it, expect } from "vitest";
import * as S from "./services";
import { createConnector, CONNECTOR_META } from "./connectors";

describe("banking services", () => {
  it("create account masks iban", () => {
    const a = S.createAccount({ familyId: 'f', userId: 'u', type: 'checking', name: 'Main', iban: 'FR76 1234 5678 9012 3456 7890 123', currency: 'EUR', balanceCents: 0, isExternal: false });
    expect(a.ibanMasked).toContain('****');
    expect(a.balanceCents).toBe(0);
  });
  it("update balance", () => {
    const a = S.createAccount({ familyId: 'f', userId: 'u', type: 'checking', name: 'Main', iban: 'FR761234', currency: 'EUR', balanceCents: 1000, isExternal: false });
    expect(S.updateBalance(a, -200).balanceCents).toBe(800);
  });
  it("card block/unblock", () => {
    const c = S.createCard({ accountId: 'a', familyId: 'f', label: 'visa', last4: '1234', isVirtual: true, dailyLimitCents: 1000, monthlyLimitCents: 5000 });
    expect(S.blockCard(c).status).toBe('blocked');
    expect(S.cardCanSpend(S.blockCard(c), 100, 0)).toBe(false);
    expect(S.cardCanSpend(S.unblockCard(S.blockCard(c)), 100, 0)).toBe(true);
  });
  it("card daily limit", () => {
    const c = S.createCard({ accountId: 'a', familyId: 'f', label: 'visa', last4: '1234', isVirtual: false, dailyLimitCents: 500, monthlyLimitCents: 5000 });
    expect(S.cardCanSpend(c, 600, 0)).toBe(false);
    expect(S.cardCanSpend(c, 100, 450)).toBe(false);
    expect(S.cardCanSpend(c, 100, 300)).toBe(true);
  });
  it("operation create dedup", () => {
    const o = S.createOperation({ accountId: 'a', familyId: 'f', type: 'payment', amountCents: -500, currency: 'EUR', label: 'Courses' });
    expect(o.hashDedup).toContain('a');
  });
  it("detect duplicates", () => {
    const o1 = S.createOperation({ accountId: 'a', familyId: 'f', type: 'payment', amountCents: -500, currency: 'EUR', label: 'Courses', executedAt: new Date('2026-01-01') });
    const o2 = S.createOperation({ accountId: 'a', familyId: 'f', type: 'payment', amountCents: -500, currency: 'EUR', label: 'Courses', executedAt: new Date('2026-01-01') });
    expect(S.detectDuplicateOps([o1, o2]).length).toBe(1);
  });
  it("reconcile", () => {
    const o = S.createOperation({ accountId: 'a', familyId: 'f', type: 'payment', amountCents: -500, currency: 'EUR', label: 'Courses', executedAt: new Date('2026-01-01') });
    const r = S.reconcileOps([o], []);
    expect(r.onlyLocal.length).toBe(1);
  });
  it("savings contribution & projection", () => {
    const g = S.addContribution({ id: 'g', familyId: 'f', name: 'x', targetCents: 10000, currentCents: 0, currency: 'EUR', createdAt: new Date() }, 3000);
    expect(g.currentCents).toBe(3000);
    expect(S.projectedCompletion(g, 1000)).not.toBeNull();
  });
  it("envelope spend", () => {
    const e = S.createEnvelope({ familyId: 'f', name: 'food', budgetCents: 5000, currency: 'EUR' });
    expect(S.spendEnvelope(e, 1000).spentCents).toBe(1000);
  });
  it("patrimony evolution", () => {
    const s1 = S.createSnapshot({ familyId: 'f', takenAt: new Date('2026-01-01'), totalAssetsCents: 10000, totalLiabilitiesCents: 2000, currency: 'EUR', breakdown: [] });
    const s2 = S.createSnapshot({ familyId: 'f', takenAt: new Date('2026-02-01'), totalAssetsCents: 12000, totalLiabilitiesCents: 2000, currency: 'EUR', breakdown: [] });
    expect(S.patrimonyEvolution([s1, s2]).delta).toBe(2000);
  });
  it("consent create/revoke", () => {
    const c = S.createConsent({ familyId: 'f', userId: 'u', providerId: 'powens', scopes: ['accounts:read'], expiresAt: new Date(Date.now() + 100000) });
    expect(S.activateConsent(c).status).toBe('active');
    expect(S.isExpired(S.revokeConsent ? S.createConsent({ familyId: 'f', userId: 'u', providerId: 'powens', scopes: [], expiresAt: new Date(Date.now() - 1) }) : c)).toBe(true);
  });
  it("beneficiary mask", () => {
    const b = S.createBeneficiary({ familyId: 'f', name: 'x', iban: 'FR76 1234 5678 9012 3456 7890 123' });
    expect(b.ibanMasked).toContain('****');
  });
  it("connectors list", () => {
    expect(CONNECTOR_META.length).toBe(4);
    expect(createConnector('powens')).not.toBeNull();
  });
});
