
import { Transaction } from "../budget/transaction";
import { Budget, calculateRemaining } from "../budget/budget";
import { Category } from "../budget/category";
import { SavingGoal, calculateProgress } from "../budget/savings";

// Toutes valeurs internes en Int centimes, aucun Float, isDeleted exclu, simulations exclues

export interface StatsFilters {
  familyId: string;
  personId?: string;
  fromDate?: Date;
  toDate?: Date;
  categoryId?: string;
  includeGlobalOnly?: boolean; // true = seulement budgets familiaux sans personId
}

export function filterValidTransactions(transactions: Transaction[], filters: StatsFilters): Transaction[] {
  return transactions.filter(t => {
    if (t.familyId !== filters.familyId) return false;
    if (t.isDeleted) return false; // toujours exclu
    if (filters.personId && t.personId !== filters.personId) return false;
    if (filters.includeGlobalOnly && t.personId) return false; // ne pas mélanger individuel et global
    if (filters.categoryId && t.categoryId !== filters.categoryId) return false;
    if (filters.fromDate && t.bookingDate < filters.fromDate) return false;
    if (filters.toDate && t.bookingDate > filters.toDate) return false;
    return true;
  });
}

export function getSpendingByCategory(transactions: Transaction[], categories: Category[], filters: StatsFilters): { categoryId: string; categoryName: string; totalCents: number; count: number; subCategories: { subId: string; name: string; totalCents: number }[] }[] {
  const valid = filterValidTransactions(transactions, filters);
  const parents = categories.filter(c => !c.parentId && !c.isArchived);
  return parents.map(parent => {
    const parentTx = valid.filter(t => t.categoryId === parent.id || categories.find(c => c.id === t.categoryId)?.parentId === parent.id);
    const totalCents = parentTx.reduce((sum, t) => sum + Math.abs(t.amountCents), 0); // dépenses bancaires souvent signées négativement
    const children = categories.filter(c => c.parentId === parent.id && !c.isArchived);
    const subCategories = children.map(child => {
      const childTx = valid.filter(t => t.categoryId === child.id);
      return { subId: child.id, name: child.name, totalCents: childTx.reduce((s, t) => s + Math.abs(t.amountCents), 0) };
    });
    return { categoryId: parent.id, categoryName: parent.name, totalCents, count: parentTx.length, subCategories };
  }).filter(r => r.totalCents !== 0 || r.subCategories.some(sc => sc.totalCents !== 0));
}

export function getSpendingByPerson(transactions: Transaction[], filters: Omit<StatsFilters, 'personId'>): { personId: string; totalCents: number; count: number }[] {
  const valid = filterValidTransactions(transactions, filters as any);
  const map = new Map<string, { totalCents: number; count: number }>();
  for (const t of valid) {
    const pid = t.personId || '__no_person__';
    const entry = map.get(pid) || { totalCents: 0, count: 0 };
    entry.totalCents += Math.abs(t.amountCents); // Int
    entry.count += 1;
    map.set(pid, entry);
  }
  return Array.from(map.entries()).map(([personId, v]) => ({ personId, totalCents: v.totalCents, count: v.count }));
}

export function getMonthlyEvolution(transactions: Transaction[], filters: StatsFilters): { year: number; month: number; totalCents: number; count: number }[] {
  const valid = filterValidTransactions(transactions, filters);
  const map = new Map<string, { year: number; month: number; totalCents: number; count: number }>();
  for (const t of valid) {
    const year = t.bookingDate.getFullYear();
    const month = t.bookingDate.getMonth() + 1;
    const key = `${year}-${month}`;
    const entry = map.get(key) || { year, month, totalCents: 0, count: 0 };
    entry.totalCents += Math.abs(t.amountCents);
    entry.count += 1;
    map.set(key, entry);
  }
  return Array.from(map.values()).sort((a,b) => a.year !== b.year ? a.year - b.year : a.month - b.month);
}

export function getAnnualEvolution(transactions: Transaction[], filters: StatsFilters): { year: number; totalCents: number; count: number }[] {
  const valid = filterValidTransactions(transactions, filters);
  const map = new Map<number, { year: number; totalCents: number; count: number }>();
  for (const t of valid) {
    const year = t.bookingDate.getFullYear();
    const entry = map.get(year) || { year, totalCents: 0, count: 0 };
    entry.totalCents += Math.abs(t.amountCents);
    entry.count += 1;
    map.set(year, entry);
  }
  return Array.from(map.values()).sort((a,b) => a.year - b.year);
}

export function getBudgetVsSpent(budgets: Budget[], transactions: Transaction[], filters: StatsFilters & { year?: number; month?: number }): { budgetId: string; type: string; year: number; month?: number; categoryId?: string; personId?: string; budgetedCents: number; spentCents: number; remainingCents: number }[] {
  let filteredBudgets = budgets.filter(b => b.familyId === filters.familyId);
  if (filters.year !== undefined) filteredBudgets = filteredBudgets.filter(b => b.year === filters.year);
  if (filters.month !== undefined) filteredBudgets = filteredBudgets.filter(b => b.type === 'monthly' ? b.month === filters.month : true);
  if (filters.personId) {
    // Ne jamais mélanger: si personId filtré, on prend budgets avec ce personId OU globaux si includeGlobalOnly false?
    // Règle: si personId demandé, on retourne seulement budgets de cette personne + on calcule avec transactions de cette personne
    filteredBudgets = filteredBudgets.filter(b => b.personId === filters.personId || !b.personId && !filters.personId); // si filtre personne, on garde seulement ceux de la personne
    // Pour strict no mixing: si personId filtré, on exclut globaux
    if (filters.personId) filteredBudgets = filteredBudgets.filter(b => b.personId === filters.personId);
  }
  if (filters.includeGlobalOnly) filteredBudgets = filteredBudgets.filter(b => !b.personId);
  if (filters.categoryId) filteredBudgets = filteredBudgets.filter(b => b.categoryId === filters.categoryId);

  const validTx = filterValidTransactions(transactions, filters);

  return filteredBudgets.map(b => {
    const relevant = validTx.filter(t => t.bookingDate.getFullYear() === b.year && (!b.month || t.bookingDate.getMonth() + 1 === b.month) && (b.categoryId ? t.categoryId === b.categoryId : true) && (b.personId ? t.personId === b.personId : true) && (b.id ? (t.budgetId === b.id || !t.budgetId) : true));
    const spentCents = relevant.reduce((s, t) => s + Math.abs(t.amountCents), 0);
    const remainingCents = b.amountCents - spentCents; // Int - Int = Int
    if (!Number.isInteger(spentCents) || !Number.isInteger(remainingCents)) throw new Error("STATS_INT_ONLY");
    return {
      budgetId: b.id,
      type: b.type,
      year: b.year,
      month: b.month,
      categoryId: b.categoryId,
      personId: b.personId,
      budgetedCents: b.amountCents,
      spentCents,
      remainingCents,
    };
  });
}

export interface BudgetAlert {
  budgetId: string;
  categoryId?: string;
  budgetedCents: number;
  spentCents: number;
  remainingCents: number;
  usagePercent: number;
  severity: 'warning' | 'over-budget';
}

/** Détecte les budgets proches du plafond ou dépassés, sans modifier les données. */
export function getBudgetAlerts(
  budgets: Array<{
    budgetId: string;
    categoryId?: string;
    budgetedCents: number;
    spentCents: number;
    remainingCents: number;
  }>,
): BudgetAlert[] {
  return budgets
    .filter(budget => budget.budgetedCents > 0 && budget.spentCents * 100 >= budget.budgetedCents * 80)
    .map(budget => ({
      ...budget,
      usagePercent: Math.floor((budget.spentCents * 100) / budget.budgetedCents),
      severity: budget.spentCents > budget.budgetedCents ? 'over-budget' as const : 'warning' as const,
    }))
    .sort((a, b) => {
      if (a.severity !== b.severity) return a.severity === 'over-budget' ? -1 : 1;
      return b.usagePercent - a.usagePercent;
    });
}

export function getSavingsStats(goals: SavingGoal[], filters: StatsFilters): { goalId: string; name: string; personId?: string; targetCents: number; currentCents: number; remainingCents: number; percentInt: number; isExceeded: boolean }[] {
  let filtered = goals.filter(g => g.familyId === filters.familyId && !g.isDeleted);
  if (filters.personId) filtered = filtered.filter(g => g.personId === filters.personId);
  return filtered.map(g => {
    const prog = calculateProgress(g);
    return {
      goalId: g.id,
      name: g.name,
      personId: g.personId,
      targetCents: prog.targetCents,
      currentCents: prog.currentCents,
      remainingCents: prog.remainingCents,
      percentInt: prog.percentInt,
      isExceeded: prog.isExceeded,
    };
  });
}
