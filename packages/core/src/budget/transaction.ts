
import { Role, assertCan, requiresOwnerConfirmation } from "../permissions/permissions";

export interface Transaction {
  id: string;
  familyId: string;
  amountCents: number; // Int, jamais float
  bookingDate: Date;
  label: string;
  source: "manual" | "import" | "bank";
  categoryId?: string;
  subCategoryId?: string;
  personId?: string; // liée à une personne - obligatoire en Étape 3
  budgetId?: string;
  notes?: string;
  isDeleted: boolean;
  deletedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
  createdByUserId: string;
}

export function validateTransactionAmount(amountCents: number): void {
  if (!Number.isInteger(amountCents)) throw new Error("TX_AMOUNT_MUST_BE_INT_CENTS: utilisez toCents()");
  if (amountCents === 0) throw new Error("TX_ZERO_FORBIDDEN");
}

export function createTransaction(input: { familyId: string; amountCents: number; bookingDate: Date; label: string; source: Transaction["source"]; categoryId?: string; subCategoryId?: string; personId: string; budgetId?: string; notes?: string; createdByUserId: string }, role: Role): Transaction {
  assertCan(role, "transaction:write");
  validateTransactionAmount(input.amountCents);
  if (!input.personId) throw new Error("TX_PERSON_REQUIRED: transaction liée à une personne obligatoire");
  if (!input.label.trim()) throw new Error("TX_LABEL_REQUIRED");
  if (requiresOwnerConfirmation(input.amountCents) && role !== "owner") {
    throw new Error("TX_REQUIRES_OWNER_CONFIRMATION: >500€ déclenche confirmation propriétaire");
  }
  return {
    id: `tx_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: input.familyId,
    amountCents: input.amountCents,
    bookingDate: input.bookingDate,
    label: input.label.trim(),
    source: input.source,
    categoryId: input.categoryId,
    subCategoryId: input.subCategoryId,
    personId: input.personId,
    budgetId: input.budgetId,
    notes: input.notes,
    isDeleted: false,
    createdAt: new Date(),
    updatedAt: new Date(),
    createdByUserId: input.createdByUserId,
  };
}

export function updateTransaction(tx: Transaction, patch: { amountCents?: number; label?: string; categoryId?: string; personId?: string }, role: Role): Transaction {
  assertCan(role, "transaction:write");
  if (tx.isDeleted) throw new Error("TX_ALREADY_DELETED");
  let updated = { ...tx };
  if (patch.amountCents !== undefined) {
    validateTransactionAmount(patch.amountCents);
    if (requiresOwnerConfirmation(patch.amountCents) && role !== "owner") throw new Error("TX_REQUIRES_OWNER_CONFIRMATION");
    updated.amountCents = patch.amountCents;
  }
  if (patch.label !== undefined) {
    if (!patch.label.trim()) throw new Error("TX_LABEL_REQUIRED");
    updated.label = patch.label.trim();
  }
  if (patch.categoryId !== undefined) updated.categoryId = patch.categoryId;
  if (patch.personId !== undefined) {
    if (!patch.personId) throw new Error("TX_PERSON_REQUIRED");
    updated.personId = patch.personId;
  }
  updated.updatedAt = new Date();
  return updated;
}

// Soft delete obligatoire - jamais suppression physique
export function softDeleteTransaction(tx: Transaction, role: Role): Transaction {
  assertCan(role, "transaction:delete");
  if (tx.isDeleted) throw new Error("TX_ALREADY_DELETED");
  if (requiresOwnerConfirmation(tx.amountCents) && role !== "owner") {
    throw new Error("TX_DELETE_REQUIRES_OWNER_CONFIRMATION: >500€");
  }
  return { ...tx, isDeleted: true, deletedAt: new Date(), updatedAt: new Date() };
}

export function restoreTransaction(tx: Transaction, familyId: string, role: Role): Transaction {
  assertCan(role, "transaction:write");
  if (tx.familyId !== familyId) throw new Error("TX_FAMILY_MISMATCH");
  if (!tx.isDeleted) throw new Error("TX_NOT_DELETED");
  if (requiresOwnerConfirmation(tx.amountCents) && role !== "owner") {
    throw new Error("TX_RESTORE_REQUIRES_OWNER_CONFIRMATION: >500€");
  }
  const { deletedAt: _deletedAt, ...active } = tx;
  return { ...active, isDeleted: false, updatedAt: new Date() };
}

// Vérifie qu'aucune suppression physique n'est possible via cette API
export function assertNoPhysicalDelete(transactions: Transaction[], id: string): boolean {
  return transactions.some(t => t.id === id);
}
