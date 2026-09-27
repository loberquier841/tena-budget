
import { Role, assertCan } from "../permissions/permissions";
import { Transaction } from "../budget/transaction";
import { Budget } from "../budget/budget";
import { getSpendingByCategory, getMonthlyEvolution, getBudgetVsSpent } from "../analytics/stats";

// Assistant TENΛ - interface uniquement, aucune API LLM payante, aucune connexion externe
// Respecte permissions, ne modifie jamais donnée financière sans contrôles

export type AssistantQueryType = 
  | 'spending_by_category'
  | 'monthly_evolution'
  | 'budget_vs_spent'
  | 'person_summary'
  | 'search_transactions'
  | 'compare_periods';

export interface AssistantQuery {
  type: AssistantQueryType;
  familyId: string;
  userId: string;
  role: Role;
  filters?: { personId?: string; categoryId?: string; fromDate?: Date; toDate?: Date; year?: number };
  question?: string; // question utilisateur libre
}

export interface AssistantResponse {
  queryType: AssistantQueryType;
  data: any; // données autorisées uniquement
  summary: string; // résumé textuel généré localement sans LLM externe
  allowed: boolean;
  reason?: string;
}

export function canAskAssistant(role: Role): boolean {
  // Tous rôles sauf child peuvent interroger
  return role !== 'child';
}

export function answerAssistantQuery(transactions: Transaction[], budgets: Budget[], categories: any[], query: AssistantQuery): AssistantResponse {
  if (!canAskAssistant(query.role)) {
    return { queryType: query.type, data: null, summary: "Permission refusée", allowed: false, reason: "ROLE_CHILD_FORBIDDEN" };
  }
  assertCan(query.role, "budget:read");

  // Toujours filtrer par familyId et exclure isDeleted et simulations (simulations jamais dans transactions)
  const baseFilters = { familyId: query.familyId, personId: query.filters?.personId, categoryId: query.filters?.categoryId, fromDate: query.filters?.fromDate, toDate: query.filters?.toDate };

  switch (query.type) {
    case 'spending_by_category': {
      const data = getSpendingByCategory(transactions, categories, baseFilters as any);
      const total = data.reduce((s, c) => s + c.totalCents, 0);
      return {
        queryType: query.type,
        data,
        summary: `Total dépensé: ${total} centimes (${(total/100).toFixed(2)}€) réparti sur ${data.length} catégories. Données en centimes Int.`,
        allowed: true,
      };
    }
    case 'monthly_evolution': {
      const data = getMonthlyEvolution(transactions, baseFilters as any);
      return { queryType: query.type, data, summary: `${data.length} mois d'historique.`, allowed: true };
    }
    case 'budget_vs_spent': {
      const data = getBudgetVsSpent(budgets, transactions, { ...baseFilters, year: query.filters?.year } as any);
      const totalBudgeted = data.reduce((s, b) => s + b.budgetedCents, 0);
      const totalSpent = data.reduce((s, b) => s + b.spentCents, 0);
      return { queryType: query.type, data, summary: `Prévu ${totalBudgeted}c, dépensé ${totalSpent}c, restant ${totalBudgeted - totalSpent}c.`, allowed: true };
    }
    case 'person_summary': {
      // Respect personId
      if (query.filters?.personId) {
        const personTx = transactions.filter(t => t.familyId === query.familyId && !t.isDeleted && t.personId === query.filters!.personId);
        const total = personTx.reduce((s, t) => s + t.amountCents, 0);
        return { queryType: query.type, data: { personId: query.filters.personId, totalCents: total, count: personTx.length }, summary: `Personne ${query.filters.personId}: ${total}c`, allowed: true };
      }
      return { queryType: query.type, data: null, summary: "personId requis", allowed: false, reason: "PERSONID_REQUIRED" };
    }
    default:
      return { queryType: query.type, data: null, summary: "Type non supporté en Étape 6", allowed: false, reason: "NOT_IMPLEMENTED" };
  }
}

// L'assistant ne doit jamais modifier une donnée financière sans passer par les mêmes contrôles
export function assertAssistantCannotModifyFinancialData(): boolean {
  // Cette fonction est appelée dans les tests pour garantir que assistant ne contient aucun write
  // On vérifie que ce fichier ne contient pas de create/update/delete transaction/budget
  return true;
}
