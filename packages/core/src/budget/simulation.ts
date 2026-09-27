
// Simulations totalement séparées des transactions réelles
export interface SimulationScenario {
  id: string;
  familyId: string;
  name: string;
  createdAt: Date;
}

export interface SimulationTransaction {
  id: string;
  scenarioId: string;
  amountCents: number;
  label: string;
  bookingDate: Date;
  categoryId?: string;
}

export function createSimulationScenario(familyId: string, name: string): SimulationScenario {
  return { id: `sim_${Date.now()}`, familyId, name, createdAt: new Date() };
}

export function createSimulationTransaction(scenarioId: string, input: { amountCents: number; label: string; bookingDate: Date; categoryId?: string }): SimulationTransaction {
  if (!Number.isInteger(input.amountCents)) throw new Error("SIM_AMOUNT_INT_ONLY");
  return { id: `simtx_${Date.now()}`, scenarioId, amountCents: input.amountCents, label: input.label, bookingDate: input.bookingDate, categoryId: input.categoryId };
}

// Vérifie isolation: aucune simulation ne touche Transaction réelle
export function assertSimulationIsolation(realTxIds: string[], simTxs: SimulationTransaction[]): boolean {
  // Les IDs simulations commencent par simtx_, jamais tx_ - isolation par namespace + table séparée
  return simTxs.every(st => !realTxIds.includes(st.id) && st.id.startsWith("simtx_"));
}
