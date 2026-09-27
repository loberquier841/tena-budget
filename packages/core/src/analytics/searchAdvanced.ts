
import { Transaction } from "../budget/transaction";
import { Role, assertCan } from "../permissions/permissions";

export interface AdvancedSearchFilters {
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

export interface SortOptions {
  field: 'bookingDate' | 'amountCents' | 'label';
  direction: 'asc' | 'desc';
}

export interface Pagination {
  page: number; // 1-indexed
  pageSize: number; // max 100
}

export interface SearchResult {
  results: Transaction[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export function advancedSearch(transactions: Transaction[], filters: AdvancedSearchFilters, sort: SortOptions, pagination: Pagination, role: Role): SearchResult {
  assertCan(role, "transaction:read");
  if (pagination.page < 1) throw new Error("PAGE_MIN_1");
  if (pagination.pageSize < 1 || pagination.pageSize > 100) throw new Error("PAGESIZE_1_100");

  let filtered = transactions.filter(t => {
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
    if (filters.labelContains && !t.label.toLowerCase().includes(filters.labelContains.toLowerCase()) && !(t.notes && t.notes.toLowerCase().includes(filters.labelContains.toLowerCase()))) return false;
    return true;
  });

  // Tri - Int centimes
  filtered.sort((a,b) => {
    let cmp = 0;
    if (sort.field === 'bookingDate') cmp = a.bookingDate.getTime() - b.bookingDate.getTime();
    else if (sort.field === 'amountCents') cmp = a.amountCents - b.amountCents;
    else if (sort.field === 'label') cmp = a.label.localeCompare(b.label);
    return sort.direction === 'asc' ? cmp : -cmp;
  });

  const total = filtered.length;
  const totalPages = Math.ceil(total / pagination.pageSize);
  const start = (pagination.page - 1) * pagination.pageSize;
  const results = filtered.slice(start, start + pagination.pageSize);

  return { results, total, page: pagination.page, pageSize: pagination.pageSize, totalPages };
}
