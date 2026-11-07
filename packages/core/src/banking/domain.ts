// TENΛ Budget — Domaine bancaire local-first (aucun SDK réel, lecture seule via partenaires)
// Modèles et règles pures. Aucun identifiant bancaire stocké en clair.

export type AccountType = 'checking' | 'savings' | 'joint' | 'multi' | 'external';
export type Currency = string; // ISO 4217

export interface TenaAccount {
  id: string;
  familyId: string;
  userId: string;
  type: AccountType;
  name: string;
  ibanMasked: string; // jamais complet
  currency: Currency;
  balanceCents: number; // entiers
  openedAt: Date;
  closedAt?: Date;
  isExternal: boolean; // agrégé open banking
  connectionId?: string;
}

export type CardStatus = 'active' | 'blocked' | 'cancelled' | 'pending';
export interface TenaCard {
  id: string;
  accountId: string;
  familyId: string;
  label: string;
  last4: string; // uniquement 4 derniers
  isVirtual: boolean;
  status: CardStatus;
  dailyLimitCents: number;
  monthlyLimitCents: number;
  createdAt: Date;
}

export type OperationType = 'transfer' | 'direct_debit' | 'payment' | 'refund' | 'scheduled' | 'fee';
export type OperationStatus = 'pending' | 'completed' | 'failed' | 'cancelled';
export interface TenaOperation {
  id: string;
  accountId: string;
  familyId: string;
  type: OperationType;
  status: OperationStatus;
  amountCents: number; // signé: négatif = sortie
  currency: Currency;
  label: string;
  counterparty?: string;
  beneficiaryId?: string;
  scheduledFor?: Date;
  executedAt?: Date;
  createdAt: Date;
  externalId?: string;
  hashDedup: string;
}

export interface Beneficiary {
  id: string;
  familyId: string;
  name: string;
  ibanMasked: string;
  createdAt: Date;
}

// Épargne
export interface SavingsGoal {
  id: string;
  familyId: string;
  name: string;
  targetCents: number;
  currentCents: number;
  currency: Currency;
  deadline?: Date;
  accountId?: string;
  createdAt: Date;
}

export interface Envelope {
  id: string;
  familyId: string;
  name: string;
  budgetCents: number;
  spentCents: number;
  currency: Currency;
}

// Patrimoine
export interface PatrimonySnapshot {
  id: string;
  familyId: string;
  takenAt: Date;
  totalAssetsCents: number;
  totalLiabilitiesCents: number;
  currency: Currency;
  breakdown: { label: string; amountCents: number }[];
}

// Consentement open banking
export type ConsentStatus = 'pending' | 'active' | 'revoked' | 'expired';
export interface BankConsent {
  id: string;
  familyId: string;
  userId: string;
  providerId: string;
  status: ConsentStatus;
  scopes: string[]; // 'accounts:read', 'transactions:read'
  redirectUrl?: string;
  expiresAt: Date;
  createdAt: Date;
  revokedAt?: Date;
}

export function isConsentValid(c: BankConsent, now: Date = new Date()): boolean {
  if (c.status !== 'active') return false;
  return c.expiresAt.getTime() > now.getTime();
}

export function revokeConsent(c: BankConsent, now: Date = new Date()): BankConsent {
  return { ...c, status: 'revoked', revokedAt: now };
}

// Règles pures
export function totalBalanceCents(accounts: TenaAccount[]): number {
  return accounts.reduce((s, a) => s + a.balanceCents, 0);
}

export function savingsProgress(g: SavingsGoal): number {
  if (g.targetCents <= 0) return 0;
  const p = g.currentCents / g.targetCents;
  return Math.max(0, Math.min(1, p));
}

export function envelopeRemaining(e: Envelope): number {
  return e.budgetCents - e.spentCents;
}

export function netWorth(s: PatrimonySnapshot): number {
  return s.totalAssetsCents - s.totalLiabilitiesCents;
}

export function maskIban(iban: string): string {
  const clean = iban.replace(/\s+/g, '');
  if (clean.length < 8) return '****';
  return `${clean.slice(0, 4)} **** **** ${clean.slice(-4)}`;
}

export function dedupHash(op: { accountId: string; amountCents: number; label: string; executedAt?: Date }): string {
  const d = op.executedAt ? op.executedAt.toISOString().slice(0, 10) : '';
  return `${op.accountId}|${op.amountCents}|${op.label}|${d}`;
}
