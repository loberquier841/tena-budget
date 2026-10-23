import type { AnalyzedSheet } from './types';
import { parseEuroToCents, parseFrenchDate } from './parser';

export interface ImportColumnMapping { date: string; amount: string; label: string; category?: string; }
export interface ImportExistingTransaction { bookingDate: Date; amountCents: number; label: string; }
export interface PreparedImportRow {
  sourceRow: number; label: string; bookingDate?: Date; amountCents?: number; category?: string;
  error?: string; duplicate?: 'existing' | 'file'; selected: boolean;
}

const normalized = (value: string) => value.trim().toLocaleLowerCase().replace(/[ _-]+/g, ' ');

export function suggestImportMapping(headers: string[]): ImportColumnMapping {
  const find = (patterns: RegExp[]) => headers.find(header => patterns.some(pattern => pattern.test(normalized(header)))) ?? '';
  return {
    date: find([/^(date|booking date|date opération|date operation|date valeur)$/]),
    amount: find([/^(montant|amount|somme|value|debit|crédit|credit)$/]),
    label: find([/^(libellé|libelle|label|description|transaction|intitulé|intitule)$/]),
    category: find([/^(catégorie|categorie|category)$/]) || undefined,
  };
}

export function validateImportMapping(headers: string[], mapping: ImportColumnMapping): string | undefined {
  for (const key of ['date', 'amount', 'label'] as const) {
    if (!mapping[key] || !headers.includes(mapping[key])) return `IMPORT_MAPPING_${key.toUpperCase()}_REQUIRED`;
  }
  const selected = [mapping.date, mapping.amount, mapping.label, mapping.category].filter(Boolean);
  if (new Set(selected).size !== selected.length || (mapping.category && !headers.includes(mapping.category))) return 'IMPORT_MAPPING_INVALID';
  return undefined;
}

function dateValue(value: unknown): Date | null {
  if (typeof value === 'number' && Number.isFinite(value) && value >= 1 && value <= 2_958_465) {
    return new Date(Date.UTC(1899, 11, 30) + value * 86_400_000);
  }
  return parseFrenchDate(value);
}

function duplicateKey(row: ImportExistingTransaction): string {
  const date = row.bookingDate.toISOString().slice(0, 10);
  return `${date}|${row.amountCents}|${normalized(row.label).replace(/\s+/g, ' ')}`;
}

export function prepareImportRows(sheet: AnalyzedSheet, mapping: ImportColumnMapping, existing: ImportExistingTransaction[] = []) {
  const mappingError = validateImportMapping(sheet.headers, mapping);
  if (mappingError) throw new Error(mappingError);
  const known = new Set(existing.filter(item => item.bookingDate instanceof Date && Number.isFinite(item.bookingDate.getTime())).map(duplicateKey));
  const seen = new Set<string>();
  let blankCount = 0;
  const rows: PreparedImportRow[] = [];
  sheet.rows.forEach((row, index) => {
    if (Object.values(row).every(value => value == null || String(value).trim() === '')) { blankCount++; return; }
    const labelValue = row[mapping.label];
    const label = typeof labelValue === 'string' || typeof labelValue === 'number' ? String(labelValue).trim() : '';
    const rawAmount = row[mapping.amount];
    const amountCents = parseEuroToCents(rawAmount);
    const bookingDate = dateValue(row[mapping.date]);
    let error: string | undefined;
    if (rawAmount && typeof rawAmount === 'object') error = 'Formule ou montant non pris en charge';
    else if (!bookingDate) error = 'Date invalide';
    else if (amountCents === null || amountCents === 0) error = 'Montant invalide ou nul';
    else if (!label) error = 'Libellé obligatoire';
    const imported = { bookingDate: bookingDate ?? new Date(0), amountCents: amountCents ?? 0, label };
    const key = duplicateKey(imported);
    const duplicate = !error && known.has(key) ? 'existing' : (!error && seen.has(key) ? 'file' : undefined);
    if (!error) seen.add(key);
    const categoryValue = mapping.category ? row[mapping.category] : undefined;
    rows.push({ sourceRow: index + 2, label, bookingDate: bookingDate ?? undefined, amountCents: amountCents ?? undefined,
      category: categoryValue == null ? undefined : String(categoryValue).trim() || undefined,
      error, duplicate, selected: !error && !duplicate });
  });
  return { rows, blankCount };
}
