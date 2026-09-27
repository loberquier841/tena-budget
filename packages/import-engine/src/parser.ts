
import { OriginalFile, AnalyzedSheet } from "./types";

// Parser sécurisé - aucun eval/Function
// Support XLSX multi-feuilles et CSV, dates FR, montants EUR

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

// Analyse XLSX multi-feuilles - interface, implémentation réelle utilise SheetJS en worker
export async function analyzeFiles(files: OriginalFile[]): Promise<AnalyzedSheet[]> {
  // Cette fonction est appelée dans un Web Worker avec SheetJS
  // Ici version mock pour tests - en prod: XLSX.read + sheet_to_json
  const result: AnalyzedSheet[] = [];
  for (const file of files) {
    if (file.mime === 'csv') {
      // CSV: parse via PapaParse en prod
      result.push({
        fileId: file.id,
        sheetName: 'CSV',
        headers: ['Category', 'Budget', 'Spent', 'Date'], // mock
        rows: [],
        rawCells: [],
      });
    } else if (file.mime === 'xlsx') {
      // Multi-feuilles: file.sheets contient noms
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
