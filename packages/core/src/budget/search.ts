
import { Transaction } from "./transaction";

export interface SearchFilters {
  familyId: string;
  personId?: string;
  categoryId?: string;
  subCategoryId?: string;
  source?: Transaction["source"];
  fromDate?: Date;
  toDate?: Date;
  minAmountCents?: number;
  maxAmountCents?: number;
  labelContains?: string;
  includeDeleted?: boolean;
  budgetId?: string;
}

export function filterTransactions(transactions: Transaction[], filters: SearchFilters): Transaction[] {
  return transactions.filter(t => {
    if (t.familyId !== filters.familyId) return false;
    if (!filters.includeDeleted && t.isDeleted) return false;
    if (filters.personId && t.personId !== filters.personId) return false;
    if (filters.categoryId && t.categoryId !== filters.categoryId) return false;
    if (filters.subCategoryId && t.subCategoryId !== filters.subCategoryId) return false;
    if (filters.source && t.source !== filters.source) return false;
    if (filters.budgetId && t.budgetId !== filters.budgetId) return false;
    if (filters.fromDate && t.bookingDate < filters.fromDate) return false;
    if (filters.toDate && t.bookingDate > filters.toDate) return false;
    if (filters.minAmountCents !== undefined && t.amountCents < filters.minAmountCents) return false;
    if (filters.maxAmountCents !== undefined && t.amountCents > filters.maxAmountCents) return false;
    if (filters.labelContains && !t.label.toLowerCase().includes(filters.labelContains.toLowerCase())) return false;
    return true;
  });
}

export function searchTransactions(transactions: Transaction[], query: string, familyId: string): Transaction[] {
  const q = query.toLowerCase().trim();
  if (!q) return transactions.filter(t => t.familyId === familyId && !t.isDeleted);
  return transactions.filter(t => {
    if (t.familyId !== familyId || t.isDeleted) return false;
    return t.label.toLowerCase().includes(q) || (t.notes && t.notes.toLowerCase().includes(q));
  });
}
