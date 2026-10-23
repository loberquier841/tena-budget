import { Role, assertCan, requiresOwnerConfirmation } from "../permissions/permissions";

// Seuil financier important
const FINANCIAL_THRESHOLD_CENTS = 50000; // 500€

export interface Budget {
  id: string;
  familyId: string;
  type: "annual" | "monthly";
  year: number;
  month?: number; // 1-12
  categoryId?: string;
  personId?: string;
  amountCents: number; // Int centimes, jamais float
  createdAt: Date;
  updatedAt: Date;
}

// Validation du montant du budget
export function validateBudgetAmount(amountCents: number): void {
  if (!Number.isInteger(amountCents)) throw new Error("BUDGET_AMOUNT_MUST_BE_INT_CENTS");
  if (amountCents < 0) throw new Error("BUDGET_NEGATIVE_FORBIDDEN");
  if (amountCents === 0) throw new Error("BUDGET_ZERO_FORBIDDEN: le montant ne peut pas être zéro");
}

// Création d'un budget
export function createBudget(input: { familyId: string; type: "annual" | "monthly"; year: number; month?: number; categoryId?: string; personId?: string; amountCents: number }, role: Role, existing: Budget[]): Budget {
  assertCan(role, "budget:write");
  validateBudgetAmount(input.amountCents);
  if (input.type === "monthly" && (!input.month || input.month < 1 || input.month > 12)) throw new Error("BUDGET_MONTH_REQUIRED");
  if (input.type === "annual" && input.month) throw new Error("BUDGET_ANNUAL_NO_MONTH");

  const dup = existing.find(b => b.familyId === input.familyId && b.type === input.type && b.year === input.year && b.month === input.month && b.categoryId === input.categoryId && b.personId === input.personId);
  if (dup) throw new Error("BUDGET_DUPLICATE");

  if (requiresOwnerConfirmation(input.amountCents) && role !== "owner") {
    throw new Error("BUDGET_REQUIRES_OWNER_CONFIRMATION: >500€");
  }

  return {
    id: `bud_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: input.familyId,
    type: input.type,
    year: input.year,
    month: input.month,
    categoryId: input.categoryId,
    personId: input.personId,
    amountCents: input.amountCents,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

// Mise à jour d'un budget
export function updateBudget(budget: Budget, patch: { amountCents?: number }, role: Role): Budget {
  assertCan(role, "budget:write");
  if (patch.amountCents !== undefined) {
    validateBudgetAmount(patch.amountCents);
    if (requiresOwnerConfirmation(patch.amountCents) && role !== "owner") throw new Error("BUDGET_REQUIRES_OWNER_CONFIRMATION");
    return { ...budget, amountCents: patch.amountCents, updatedAt: new Date() };
  }
  return budget;
}

// Calcul budget restant en temps réel - Int centimes only
export function calculateRemaining(budget: Budget, transactions: { amountCents: number; isDeleted: boolean; budgetId?: string; categoryId?: string; bookingDate: Date }[]): number {
  const relevant = transactions.filter(t => !t.isDeleted &&
    (budget.categoryId && t.categoryId === budget.categoryId ||
     (budget.id && t.budgetId === budget.id) ||
     (!budget.categoryId && !budget.id)
  ));
  // Pour simplifier Étape 3: toutes transactions de la même année/mois/catégorie
  const spent = relevant.reduce((sum, t) => sum + t.amountCents, 0);
  // amountCents - spent (tous Int)
  return budget.amountCents - spent;
}

// Budgets pour une période donnée
export function getBudgetsForPeriod(budgets: Budget[], year: number, month?: number): Budget[] {
  return budgets.filter(b => b.year === year && (month === undefined || b.month === month));
}
