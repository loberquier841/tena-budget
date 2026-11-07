// Connecteurs open banking (stubs, aucun SDK réel). Lecture seule uniquement.

import { IBankProviderAdapter, BankProvider, BankAccount, BankTransactionRaw, BankConnectionStatus } from "./interface";

export interface ConnectorMeta { id: string; name: string; region: string; readOnly: true; }

export const CONNECTOR_META: ConnectorMeta[] = [
  { id: 'powens', name: 'Powens (Budget Insight)', region: 'EU', readOnly: true },
  { id: 'bridge', name: 'Bridge (Bankin)', region: 'EU', readOnly: true },
  { id: 'tink', name: 'Tink (Visa)', region: 'EU', readOnly: true },
  { id: 'truelayer', name: 'TrueLayer', region: 'EU/UK', readOnly: true },
];

export class StubConnector implements IBankProviderAdapter {
  constructor(public provider: BankProvider) {}
  async createConsent(familyId: string, userId: string) {
    return { consentId: `stub_${this.provider.id}_${Date.now()}`, redirectUrl: `https://consent.example/${this.provider.id}`, expiresAt: new Date(Date.now() + this.provider.consentDurationDays * 86400000) };
  }
  async getAccounts(consentId: string): Promise<BankAccount[]> { return []; }
  async getTransactions(accountId: string, from: Date, to: Date): Promise<BankTransactionRaw[]> { return []; }
  async revokeConsent(consentId: string): Promise<void> {}
}
export function createConnector(id: string): StubConnector | null {
  const p = { id, name: id, supportsReadOnly: true, requiresConsent: true, consentDurationDays: 90 };
  return new StubConnector(p as any);
}
