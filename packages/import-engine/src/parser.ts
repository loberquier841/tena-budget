
import { OriginalFile, AnalyzedSheet } from "./types";

// Parser sécurisé - aucun eval/Function
// Support XLSX multi-feuilles et CSV, dates FR, montants EUR

// ---------- CSV natif (aucune dépendance externe) ----------

const BOM = '\uFEFF';

/**
 * Détermine le séparateur de CSV le plus probable parmi , ; \t.
 * Préfère le séparateur qui donne un nombre de colonnes constant > 1 sur les premières lignes.
 */
function detectCsvSeparator(text: string): ',' | ';' | '\t' {
  const counts: Record<',' | ';' | '\t', number> = { ',': 0, ';': 0, '\t': 0 };
  let quoted = false;
  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    if (char === '"') {
      if (quoted && text[index + 1] === '"') index++;
      else quoted = !quoted;
    } else if (!quoted && (char === '\n' || char === '\r')) break;
    else if (!quoted && char in counts) counts[char as ',' | ';' | '\t']++;
  }
  return (Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0] as ',' | ';' | '\t') || ',';
}

function parseCsvRecords(text: string, separator: ',' | ';' | '\t'): string[][] {
  const records: string[][] = [];
  let record: string[] = [];
  let field = '';
  let quoted = false;
  let closedQuote = false;
  const pushField = () => { record.push(field); field = ''; closedQuote = false; };
  const pushRecord = () => {
    pushField();
    if (record.some(value => value.trim() !== '')) records.push(record);
    record = [];
  };

  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    if (quoted) {
      if (char === '"' && text[index + 1] === '"') { field += '"'; index++; }
      else if (char === '"') { quoted = false; closedQuote = true; }
      else field += char;
      continue;
    }
    if (closedQuote && char !== separator && char !== '\r' && char !== '\n' && !/\s/.test(char)) {
      throw new Error('CSV_INVALID_QUOTE');
    }
    if (char === '"') {
      if (field.length !== 0) throw new Error('CSV_INVALID_QUOTE');
      quoted = true;
    } else if (char === separator) pushField();
    else if (char === '\n' || char === '\r') {
      if (char === '\r' && text[index + 1] === '\n') index++;
      pushRecord();
    } else if (!closedQuote) field += char;
  }
  if (quoted) throw new Error('CSV_UNCLOSED_QUOTE');
  if (record.length || field.length || closedQuote) pushRecord();
  return records;
}

/**
 * Parse un texte CSV en { headers, rows }.
 * rows: tableau d'objets keyé par les headers.
 */
export function parseCsvText(text: string): { headers: string[]; rows: Record<string, any>[]; rawCells: any[][] } {
  const cleaned = text.replace(BOM, '');
  const records = parseCsvRecords(cleaned, detectCsvSeparator(cleaned));
  if (records.length === 0) return { headers: [], rows: [], rawCells: [] };

  const originalHeaders = records[0].map(header => header.trim());
  const retained = originalHeaders.map((header, index) => ({ header, index })).filter(item => item.header !== '');
  const headers = retained.map(item => item.header);
  if (headers.length === 0) throw new Error('CSV_HEADERS_REQUIRED');
  const normalized = headers.map(header => header.toLocaleLowerCase());
  if (new Set(normalized).size !== normalized.length) throw new Error('CSV_DUPLICATE_HEADERS');

  const rows: Record<string, any>[] = [];
  const rawCells: any[][] = [headers];
  for (const record of records.slice(1)) {
    if (record.length > originalHeaders.length && record.slice(originalHeaders.length).some(value => value.trim())) {
      throw new Error('CSV_COLUMN_COUNT_MISMATCH');
    }
    const row: Record<string, any> = {};
    for (const { header, index } of retained) row[header] = record[index] ?? '';
    rows.push(row);
    rawCells.push(retained.map(({ index }) => record[index] ?? ''));
  }
  return { headers, rows, rawCells };
}

/**
 * Lit le buffer ArrayBuffer d'un fichier et retourne le texte (UTF-8).
 * Ne mutera jamais le buffer source.
 */
export function bufferToText(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  try { return new TextDecoder('utf-8', { fatal: true }).decode(bytes); }
  catch { return new TextDecoder('windows-1252').decode(bytes); }
}

/**
 * Analyse réels les fichiers : CSV parsé ici-même, XLSX laisse la structure
 * prête pour SheetJS (à activer quand la dépendance sera installée).
 */
export async function analyzeFiles(files: OriginalFile[]): Promise<AnalyzedSheet[]> {
  const result: AnalyzedSheet[] = [];
  for (const file of files) {
    if (file.mime === 'csv') {
      const text = bufferToText(file.buffer);
      const { headers, rows, rawCells } = parseCsvText(text);
      result.push({
        fileId: file.id,
        sheetName: 'CSV',
        headers,
        rows,
        rawCells,
      });
    } else if (file.mime === 'xlsx') {
      const ExcelJS = await import('exceljs');
      const workbook = new ExcelJS.Workbook();
      await workbook.xlsx.load(file.buffer);
      if (workbook.worksheets.length === 0) throw new Error('XLSX_NO_SHEETS');
      for (const worksheet of workbook.worksheets) {
        if (worksheet.rowCount > 10001 || worksheet.columnCount > 100) throw new Error('IMPORT_SHEET_TOO_LARGE');
        const headers = Array.from({ length: worksheet.columnCount }, (_, index) => String(worksheet.getRow(1).getCell(index + 1).value ?? '').trim());
        const rows: Record<string, any>[] = [];
        const rawCells: any[][] = [headers];
        for (let rowNumber = 2; rowNumber <= worksheet.rowCount; rowNumber++) {
          const excelRow = worksheet.getRow(rowNumber);
          const values = headers.map((_, columnIndex) => {
            const value = excelRow.getCell(columnIndex + 1).value;
            if (value && typeof value === 'object' && 'richText' in value) return value.richText.map((part: any) => part.text).join('');
            if (value && typeof value === 'object' && ('formula' in value || 'sharedFormula' in value)) return value;
            if (value && typeof value === 'object' && 'text' in value && 'hyperlink' in value) return value.text;
            return value ?? '';
          });
          if (values.every(value => value === '' || value == null)) continue;
          const row: Record<string, any> = {};
          headers.forEach((header, index) => { if (header) row[header] = values[index]; });
          rows.push(row);
          rawCells.push(values);
        }
        if (headers.filter(Boolean).length === 0) throw new Error('XLSX_HEADERS_REQUIRED');
        const normalizedHeaders = headers.filter(Boolean).map(header => header.toLocaleLowerCase());
        if (new Set(normalizedHeaders).size !== normalizedHeaders.length) throw new Error('XLSX_DUPLICATE_HEADERS');
        result.push({ fileId: file.id, sheetName: worksheet.name, headers: headers.filter(Boolean), rows, rawCells });
      }
    } else {
      throw new Error('IMPORT_FILE_UNSUPPORTED');
    }
  }
  return result;
}

const FORBIDDEN_FORMULA_KEYWORDS = ['eval', 'Function', 'import', 'require', 'process', 'window', 'document', 'fetch', 'XMLHttpRequest'];

export function isFormulaSafe(raw: string): { safe: boolean; reason?: string } {
  if (FORBIDDEN_FORMULA_KEYWORDS.some(k => raw.includes(k))) return { safe: false, reason: 'forbidden keyword' };
  // Whitelist: chiffres, lettres, + - * / ( ) , . _ € % et noms SOMME MOYENNE etc
  const allowed = /^[=\d\s+\-*/().,A-Za-z_éèêàâôûÉÈ€%]+$/;
  const withoutEqual = raw.startsWith('=') ? raw.slice(1) : raw;
  if (!allowed.test(withoutEqual)) return { safe: false, reason: 'invalid chars' };
  return { safe: true };
}

export function convertFormulaSafe(raw: string): string | null {
  const check = isFormulaSafe(raw);
  if (!check.safe) return null;
  let converted = raw.replace(/^=/, '');
  // Conversion exemple =Budget-Dépensé -> budget - spent
  converted = converted
    .replace(/Budget/gi, 'budget')
    .replace(/Dépensé|Depense/gi, 'spent')
    .replace(/Restant|Reste/gi, 'remaining')
    .replace(/SOMME/gi, 'SUM')
    .replace(/MOYENNE/gi, 'AVERAGE');
  converted = converted.replace(/\s*([+\-*/])\s*/g, ' $1 ');
  return converted.trim();
}

// Montants EUR: "4 000 €", "4000€", "4.000,50 €", "4000,50", "€ 4000"
export function parseEuroToCents(input: any): number | null {
  if (input === null || input === undefined || input === '') return null;
  if (typeof input === 'number') {
    if (!Number.isFinite(input)) return null;
    const cents = Math.round(input * 100);
    return Number.isSafeInteger(cents) ? cents : null;
  }
  let value = String(input).trim().replace(/[€\s\u00a0\u202f]/g, '').replace(/[−–]/g, '-');
  if (!value) return null;
  let sign = 1;
  if (value.startsWith('(') && value.endsWith(')')) { sign = -1; value = value.slice(1, -1); }
  if (value.startsWith('-') || value.startsWith('+')) { if (value[0] === '-') sign *= -1; value = value.slice(1); }
  if (!value || /[+-]/.test(value)) return null;

  const commaCount = (value.match(/,/g) ?? []).length;
  const dotCount = (value.match(/\./g) ?? []).length;
  let decimalSeparator = '';
  let groupingSeparator = '';
  if (commaCount && dotCount) {
    decimalSeparator = value.lastIndexOf(',') > value.lastIndexOf('.') ? ',' : '.';
    groupingSeparator = decimalSeparator === ',' ? '.' : ',';
    if ((decimalSeparator === ',' ? commaCount : dotCount) !== 1) return null;
  } else if (commaCount === 1) decimalSeparator = ',';
  else if (dotCount === 1) {
    const after = value.length - value.lastIndexOf('.') - 1;
    if (after === 3 && /^\d{1,3}(?:\.\d{3})+$/.test(value)) groupingSeparator = '.';
    else decimalSeparator = '.';
  } else if (dotCount > 1) groupingSeparator = '.';

  const parts = decimalSeparator ? value.split(decimalSeparator) : [value];
  if (parts.length > 2 || (parts[1] !== undefined && !/^\d{1,2}$/.test(parts[1]))) return null;
  let whole = parts[0];
  if (groupingSeparator) {
    const grouped = whole.split(groupingSeparator);
    if (!/^\d{1,3}$/.test(grouped[0]) || grouped.slice(1).some(group => !/^\d{3}$/.test(group))) return null;
    whole = grouped.join('');
  }
  if (!/^\d+$/.test(whole)) return null;
  const wholeNumber = Number(whole);
  const fraction = (parts[1] ?? '').padEnd(2, '0');
  const cents = wholeNumber * 100 + Number(fraction || 0);
  return Number.isSafeInteger(cents) ? sign * cents : null;
}

// Dates FR: "15/01/2026", "15-01-2026", "15.01.2026", "2026-01-15", Date object
export function parseFrenchDate(input: any): Date | null {
  if (!input) return null;
  if (input instanceof Date && !isNaN(input.getTime())) return input;
  const s = String(input).trim();
  // ISO (vérifie les composantes pour refuser les dates rollover comme le 31 février).
  const isoMatch = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:T.*)?$/);
  if (isoMatch) {
    const year = Number(isoMatch[1]); const month = Number(isoMatch[2]); const day = Number(isoMatch[3]);
    const calendarDate = new Date(Date.UTC(year, month - 1, day));
    const iso = new Date(s);
    if (Number.isFinite(iso.getTime()) && calendarDate.getUTCFullYear() === year && calendarDate.getUTCMonth() + 1 === month && calendarDate.getUTCDate() === day) return iso;
    return null;
  }

  // FR JJ/MM/AAAA ou JJ-MM-AAAA ou JJ.MM.AAAA
  const frMatch = s.match(/^(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})$/);
  if (frMatch) {
    let d = parseInt(frMatch[1], 10);
    let m = parseInt(frMatch[2], 10) - 1;
    let y = parseInt(frMatch[3], 10);
    if (y < 100) y += 2000;
    const dt = new Date(y, m, d);
    if (!isNaN(dt.getTime()) && dt.getFullYear() === y && dt.getMonth() === m && dt.getDate() === d) return dt;
  }
  return null;
}

export function hashDedup(bookingDate: Date, amountCents: number, label: string): string {
  const norm = `${bookingDate.toISOString().slice(0,10)}|${amountCents}|${label.toLowerCase().trim().replace(/\s+/g,' ')}`;
  let h = 0;
  for (let i=0;i<norm.length;i++) h = (h*31 + norm.charCodeAt(i)) >>> 0;
  return h.toString(16);
}


