
export type Layer = 'file_original' | 'data_analyzed' | 'data_recognized' | 'data_ambiguous' | 'data_validated' | 'data_final';

export interface OriginalFile {
  id: string;
  name: string;
  mime: 'xlsx' | 'csv' | 'unknown';
  size: number;
  buffer: ArrayBuffer; // jamais muté - read-only ref
  sheets?: string[]; // pour XLSX
}

export interface AnalyzedSheet {
  fileId: string;
  sheetName: string;
  headers: string[];
  rows: Record<string, any>[];
  rawCells: any[][];
}

export interface RecognizedColumn {
  originalHeader: string;
  mappedTo: 'category' | 'budget' | 'spent' | 'remaining' | 'person' | 'date' | 'amount' | 'label' | 'goal' | 'unknown';
  confidence: number; // 0-100
  sampleValues: any[];
}

export interface RecognizedData {
  columns: RecognizedColumn[];
  categories: { name: string; sourceRow: number }[];
  budgets: { category: string; amountCents: number; year?: number; type?: 'annual'|'monthly' }[];
  transactions: { label: string; amountCents: number; bookingDate: Date; category?: string; person?: string; hashDedup: string; sourceRow: number }[];
  persons: string[];
  goals: { name: string; targetCents?: number }[];
  years: number[];
  formulas: { raw: string; converted: string; isSafe: boolean; row: number; col: string }[];
  isPartial: boolean;
  partialWarnings: string[];
}

export interface AmbiguousColumn {
  column: string;
  guesses: { mappedTo: RecognizedColumn['mappedTo']; confidence: number }[];
  sampleValues: any[];
  status: 'pending' | 'corrected' | 'ignored';
}

export interface DuplicateGroup {
  id: string;
  type: 'exact' | 'likely';
  transactions: RecognizedData['transactions'];
  existingTransactionIds?: string[]; // pour réimport
  decision?: 'keep_both' | 'keep_first' | 'keep_second' | 'compare';
}

export interface ComparisonItem {
  incoming: RecognizedData['transactions'][0];
  existing?: { id: string; label: string; amountCents: number; bookingDate: Date };
  diff: string[];
}

export interface PreviewData {
  budgetsToCreate: RecognizedData['budgets'];
  categoriesToCreate: string[];
  transactionsToCreate: RecognizedData['transactions'];
  personsToCreate: string[];
  yearsSelected: number[];
}

export interface ImportReport {
  imported: { budgets: number; categories: number; transactions: number; persons: number; goals: number };
  ignored: { count: number; items: { reason: string; row: number }[] };
  modified: { count: number; items: { original: string; corrected: string }[] };
  ambiguous: { count: number; columns: string[] };
  duplicates: { count: number; groups: DuplicateGroup[] };
  errors: { count: number; items: { row: number; error: string }[] };
  attention: { count: number; items: string[] };
  isPartial: boolean;
  yearsImported: number[];
}

export interface MigrationState {
  step: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11;
  files_original: OriginalFile[]; // jamais muté
  data_analyzed: AnalyzedSheet[] | null;
  data_recognized: RecognizedData | null;
  data_ambiguous: AmbiguousColumn[] | null;
  data_validated: PreviewData | null;
  data_final: ImportReport | null;
  // Pour réexécution réelle après correction mapping
  columnMappings: Record<string, RecognizedColumn['mappedTo']>;
  yearsSelected: number[];
  duplicateDecisions: Record<string, DuplicateGroup['decision']>;
  validated: boolean; // validation finale obligatoire
}

export const INITIAL_STATE: MigrationState = {
  step: 1,
  files_original: [],
  data_analyzed: null,
  data_recognized: null,
  data_ambiguous: null,
  data_validated: null,
  data_final: null,
  columnMappings: {},
  yearsSelected: [],
  duplicateDecisions: {},
  validated: false,
};
