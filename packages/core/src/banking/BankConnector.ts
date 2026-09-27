// MOCK ONLY - Aucun SDK bancaire réel pour Étape 11
export const BANKING_MOCK_ONLY = true;
export class BankConnector {
  static readonly MOCK_ONLY = true;
  static readonly NO_REAL_SDK = true;
  static readonly READ_ONLY = true;
  async connect() { return { mock: true, consentId: `mock_${Date.now()}` }; }
  async getAccounts() { return [{ id: 'mock', ibanMasked: 'FR76 **** **** 1234', balanceCents: 0 }]; }
  async getTransactions() { return []; }
}
