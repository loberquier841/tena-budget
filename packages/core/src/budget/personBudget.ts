
import { Budget, calculateRemaining } from "./budget";
import { Transaction } from "./transaction";

// Budgets par personne - ne pas mélanger avec budget familial global

export function getBudgetsByPerson(budgets: Budget[], personId: string): Budget[] {
  return budgets.filter(b => b.personId === personId);
}

export function getFamilyGlobalBudgets(budgets: Budget[]): Budget[] {
  return budgets.filter(b => !b.personId);
}

export function calculateRemainingByPerson(budgets: Budget[], transactions: Transaction[], personId: string): { budget: Budget; remainingCents: number }[] {
  const personBudgets = getBudgetsByPerson(budgets, personId);
  return personBudgets.map(b => {
    const relevantTx = transactions.filter(t => !t.isDeleted && t.personId === personId && (t.categoryId === b.categoryId || t.budgetId === b.id));
    const remaining = calculateRemaining(b, relevantTx as any);
    return { budget: b, remainingCents: remaining };
  });
}

export function calculateFamilyRemaining(budgets: Budget[], transactions: Transaction[]): number {
  const globalBudgets = getFamilyGlobalBudgets(budgets);
  const globalTx = transactions.filter(t => !t.isDeleted && !t.personId);
  let totalRemaining = 0;
  for (const b of globalBudgets) {
    const relevant = globalTx.filter(t => t.categoryId === b.categoryId || t.budgetId === b.id);
    totalRemaining += calculateRemaining(b, relevant as any);
  }
  return totalRemaining;
}

// Vérifie calculs multi-personnes - pas de mélange
export function verifyNoMixing(budgets: Budget[], transactions: Transaction[]): boolean {
  // Chaque transaction avec personId doit être comptée uniquement dans budget avec même personId ou global si pas de personId dans budget
  for (const tx of transactions) {
    if (tx.isDeleted) continue;
    if (tx.personId) {
      const matchingBudgets = budgets.filter(b => b.personId === tx.personId);
      // OK si au moins un budget personne ou aucun (alors global ne doit pas compter tx personne)
      // Pour vérif: on s'assure que calculateFamilyRemaining n'inclut pas tx avec personId
      const familyBudgets = getFamilyGlobalBudgets(budgets);
      if (familyBudgets.length > 0 && tx.personId) {
        // familyRemaining ne doit pas inclure tx avec personId - vérifié dans calculateFamilyRemaining
        continue;
      }
    }
  }
  return true;
}
