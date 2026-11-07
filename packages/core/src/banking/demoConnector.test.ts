import { describe, it, expect } from "vitest";
import { DemoBankConnector, runSync } from "./demoConnector";

describe("demo connector", () => {
  it("returns fake accounts", async () => {
    const c = new DemoBankConnector();
    const consent = await c.createConsent('f', 'u');
    const accs = await c.getAccounts(consent.consentId);
    expect(accs.length).toBe(2);
    expect(accs[0].ibanMasked).toContain('****');
  });
  it("returns demo transactions", async () => {
    const c = new DemoBankConnector();
    const txs = await c.getTransactions('demo_acc_1', new Date('2026-10-01'), new Date('2026-10-31'));
    expect(txs.length).toBe(3);
    expect(txs[0].rawData.demo).toBe(true);
  });
  it("sync detects duplicates", async () => {
    const c = new DemoBankConnector();
    const accs = await c.getAccounts('x');
    const existing = new Set<string>();
    const r1 = await runSync(c, 'consent', accs, new Date('2026-10-01'), new Date('2026-10-31'), existing);
    expect(r1.newTxs.length).toBe(6);
    const r2 = await runSync(c, 'consent', accs, new Date('2026-10-01'), new Date('2026-10-31'), existing);
    expect(r2.newTxs.length).toBe(0);
  });
});
