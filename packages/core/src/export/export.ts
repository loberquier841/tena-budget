
import { Transaction } from "../budget/transaction";
import { Budget } from "../budget/budget";
import { Category } from "../budget/category";
import { Role, assertCan } from "../permissions/permissions";

// Exports Excel/CSV/PDF - valeurs internes centimes, conversion euros affichage/export seulement

export interface ExportFilters {
  familyId: string;
  personId?: string;
  categoryId?: string;
  fromDate?: Date;
  toDate?: Date;
  includeDeleted?: boolean;
}

function filterForExport(transactions: Transaction[], filters: ExportFilters): Transaction[] {
  return transactions.filter(t => {
    if (t.familyId !== filters.familyId) return false;
    if (!filters.includeDeleted && t.isDeleted) return false;
    if (filters.personId && t.personId !== filters.personId) return false;
    if (filters.categoryId && t.categoryId !== filters.categoryId) return false;
    if (filters.fromDate && t.bookingDate < filters.fromDate) return false;
    if (filters.toDate && t.bookingDate > filters.toDate) return false;
    return true;
  });
}

function centsToEurosForExport(cents: number): number {
  // Conversion affichage/export seulement, pas pour calcul interne
  return cents / 100;
}

export interface ExcelExportData {
  fileName: string;
  sheets: { name: string; headers: string[]; rows: (string | number)[][]; totalsCents: number }[];
  totalCents: number;
}

export function prepareExcelExport(transactions: Transaction[], budgets: Budget[], categories: Category[], filters: ExportFilters, role: Role): ExcelExportData {
  assertCan(role, "budget:read");
  const validTx = filterForExport(transactions, filters);
  const totalCents = validTx.reduce((s, t) => s + t.amountCents, 0);

  const txRows = validTx.map(t => [
    t.bookingDate.toISOString().slice(0,10),
    t.label,
    categories.find(c => c.id === t.categoryId)?.name || '',
    t.personId || '',
    centsToEurosForExport(t.amountCents), // euros pour affichage Excel
    t.source,
  ]);

  const budgetRows = budgets.filter(b => b.familyId === filters.familyId).map(b => [
    b.year,
    b.month || '',
    categories.find(c => c.id === b.categoryId)?.name || '',
    b.personId || '',
    centsToEurosForExport(b.amountCents),
    b.type,
  ]);

  return {
    fileName: `TENLA_Budget_${filters.familyId}_${new Date().toISOString().slice(0,10)}.xlsx`,
    sheets: [
      { name: "Transactions", headers: ["Date", "Libellé", "Catégorie", "Personne", "Montant €", "Source"], rows: txRows, totalsCents: totalCents },
      { name: "Budgets", headers: ["Année", "Mois", "Catégorie", "Personne", "Montant €", "Type"], rows: budgetRows, totalsCents: budgets.reduce((s,b) => s + b.amountCents, 0) },
    ],
    totalCents,
  };
}

export interface CsvExportData {
  fileName: string;
  content: string; // CSV string
  totalCents: number;
}

export function prepareCsvExport(transactions: Transaction[], filters: ExportFilters, role: Role): CsvExportData {
  assertCan(role, "budget:read");
  const validTx = filterForExport(transactions, filters);
  const totalCents = validTx.reduce((s, t) => s + t.amountCents, 0);

  const headers = ["Date", "Libellé", "Catégorie", "Personne", "MontantCents", "MontantEuros", "Source"];
  const rows = validTx.map(t => [
    t.bookingDate.toISOString().slice(0,10),
    `"${t.label.replace(/"/g, '""')}"`,
    t.categoryId || '',
    t.personId || '',
    t.amountCents.toString(), // centimes interne conservé
    centsToEurosForExport(t.amountCents).toString(),
    t.source,
  ].join(","));

  const content = [headers.join(","), ...rows].join("\n");

  return {
    fileName: `TENLA_Budget_${filters.familyId}_${new Date().toISOString().slice(0,10)}.csv`,
    content,
    totalCents,
  };
}

export interface PdfExportData {
  fileName: string;
  title: string;
  tables: { headers: string[]; rows: (string | number)[][] }[];
  totalCents: number;
  summary: { budgetedCents: number; spentCents: number; remainingCents: number };
}

export function preparePdfExport(transactions: Transaction[], budgets: Budget[], categories: Category[], filters: ExportFilters, role: Role): PdfExportData {
  assertCan(role, "budget:read");
  const validTx = filterForExport(transactions, filters);
  const totalSpentCents = validTx.reduce((s, t) => s + t.amountCents, 0);
  const filteredBudgets = budgets.filter(b => b.familyId === filters.familyId && (!filters.personId || b.personId === filters.personId));
  const totalBudgetedCents = filteredBudgets.reduce((s, b) => s + b.amountCents, 0);
  const remainingCents = totalBudgetedCents - totalSpentCents;

  const txRows = validTx.slice(0, 100).map(t => [ // limite 100 pour PDF
    t.bookingDate.toISOString().slice(0,10),
    t.label.slice(0,30),
    centsToEurosForExport(t.amountCents).toFixed(2) + " €",
  ]);

  return {
    fileName: `TENLA_Budget_${filters.familyId}_${new Date().toISOString().slice(0,10)}.pdf`,
    title: `TENΛ Budget - Export ${new Date().toISOString().slice(0,10)}`,
    tables: [{ headers: ["Date", "Libellé", "Montant"], rows: txRows }],
    totalCents: totalSpentCents,
    summary: { budgetedCents: totalBudgetedCents, spentCents: totalSpentCents, remainingCents },
  };
}

export function verifyExportTotals(transactions: Transaction[], exportData: { totalCents: number }, filters: ExportFilters): boolean {
  const validTx = filterForExport(transactions, filters);
  const realTotal = validTx.reduce((s, t) => s + t.amountCents, 0);
  return realTotal === exportData.totalCents;
}

// ---------- Écriture de fichiers (navigateur, aucune dépendance externe) ----------

/**
 * Déclenche le téléchargement d'un contenu texte sous forme de fichier.
 * Utilise Blob + URL.createObjectURL (navigateur uniquement).
 * Retourne true si le téléchargement a pu être initié.
 */
export function downloadAsFile(content: string, fileName: string, mimeType: string): boolean {
  if (typeof window === 'undefined' || typeof document === 'undefined') {
    return false;
  }
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 10000);
  return true;
}

/**
 * Construit une erreur explicite pour un format d'export non pris en charge.
 */
export function unsupportedFormatError(format: string): Error {
  return new Error(`EXPORT_FORMAT_NOT_SUPPORTED: le format "${format}" n'est pas pris en charge. Formats disponibles: csv.`);
}

/**
 * Prépare et télécharge un export CSV. Retourne les données préparées.
 * Lance une erreur explicite si le téléchargement n'est pas possible (environnement non navigateur).
 */
export function exportCsvToFile(transactions: Transaction[], filters: ExportFilters, role: Role): CsvExportData {
  const data = prepareCsvExport(transactions, filters, role);
  const ok = downloadAsFile(data.content, data.fileName, 'text/csv;charset=utf-8');
  if (!ok) {
    throw new Error('EXPORT_DOWNLOAD_UNAVAILABLE: impossible de déclencher le téléchargement du fichier CSV (environnement non navigateur).');
  }
  return data;
}
