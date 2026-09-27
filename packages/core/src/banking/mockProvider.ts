
import { IBankProviderAdapter, BankProvider, BankAccount, BankTransactionRaw, BankConnection, BankSyncLog, COMPATIBLE_PROVIDERS } from "./interface";

// Mock provider uniquement - aucun SDK réel, aucune connexion vraie banque

export class MockBankProviderAdapter implements IBankProviderAdapter {
  provider: BankProvider = COMPATIBLE_PROVIDERS[0]; // mock

  async createConsent(familyId: string, userId: string): Promise<{ consentId: string; redirectUrl: string; expiresAt: Date }> {
    // Simulation consent - lecture seule uniquement
    const consentId = `consent_mock_${Date.now()}`;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 90);
    return {
      consentId,
      redirectUrl: `/banking/callback?consentId=${consentId}&familyId=${familyId}`,
      expiresAt,
    };
  }

  async getAccounts(consentId: string): Promise<BankAccount[]> {
    // Mock accounts - IBAN masqué uniquement, jamais complet
    return [
      {
        id: `acc_mock_1`,
        connectionId: `conn_${consentId}`,
        externalId: `ext_acc_1`,
        name: 'Compte Courant Mock',
        ibanMasked: 'FR76 **** **** 1234',
        balanceCents: 250000, // 2500€ Int
        currency: 'EUR',
      },
      {
        id: `acc_mock_2`,
        connectionId: `conn_${consentId}`,
        externalId: `ext_acc_2`,
        name: 'Livret A Mock',
        ibanMasked: 'FR76 **** **** 5678',
        balanceCents: 500000,
        currency: 'EUR',
      },
    ];
  }

  async getTransactions(accountId: string, from: Date, to: Date): Promise<BankTransactionRaw[]> {
    // Mock transactions - hashDedup pour réimport/doublons
    const mockLabels = ['Courses Leclerc', 'Loyer', 'Essence Total', 'Abonnement Netflix', 'Salaire'];
    const transactions: BankTransactionRaw[] = mockLabels.map((label, idx) => {
      const date = new Date(from);
      date.setDate(from.getDate() + idx * 7);
      const amountCents = [ -8500, -80000, -6000, -1299, 250000 ][idx];
      const hash = `${date.toISOString().slice(0,10)}|${amountCents}|${label.toLowerCase()}`;
      // hashDedup simple (même algo que import-engine)
      let h = 0;
      for (let i=0;i<hash.length;i++) h = (h*31 + hash.charCodeAt(i)) & 0xFFFFFFFF;
      return {
        id: `raw_mock_${idx}_${Date.now()}`,
        accountId,
        externalId: `ext_tx_${accountId}_${idx}`,
        amountCents,
        bookingDate: date,
        label,
        rawData: { mock: true, provider: 'mock', originalLabel: label },
        hashDedup: h.toString(16),
      };
    });

    return transactions.filter(t => t.bookingDate >= from && t.bookingDate <= to);
  }

  async revokeConsent(consentId: string): Promise<void> {
    // Mock revoke
    return;
  }
}

// Factory - retourne mock pour l'instant, aucun fournisseur définitif choisi
export function createBankAdapter(providerId: string = 'mock'): IBankProviderAdapter {
  if (providerId === 'mock') return new MockBankProviderAdapter();
  // Pour autres providers, on retourne mock aussi tant que non validé - aucun SDK réel
  console.warn(`Provider ${providerId} non validé - utilisation mock (aucun SDK réel pour Étape 11)`);
  return new MockBankProviderAdapter();
}

// Validation humaine obligatoire avant transformation en Transaction réelle
export function requiresHumanValidation(raw: BankTransactionRaw): boolean {
  return true; // toujours validation humaine obligatoire
}

export function transformToTransactionAfterValidation(raw: BankTransactionRaw, familyId: string, personId: string, userId: string, categoryId?: string): { familyId: string; amountCents: number; bookingDate: Date; label: string; source: 'bank'; personId: string; categoryId?: string; createdByUserId: string; rawId: string; hashDedup: string } {
  // Transformation uniquement après validation humaine
  if (!raw) throw new Error("RAW_REQUIRED");
  if (!familyId) throw new Error("FAMILYID_ISOLATED_REQUIRED");
  // familyId toujours isolé, simulations toujours exclues, aucun identifiant bancaire stocké
  return {
    familyId,
    amountCents: raw.amountCents,
    bookingDate: raw.bookingDate,
    label: raw.label,
    source: 'bank' as const,
    personId,
    categoryId,
    createdByUserId: userId,
    rawId: raw.id,
    hashDedup: raw.hashDedup,
  };
}
