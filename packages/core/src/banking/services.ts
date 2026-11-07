// Services bancaires locaux (in-memory, local-first). Aucun SDK réel.

import { TenaAccount, TenaCard, TenaOperation, Beneficiary, SavingsGoal, Envelope, PatrimonySnapshot, BankConsent, maskIban, savingsProgress, envelopeRemaining, netWorth, isConsentValid, revokeConsent, dedupHash } from "./domain";
import { autoCategorize } from "./intelligence";

// Accounts
export function createAccount(input: Omit<TenaAccount, 'id' | 'openedAt' | 'ibanMasked'> & { iban: string }): TenaAccount {
  return { ...input, id: `acc_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`, openedAt: new Date(), ibanMasked: maskIban(input.iban) };
}
export function updateBalance(acc: TenaAccount, deltaCents: number): TenaAccount { return { ...acc, balanceCents: acc.balanceCents + deltaCents }; }
export function closeAccount(acc: TenaAccount): TenaAccount { return { ...acc, closedAt: new Date() }; }
export function accountsByCurrency(accs: TenaAccount[], currency: string): TenaAccount[] { return accs.filter(a => a.currency === currency && !a.closedAt); }

// Cards
export function createCard(input: Omit<TenaCard, 'id' | 'createdAt' | 'status'> & { status?: TenaCard['status'] }): TenaCard {
  return { ...input, id: `card_${Date.now()}`, createdAt: new Date(), status: input.status || 'active' };
}
export function blockCard(c: TenaCard): TenaCard { return { ...c, status: 'blocked' }; }
export function unblockCard(c: TenaCard): TenaCard { return { ...c, status: 'active' }; }
export function cardCanSpend(c: TenaCard, amountCents: number, dailySpent: number): boolean {
  if (c.status !== 'active') return false;
  if (dailySpent + amountCents > c.dailyLimitCents) return false;
  return true;
}

// Operations
export function createOperation(input: Omit<TenaOperation, 'id' | 'createdAt' | 'hashDedup' | 'status'> & { status?: TenaOperation['status'] }): TenaOperation {
  const op: TenaOperation = { ...input, id: `op_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`, createdAt: new Date(), status: input.status || 'pending', hashDedup: '' };
  op.hashDedup = dedupHash(op);
  if (!op.category) (op as any).category = autoCategorize(op.label);
  return op;
}
export function detectDuplicateOps(ops: TenaOperation[]): TenaOperation[][] {
  const groups = new Map<string, TenaOperation[]>();
  for (const o of ops) { const arr = groups.get(o.hashDedup) || []; arr.push(o); groups.set(o.hashDedup, arr); }
  return [...groups.values()].filter(g => g.length > 1);
}
export function reconcileOps(local: TenaOperation[], remote: TenaOperation[]): { matched: TenaOperation[]; onlyLocal: TenaOperation[]; onlyRemote: TenaOperation[] } {
  const remoteHashes = new Set(remote.map(r => r.hashDedup));
  const localHashes = new Set(local.map(l => l.hashDedup));
  const matched = local.filter(l => remoteHashes.has(l.hashDedup));
  const onlyLocal = local.filter(l => !remoteHashes.has(l.hashDedup));
  const onlyRemote = remote.filter(r => !localHashes.has(r.hashDedup));
  return { matched, onlyLocal, onlyRemote };
}

// Savings
export function addContribution(g: SavingsGoal, amountCents: number): SavingsGoal {
  return { ...g, currentCents: g.currentCents + amountCents };
}
export function projectedCompletion(g: SavingsGoal, monthlyCents: number): Date | null {
  if (monthlyCents <= 0) return null;
  const remaining = g.targetCents - g.currentCents;
  if (remaining <= 0) return new Date();
  const months = Math.ceil(remaining / monthlyCents);
  const d = new Date(); d.setMonth(d.getMonth() + months);
  return d;
}
export function createEnvelope(input: Omit<Envelope, 'id' | 'spentCents'> & { spentCents?: number }): Envelope {
  return { ...input, id: `env_${Date.now()}`, spentCents: input.spentCents || 0 };
}
export function spendEnvelope(e: Envelope, amountCents: number): Envelope { return { ...e, spentCents: e.spentCents + amountCents }; }

// Patrimony
export function createSnapshot(input: Omit<PatrimonySnapshot, 'id'>): PatrimonySnapshot {
  return { ...input, id: `snap_${Date.now()}` };
}
export function patrimonyEvolution(snaps: PatrimonySnapshot[]): { from: number; to: number; delta: number } {
  if (snaps.length < 2) return { from: 0, to: snaps[0]?.totalAssetsCents || 0, delta: 0 };
  const sorted = [...snaps].sort((a, b) => a.takenAt.getTime() - b.takenAt.getTime());
  const from = sorted[0].totalAssetsCents - sorted[0].totalLiabilitiesCents;
  const to = sorted[sorted.length - 1].totalAssetsCents - sorted[sorted.length - 1].totalLiabilitiesCents;
  return { from, to, delta: to - from };
}

// Consent
export function createConsent(input: Omit<BankConsent, 'id' | 'createdAt' | 'status'> & { status?: BankConsent['status'] }): BankConsent {
  return { ...input, id: `consent_${Date.now()}`, createdAt: new Date(), status: input.status || 'pending' };
}
export function activateConsent(c: BankConsent): BankConsent { return { ...c, status: 'active' }; }
export function isExpired(c: BankConsent, now = new Date()): boolean { return !isConsentValid(c, now); }

// Beneficiary
export function createBeneficiary(input: Omit<Beneficiary, 'id' | 'createdAt' | 'ibanMasked'> & { iban: string }): Beneficiary {
  return { ...input, id: `ben_${Date.now()}`, createdAt: new Date(), ibanMasked: maskIban(input.iban) };
}

export { savingsProgress, envelopeRemaining, netWorth, isConsentValid, revokeConsent };
