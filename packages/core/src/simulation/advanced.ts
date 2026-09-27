
import { SimulationScenario, SimulationTransaction } from "../budget/simulation";
import { Transaction } from "../budget/transaction";
import { Budget } from "../budget/budget";
import { Role, assertCan } from "../permissions/permissions";

// Simulations what-if réellement séparées - aucun impact sur données réelles

export interface SimulationImpact {
  scenarioId: string;
  scenarioName: string;
  realTotalCents: number; // Int
  simulatedTotalCents: number; // Int
  combinedTotalCents: number; // réel + simulation Int
  diffCents: number; // simulation - 0 (impact) Int
  budgetImpact: { budgetId: string; budgetedCents: number; realSpentCents: number; simulatedSpentCents: number; remainingRealCents: number; remainingWithSimCents: number }[];
}

export function createWhatIfScenario(familyId: string, name: string, role: Role): SimulationScenario {
  assertCan(role, "budget:read"); // lecture suffit pour simulation
  if (!name.trim()) throw new Error("SCENARIO_NAME_REQUIRED");
  return { id: `sim_${Date.now()}_${Math.random().toString(36).slice(2,6)}`, familyId, name: name.trim(), createdAt: new Date() };
}

export function addWhatIfTransaction(scenario: SimulationScenario, input: { label: string; amountCents: number; bookingDate: Date; categoryId?: string }, role: Role): SimulationTransaction {
  assertCan(role, "budget:read");
  if (!Number.isInteger(input.amountCents)) throw new Error("SIM_AMOUNT_INT_ONLY");
  if (input.amountCents === 0) throw new Error("SIM_ZERO_FORBIDDEN");
  if (!input.label.trim()) throw new Error("SIM_LABEL_REQUIRED");
  // Aucune création de Transaction réelle - uniquement SimulationTransaction
  return {
    id: `simtx_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    scenarioId: scenario.id,
    amountCents: input.amountCents,
    label: input.label.trim(),
    bookingDate: input.bookingDate,
    categoryId: input.categoryId,
  };
}

export function calculateImpact(scenario: SimulationScenario, simTransactions: SimulationTransaction[], realTransactions: Transaction[], budgets: Budget[], filters: { familyId: string; personId?: string }): SimulationImpact {
  // Toujours exclure isDeleted et respecter familyId/personId
  const realValid = realTransactions.filter(t => t.familyId === filters.familyId && !t.isDeleted && (!filters.personId || t.personId === filters.personId));
  const simValid = simTransactions.filter(st => st.scenarioId === scenario.id);

  const realTotalCents = realValid.reduce((s, t) => s + t.amountCents, 0);
  const simulatedTotalCents = simValid.reduce((s, st) => s + st.amountCents, 0);
  const combinedTotalCents = realTotalCents + simulatedTotalCents;
  const diffCents = simulatedTotalCents; // impact

  const budgetImpact = budgets.filter(b => b.familyId === filters.familyId && (!filters.personId || b.personId === filters.personId)).map(b => {
    const realSpent = realValid.filter(t => t.categoryId === b.categoryId || t.budgetId === b.id).reduce((s, t) => s + t.amountCents, 0);
    const simSpent = simValid.filter(st => st.categoryId === b.categoryId).reduce((s, st) => s + st.amountCents, 0);
    return {
      budgetId: b.id,
      budgetedCents: b.amountCents,
      realSpentCents: realSpent,
      simulatedSpentCents: simSpent,
      remainingRealCents: b.amountCents - realSpent,
      remainingWithSimCents: b.amountCents - realSpent - simSpent,
    };
  });

  // Vérif Int
  if (!Number.isInteger(realTotalCents) || !Number.isInteger(simulatedTotalCents)) throw new Error("IMPACT_INT_ONLY");

  return {
    scenarioId: scenario.id,
    scenarioName: scenario.name,
    realTotalCents,
    simulatedTotalCents,
    combinedTotalCents,
    diffCents,
    budgetImpact,
  };
}

export function compareRealVsSimulation(impact: SimulationImpact): { realCents: number; simulatedCents: number; combinedCents: number; diffCents: number; diffPercentInt: number } {
  const diffPercentInt = impact.realTotalCents !== 0 ? Math.floor((impact.simulatedTotalCents * 100) / impact.realTotalCents) : 0;
  return {
    realCents: impact.realTotalCents,
    simulatedCents: impact.simulatedTotalCents,
    combinedCents: impact.combinedTotalCents,
    diffCents: impact.diffCents,
    diffPercentInt,
  };
}

export function assertNoRealTransactionModified(realTxBefore: Transaction[], realTxAfter: Transaction[], simTransactions: SimulationTransaction[]): boolean {
  // Vérifie qu'aucune Transaction réelle n'a été créée/modifiée par simulation
  if (realTxBefore.length !== realTxAfter.length) return false;
  const beforeIds = new Set(realTxBefore.map(t => t.id));
  const afterIds = new Set(realTxAfter.map(t => t.id));
  if (beforeIds.size !== afterIds.size) return false;
  for (const id of beforeIds) if (!afterIds.has(id)) return false;
  // SimTransactions ont namespace simtx_, jamais tx_
  if (simTransactions.some(st => !st.id.startsWith("simtx_"))) return false;
  return true;
}
