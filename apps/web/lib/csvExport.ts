import { getLocalBudgets, getLocalTransactions } from '@tena/core/sync/dexie';

function csvCell(value: string | number): string {
  let safe = String(value);
  if (typeof value === 'string' && /^[\s\u0000-\u001f]*[=+@-]/.test(value)) safe = `'${safe}`;
  return `"${safe.replace(/"/g, '""')}"`;
}

function csvDocument(headers: string[], rows: Array<Array<string | number>>): string {
  return `\uFEFF${[headers, ...rows].map((row) => row.map(csvCell).join(';')).join('\r\n')}`;
}

export async function exportLocalTransactionsCsv(familyId: string): Promise<string> {
  const transactions = await getLocalTransactions(familyId);
  return csvDocument(
    ['id', 'date', 'libelle', 'source', 'categorie_id', 'personne_id', 'montant_centimes', 'montant_euros'],
    transactions.map((transaction) => [
      transaction.id,
      transaction.bookingDate.toISOString(),
      transaction.label,
      transaction.source ?? 'manual',
      transaction.categoryId ?? '',
      transaction.personId ?? '',
      transaction.amountCents,
      transaction.amountCents / 100,
    ]),
  );
}

export async function exportLocalBudgetsCsv(familyId: string): Promise<string> {
  const budgets = await getLocalBudgets(familyId);
  return csvDocument(
    ['id', 'annee', 'mois', 'categorie_id', 'personne_id', 'montant_centimes', 'montant_euros'],
    budgets.map((budget) => [
      budget.id,
      budget.year,
      budget.month ?? '',
      budget.categoryId ?? '',
      budget.personId ?? '',
      budget.amountCents,
      budget.amountCents / 100,
    ]),
  );
}
