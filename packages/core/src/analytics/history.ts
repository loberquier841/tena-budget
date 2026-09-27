
import { Transaction } from "../budget/transaction";
import { Budget } from "../budget/budget";
import { filterValidTransactions, getSpendingByCategory, getMonthlyEvolution, getBudgetVsSpent } from "./stats";

// Historique / comparaison - jamais inclure simulations

export interface Period {
  from: Date;
  to: Date;
  label: string;
}

export interface ComparisonResult {
  periodA: { label: string; totalSpentCents: number; totalBudgetedCents: number; totalRemainingCents: number; byCategory: ReturnType<typeof getSpendingByCategory>; monthly: ReturnType<typeof getMonthlyEvolution> };
  periodB: { label: string; totalSpentCents: number; totalBudgetedCents: number; totalRemainingCents: number; byCategory: ReturnType<typeof getSpendingByCategory>; monthly: ReturnType<typeof getMonthlyEvolution> };
  diff: { spentDiffCents: number; budgetedDiffCents: number; remainingDiffCents: number; spentDiffPercentInt: number }; // percentInt sans float arrondi final seulement
}

export function comparePeriods(transactions: Transaction[], budgets: Budget[], categories: any[], periodA: Period, periodB: Period, filters: { familyId: string; personId?: string; categoryId?: string }): ComparisonResult {
  // Toujours exclure isDeleted et simulations (simulations jamais dans transactions réelles)
  const filterA = { familyId: filters.familyId, personId: filters.personId, categoryId: filters.categoryId, fromDate: periodA.from, toDate: periodA.to };
  const filterB = { familyId: filters.familyId, personId: filters.personId, categoryId: filters.categoryId, fromDate: periodB.from, toDate: periodB.to };

  const byCatA = getSpendingByCategory(transactions, categories, filterA as any);
  const byCatB = getSpendingByCategory(transactions, categories, filterB as any);

  const monthlyA = getMonthlyEvolution(transactions, filterA as any);
  const monthlyB = getMonthlyEvolution(transactions, filterB as any);

  const budgetVsA = getBudgetVsSpent(budgets, transactions, { ...filterA, year: periodA.from.getFullYear() } as any);
  const budgetVsB = getBudgetVsSpent(budgets, transactions, { ...filterB, year: periodB.from.getFullYear() } as any);

  const validTransactionsA = filterValidTransactions(transactions, filterA as any);
  const validTransactionsB = filterValidTransactions(transactions, filterB as any);

  const totalSpentA = validTransactionsA.reduce((s, t) => s + t.amountCents, 0);
  const totalSpentB = validTransactionsB.reduce((s, t) => s + t.amountCents, 0);

  const totalBudgetedA = budgetVsA.reduce((s, b) => s + b.budgetedCents, 0);
  const totalBudgetedB = budgetVsB.reduce((s, b) => s + b.budgetedCents, 0);

  const totalRemainingA = totalBudgetedA - totalSpentA;
  const totalRemainingB = totalBudgetedB - totalSpentB;

  const spentDiffCents = totalSpentB - totalSpentA;
  const budgetedDiffCents = totalBudgetedB - totalBudgetedA;
  const remainingDiffCents = totalRemainingB - totalRemainingA;

  // percent sans float: floor(diff*100 / base) si base !=0
  const spentDiffPercentInt = totalSpentA !== 0 ? Math.floor((spentDiffCents * 100) / totalSpentA) : 0;

  return {
    periodA: { label: periodA.label, totalSpentCents: totalSpentA, totalBudgetedCents: totalBudgetedA, totalRemainingCents: totalRemainingA, byCategory: byCatA, monthly: monthlyA },
    periodB: { label: periodB.label, totalSpentCents: totalSpentB, totalBudgetedCents: totalBudgetedB, totalRemainingCents: totalRemainingB, byCategory: byCatB, monthly: monthlyB },
    diff: { spentDiffCents, budgetedDiffCents, remainingDiffCents, spentDiffPercentInt },
  };
}

export function compareYearNvsNMinus1(transactions: Transaction[], budgets: Budget[], categories: any[], year: number, filters: { familyId: string; personId?: string; categoryId?: string }): ComparisonResult {
  const periodA: Period = { from: new Date(year - 1, 0, 1), to: new Date(year - 1, 11, 31, 23, 59, 59), label: `${year - 1}` };
  const periodB: Period = { from: new Date(year, 0, 1), to: new Date(year, 11, 31, 23, 59, 59), label: `${year}` };
  return comparePeriods(transactions, budgets, categories, periodA, periodB, filters);
}

export function getHistory(transactions: Transaction[], year: number, familyId: string): { year: number; totalCents: number; count: number }[] {
  // Historique réel - jamais simulations
  const valid = transactions.filter(t => t.familyId === familyId && !t.isDeleted && t.bookingDate.getFullYear() <= year);
  const map = new Map<number, { totalCents: number; count: number }>();
  for (const t of valid) {
    const y = t.bookingDate.getFullYear();
    const entry = map.get(y) || { totalCents: 0, count: 0 };
    entry.totalCents += t.amountCents;
    entry.count += 1;
    map.set(y, entry);
  }
  return Array.from(map.entries()).map(([yr, v]) => ({ year: yr, totalCents: v.totalCents, count: v.count })).sort((a,b) => a.year - b.year);
}
