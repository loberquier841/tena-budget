
export * from "./types";
export * from "./parser";
export * from "./localImport";
export * from "./detector";
export * from "./pipeline";
export * from "./duplicate";
export * from "./report";
export * from "./reimport";

// Réexport pour compatibilité Étape 3
export type Layer = 'file_original' | 'data_analyzed' | 'data_recognized' | 'data_ambiguous' | 'data_validated' | 'data_final';

export interface MigrationStateLegacy {
  file_original: File | null;
  data_analyzed: any;
  data_recognized: any;
  data_ambiguous: any;
  data_validated: any;
  data_final: any;
}

export const INITIAL_STATE_LEGACY = {
  file_original: null,
  data_analyzed: null,
  data_recognized: null,
  data_ambiguous: null,
  data_validated: null,
  data_final: null,
};

export function safeParseFormula(raw: string) {
  const { isFormulaSafe, convertFormulaSafe } = require("./parser");
  const safe = isFormulaSafe(raw);
  return { isSafe: safe.safe, converted: safe.safe ? convertFormulaSafe(raw) : null, reason: safe.reason };
}

export function hashDedup(date: string, amountCents: number, label: string) {
  const { hashDedup: h } = require("./parser");
  return h(new Date(date), amountCents, label);
}
