
import { Transaction } from "../budget/transaction";

// RGPD - Anonymisation et suppression définitive encadrée - Étape 14

export interface AnonymizationResult {
  id: string;
  originalLabel: string;
  anonymizedLabel: string;
  originalAmountCents: number;
  anonymized: boolean;
  deletedAt: Date;
}

export function anonymizeTransaction(transaction: Transaction): AnonymizationResult {
  // Anonymisation après 30j isDeleted
  if (!transaction.isDeleted || !transaction.deletedAt) {
    throw new Error("ANONYMIZATION_REQUIRES_SOFT_DELETE");
  }
  const daysSinceDelete = (Date.now() - transaction.deletedAt.getTime()) / (1000 * 60 * 60 * 24);
  if (daysSinceDelete < 30) {
    throw new Error("ANONYMIZATION_REQUIRES_30_DAYS");
  }

  return {
    id: transaction.id,
    originalLabel: transaction.label,
    anonymizedLabel: "ANONYMIZED",
    originalAmountCents: transaction.amountCents,
    anonymized: true,
    deletedAt: transaction.deletedAt,
  };
}

export function shouldAnonymize(transaction: Transaction): boolean {
  if (!transaction.isDeleted || !transaction.deletedAt) return false;
  const daysSinceDelete = (Date.now() - transaction.deletedAt.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceDelete >= 30;
}

export function hardDeleteTransaction(transaction: Transaction, requestingRole: string, familyId: string, confirmOwner: boolean): { deleted: boolean; reason?: string } {
  // Suppression définitive encadrée - uniquement owner + confirmation + 30j + familyId isolé
  if (transaction.familyId !== familyId) {
    return { deleted: false, reason: "FAMILYID_MISMATCH" };
  }
  if (requestingRole !== 'owner') {
    return { deleted: false, reason: "REQUIRES_OWNER" };
  }
  if (!confirmOwner) {
    return { deleted: false, reason: "OWNER_CONFIRMATION_REQUIRED" };
  }
  if (!transaction.isDeleted) {
    return { deleted: false, reason: "REQUIRES_SOFT_DELETE_FIRST" };
  }
  if (!shouldAnonymize(transaction)) {
    return { deleted: false, reason: "REQUIRES_30_DAYS" };
  }

  // Hard delete autorisé
  return { deleted: true };
}

export function runAnonymizationJob(transactions: Transaction[]): { anonymized: AnonymizationResult[]; pending: Transaction[] } {
  const anonymized: AnonymizationResult[] = [];
  const pending: Transaction[] = [];

  for (const t of transactions) {
    if (shouldAnonymize(t)) {
      try {
        const result = anonymizeTransaction(t);
        anonymized.push(result);
      } catch {
        pending.push(t);
      }
    } else if (t.isDeleted) {
      pending.push(t);
    }
  }

  return { anonymized, pending };
}
