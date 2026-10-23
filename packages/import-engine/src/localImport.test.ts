import { describe, expect, it } from 'vitest';
import { analyzeFiles, parseCsvText, parseEuroToCents, parseFrenchDate } from './parser';
import { prepareImportRows, suggestImportMapping } from './localImport';

describe('import CSV/XLSX local', () => {
  it('accepte un CSV valide et prépare la transaction', async () => {
    const csv = 'Date;Libellé;Montant;Catégorie\n12/03/2026;Courses;-24,50;Alimentation';
    const sheets = await analyzeFiles([{ id: 'f', name: 'bank.csv', mime: 'csv', size: csv.length, buffer: new TextEncoder().encode(csv).buffer }]);
    const mapping = suggestImportMapping(sheets[0].headers);
    const preview = prepareImportRows(sheets[0], mapping);
    expect(preview.rows).toHaveLength(1);
    expect(preview.rows[0]).toMatchObject({ label: 'Courses', amountCents: -2450, category: 'Alimentation', selected: true });
    expect(preview.rows[0].bookingDate?.toLocaleDateString('fr-FR')).toBe('12/03/2026');
  });

  it('refuse les CSV mal formés et les colonnes absentes', () => {
    expect(() => parseCsvText('date;label;amount\n01/02/2026;"broken;12')).toThrow('CSV_UNCLOSED_QUOTE');
    const sheet = { fileId: 'f', sheetName: 'CSV', headers: ['Date', 'Libellé'], rows: [], rawCells: [] };
    expect(() => prepareImportRows(sheet, { date: 'Date', label: 'Libellé', amount: 'Montant' })).toThrow('IMPORT_MAPPING_AMOUNT_REQUIRED');
  });

  it('valide les montants négatifs et rejette les formats ambigus', () => {
    expect(parseEuroToCents('-12,34')).toBe(-1234);
    expect(parseEuroToCents('12,345')).toBeNull();
  });

  it('rejette les dates calendrier impossibles sans faussement rejeter un fuseau ISO', () => {
    expect(parseFrenchDate('31/02/2026')).toBeNull();
    expect(parseFrenchDate('2026-02-31')).toBeNull();
    expect(parseFrenchDate('2026-03-12T00:00:00+01:00')).toBeInstanceOf(Date);
  });

  it('signale les doublons déjà présents et répétés dans le fichier', () => {
    const csv = 'Date,Libellé,Montant\n2026-03-12,Café,-2.50\n2026-03-12,Café,-2.50';
    const sheet = parseCsvText(csv);
    const analyzed = { fileId: 'f', sheetName: 'CSV', ...sheet };
    const result = prepareImportRows(analyzed, suggestImportMapping(sheet.headers), [{ bookingDate: new Date('2026-03-12T09:00:00'), amountCents: -250, label: '  café ' }]);
    expect(result.rows.map(row => row.duplicate)).toEqual(['existing', 'existing']);
    const withoutExisting = prepareImportRows(analyzed, suggestImportMapping(sheet.headers));
    expect(withoutExisting.rows.map(row => row.duplicate)).toEqual([undefined, 'file']);
    expect(withoutExisting.rows[1].selected).toBe(false);
  });

  it('analyse une feuille XLSX et laisse les formules non évaluées', async () => {
    const ExcelJS = await import('exceljs');
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Transactions');
    worksheet.addRow(['Date', 'Libellé', 'Montant']);
    worksheet.addRow([new Date('2026-03-12T00:00:00Z'), 'Loyer', { formula: '1+2' }]);
    const buffer = await workbook.xlsx.writeBuffer();
    const sheets = await analyzeFiles([{ id: 'x', name: 'bank.xlsx', mime: 'xlsx', size: buffer.byteLength, buffer: buffer as ArrayBuffer }]);
    expect(sheets[0].sheetName).toBe('Transactions');
    expect(typeof sheets[0].rows[0].Montant).toBe('object');
    const rows = prepareImportRows(sheets[0], { date: 'Date', label: 'Libellé', amount: 'Montant' });
    expect(rows.rows[0].error).toMatch(/Formule/);
  });
});
