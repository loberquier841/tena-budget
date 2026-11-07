// Connecteur de démonstration — données bancaires FICTIVES, clairement identifiées.
// Aucune connexion réelle. Lecture seule.

import { IBankProviderAdapter, BankProvider, BankAccount, BankTransactionRaw } from "./interface";

export const DEMO_PROVIDER: BankProvider = {
  id: 'demo', name: 'Démonstration (données fictives uniquement)', supportsReadOnly: true, requiresConsent: true, consentDurationDays: 90,
};

export class DemoBankConnector implements IBankProviderAdapter {
  provider = DEMO_PROVIDER;
  private accounts: BankAccount[] = [
    { id: 'demo_acc_1', connectionId: 'demo_conn', externalId: 'ext_1', name: 'Compte courant (démo)', ibanMasked: 'FR76 **** **** 1234', balanceCents: 245000, currency: 'EUR' },
    { id: 'demo_acc_2', connectionId: 'demo_conn', externalId: 'ext_2', name: 'Épargne (démo)', ibanMasked: 'FR76 **** **** 5678', balanceCents: 1200000, currency: 'EUR' },
  ];
  async createConsent(familyId: string, userId: string) {
    return { consentId: `demo_consent_${Date.now()}`, redirectUrl: 'https://demo.consent.local', expiresAt: new Date(Date.now() + 90 * 86400000) };
  }
  async getAccounts(consentId: string): Promise<BankAccount[]> { return this.accounts.map(a => ({ ...a })); }
  async getTransactions(accountId: string, from: Date, to: Date): Promise<BankTransactionRaw[]> {
    return [
      { id: `demo_tx_${accountId}_1`, accountId, externalId: 'ext_tx_1', amountCents: -4500, bookingDate: new Date('2026-10-01'), label: 'Courses Carrefour (démo)', rawData: { demo: true }, hashDedup: `${accountId}|-4500|Courses Carrefour (démo)|2026-10-01` },
      { id: `demo_tx_${accountId}_2`, accountId, externalId: 'ext_tx_2', amountCents: -1200, bookingDate: new Date('2026-10-05'), label: 'Netflix (démo)', rawData: { demo: true }, hashDedup: `${accountId}|-1200|Netflix (démo)|2026-10-05` },
      { id: `demo_tx_${accountId}_3`, accountId, externalId: 'ext_tx_3', amountCents: 250000, bookingDate: new Date('2026-10-10'), label: 'Salaire (démo)', rawData: { demo: true }, hashDedup: `${accountId}|250000|Salaire (démo)|2026-10-10` },
    ];
  }
  async revokeConsent(consentId: string): Promise<void> {}
}

// Sync engine
export interface SyncResult { connectionId: string; startedAt: Date; finishedAt: Date; status: 'success' | 'error'; transactionsFetched: number; errorCode?: string; newCount: number; duplicateCount: number; }
export async function runSync(connector: IBankProviderAdapter, consentId: string, accounts: BankAccount[], from: Date, to: Date, existingHashes: Set<string>): Promise<{ results: SyncResult[]; newTxs: BankTransactionRaw[] }> {
  const results: SyncResult[] = [];
  const newTxs: BankTransactionRaw[] = [];
  let dup = 0;
  for (const acc of accounts) {
    const started = new Date();
    try {
      const txs = await connector.getTransactions(acc.id, from, to);
      let fetched = 0;
      for (const t of txs) {
        fetched++;
        if (existingHashes.has(t.hashDedup)) { dup++; continue; }
        existingHashes.add(t.hashDedup);
        newTxs.push(t);
      }
      results.push({ connectionId: acc.connectionId || 'x', startedAt: started, finishedAt: new Date(), status: 'success', transactionsFetched: fetched, newCount: txs.length - (fetched - (txs.length - (fetched - 0))), duplicateCount: dup });
    } catch (e: any) {
      results.push({ connectionId: acc.connectionId || 'x', startedAt: started, finishedAt: new Date(), status: 'error', transactionsFetched: 0, errorCode: e?.message || 'unknown', newCount: 0, duplicateCount: 0 });
    }
  }
  // fix newCount
  for (const r of results) { if (r.status === 'success') r.newCount = r.transactionsFetched - r.duplicateCount; }
  return { results, newTxs };
}
