
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
  const candidates: Array<',' | ';' | '\t'> = [',', ';', '\t'];
  const lines = text.split(/\r?\n/).filter(l => l.length > 0).slice(0, 10);
  if (lines.length === 0) return ',';

  let best: ',' | ';' | '\t' = ',';
  let bestScore = -1;
  for (const sep of candidates) {
    const counts = lines.map(l => (l.match(new RegExp('\\' + (sep === '\t' ? '\\t' : sep), 'g')) || []).length);
    const uniqueCounts = new Set(counts);
    const constant = uniqueCounts.size === 1 ? 2 : 1;
    const avgCols = counts.reduce((a, b) => a + b, 0) / counts.length;
    const score = constant * 10 + (avgCols > 1 ? avgCols : 0);
    if (score > bestScore) {
      bestScore = score;
      best = sep;
    }
  }
  return best;
}

/**
 * Découpe une ligne CSV en champs en gérant les guillemets doubles (escape "" -> ").
 */
function parseCsvLine(line: string, sep: ',' | ';' | '\t'): string[] {
  const fields: string[] = [];
  let i = 0;
  const sepChar = sep === '\t' ? '\t' : sep;
  while (i < line.length) {
    if (line[i] === '"') {
      i++; // skip opening quote
      let field = '';
      while (i < line.length) {
        if (line[i] === '"') {
          if (i + 1 < line.length && line[i + 1] === '"') {
            field += '"';
            i += 2;
          } else {
            i++; // skip closing quote
            break;
          }
        } else {
          field += line[i];
          i++;
        }
      }
      while (i < line.length && line[i] !== sepChar) i++;
      if (i < line.length) i++; // skip sep
      fields.push(field);
    } else {
      const end = line.indexOf(sepChar, i);
      if (end === -1) {
        fields.push(line.slice(i));
        i = line.length;
      } else {
        fields.push(line.slice(i, end));
        i = end + 1;
      }
    }
  }
  return fields;
}

/**
 * Parse un texte CSV en { headers, rows }.
 * rows: tableau d'objets keyé par les headers.
 */
export function parseCsvText(text: string): { headers: string[]; rows: Record<string, any>[]; rawCells: any[][] } {
  let cleaned = text.replace(BOM, '');
  cleaned = cleaned.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = cleaned.split('\n');
  while (lines.length > 0 && lines[lines.length - 1].trim() === '') lines.pop();
  if (lines.length === 0) return { headers: [], rows: [], rawCells: [] };

  const sep = detectCsvSeparator(cleaned);
  const rawCells: any[][] = [];
  const headers: string[] = [];
  const rows: Record<string, any>[] = [];

  const headerFields = parseCsvLine(lines[0], sep);
  for (const h of headerFields) headers.push(h.trim());
  rawCells.push(headerFields);

  for (let li = 1; li < lines.length; li++) {
    const fields = parseCsvLine(lines[li], sep);
    rawCells.push(fields);
    const row: Record<string, any> = {};
    for (let ci = 0; ci < headers.length; ci++) {
      row[headers[ci]] = ci < fields.length ? fields[ci] : '';
    }
    rows.push(row);
  }

  return { headers, rows, rawCells };
}

/**
 * Lit le buffer ArrayBuffer d'un fichier et retourne le texte (UTF-8).
 * Ne mutera jamais le buffer source.
 */
export function bufferToText(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  const decoder = new TextDecoder('utf-8');
  return decoder.decode(bytes);
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
      const sheets = file.sheets && file.sheets.length ? file.sheets : ['Sheet1'];
      for (const sheetName of sheets) {
        result.push({
          fileId: file.id,
          sheetName,
          headers: [],
          rows: [],
          rawCells: [],
        });
      }
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
    return Math.round(input * 100);
  }
  let s = String(input).trim();
  s = s.replace(/€/g, '').replace(/\s+/g, '').trim();
  // Gère "4.000,50" -> "4000.50" et "4000,50" -> "4000.50"
  if (s.includes(',') && s.includes('.')) {
    // Suppose . = séparateur milliers
    s = s.replace(/\./g, '').replace(',', '.');
  } else if (s.includes(',')) {
    s = s.replace(',', '.');
  }
  s = s.replace(/[^\d.-]/g, '');
  const num = parseFloat(s);
  if (isNaN(num)) return null;
  return Math.round(num * 100);
}

// Dates FR: "15/01/2026", "15-01-2026", "15.01.2026", "2026-01-15", Date object
export function parseFrenchDate(input: any): Date | null {
  if (!input) return null;
  if (input instanceof Date && !isNaN(input.getTime())) return input;
  const s = String(input).trim();
  // ISO
  const iso = new Date(s);
  if (!isNaN(iso.getTime()) && /^\d{4}-\d{2}-\d{2}/.test(s)) return iso;

  // FR JJ/MM/AAAA ou JJ-MM-AAAA ou JJ.MM.AAAA
  const frMatch = s.match(/^(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})$/);
  if (frMatch) {
    let d = parseInt(frMatch[1], 10);
    let m = parseInt(frMatch[2], 10) - 1;
    let y = parseInt(frMatch[3], 10);
    if (y < 100) y += 2000;
    const dt = new Date(y, m, d);
    if (!isNaN(dt.getTime())) return dt;
  }
  return null;
}

export function hashDedup(bookingDate: Date, amountCents: number, label: string): string {
  const norm = `${bookingDate.toISOString().slice(0,10)}|${amountCents}|${label.toLowerCase().trim().replace(/\s+/g,' ')}`;
  let h = 0;
  for (let i=0;i<norm.length;i++) h = (h*31 + norm.charCodeAt(i)) >>> 0;
  return h.toString(16);
}


