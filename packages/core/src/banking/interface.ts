
import { Role } from "../permissions/permissions";

// Interface bancaire abstraite - lecture seule uniquement - aucun SDK réel
// Réutilise exactement le pipeline import 11 étapes

export type BankConnectionStatus = 'pending' | 'active' | 'revoked' | 'expired';
export type BankSyncStatus = 'idle' | 'syncing' | 'success' | 'error';

export interface BankProvider {
  id: string; // ex: 'mock', 'gocardless', 'tink' - mais aucun choisi définitivement pour l'instant
  name: string;
  supportsReadOnly: boolean; // lecture seule uniquement
  requiresConsent: boolean;
  consentDurationDays: number;
}

export interface BankConnection {
  id: string;
  familyId: string;
  userId: string;
  providerId: string; // mock pour l'instant
  consentId?: string;
  status: BankConnectionStatus;
  consentExpiresAt?: Date;
  lastSyncAt?: Date;
  createdAt: Date;
  revokedAt?: Date;
}

export interface BankAccount {
  id: string;
  connectionId: string;
  externalId: string; // ID externe fournisseur, pas stocké comme secret bancaire
  name: string;
  ibanMasked: string; // uniquement masqué, jamais complet: FR76 **** **** 1234
  balanceCents: number; // Int centimes, lecture seule
  currency: string;
}

export interface BankTransactionRaw {
  id: string;
  accountId: string;
  externalId: string; // unique externe
  amountCents: number; // Int centimes
  bookingDate: Date;
  label: string;
  rawData: any; // données brutes fournisseur (lecture seule)
  hashDedup: string; // pour réimport/doublons
  importedAsTransactionId?: string; // lien vers Transaction réelle après validation humaine
}

export interface BankSyncLog {
  id: string;
  connectionId: string;
  startedAt: Date;
  finishedAt?: Date;
  status: BankSyncStatus;
  errorCode?: string;
  transactionsFetched: number;
}

// Interface provider - uniquement lecture seule, aucun identifiant bancaire stocké par TENΛ
export interface IBankProviderAdapter {
  provider: BankProvider;
  createConsent(familyId: string, userId: string): Promise<{ consentId: string; redirectUrl: string; expiresAt: Date }>;
  getAccounts(consentId: string): Promise<BankAccount[]>;
  getTransactions(accountId: string, from: Date, to: Date): Promise<BankTransactionRaw[]>;
  revokeConsent(consentId: string): Promise<void>;
}

// Aucun SDK réel pour l'instant - uniquement interface
export const COMPATIBLE_PROVIDERS: BankProvider[] = [
  { id: 'mock', name: 'Mock (tests uniquement)', supportsReadOnly: true, requiresConsent: true, consentDurationDays: 90 },
  { id: 'gocardless', name: 'GoCardless (ex Nordigen)', supportsReadOnly: true, requiresConsent: true, consentDurationDays: 90 },
  { id: 'tink', name: 'Tink (Visa)', supportsReadOnly: true, requiresConsent: true, consentDurationDays: 90 },
  { id: 'plaid', name: 'Plaid (US/EU)', supportsReadOnly: true, requiresConsent: true, consentDurationDays: 90 },
  { id: 'budget-insight', name: 'Budget Insight / Powens', supportsReadOnly: true, requiresConsent: true, consentDurationDays: 180 },
];

// Aucun fournisseur définitif choisi - à comparer avec propriétaire après Étape 11
export function getProviderById(id: string): BankProvider | undefined {
  return COMPATIBLE_PROVIDERS.find(p => p.id === id);
}
