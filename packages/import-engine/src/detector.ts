
import { AnalyzedSheet, RecognizedData, RecognizedColumn, AmbiguousColumn } from "./types";
import { parseEuroToCents, parseFrenchDate, isFormulaSafe, convertFormulaSafe, hashDedup } from "./parser";

const HEADER_MAP: Record<string, RecognizedColumn['mappedTo']> = {
  'categorie': 'category',
  'catégorie': 'category',
  'categories': 'category',
  'budget': 'budget',
  'budget annuel': 'budget',
  'prévu': 'budget',
  'dépense': 'amount',
  'depensé': 'spent',
  'dépensé': 'spent',
  'restant': 'remaining',
  'reste': 'remaining',
  'personne': 'person',
  'person': 'person',
  'qui': 'person',
  'date': 'date',
  'année': 'date',
  'montant': 'amount',
  'libellé': 'label',
  'libelle': 'label',
  'description': 'label',
  'objectif': 'goal',
  'économies': 'goal',
};

export function detectColumns(headers: string[], sampleRows: Record<string, any>[]): { recognized: RecognizedColumn[]; ambiguous: AmbiguousColumn[] } {
  const recognized: RecognizedColumn[] = [];
  const ambiguous: AmbiguousColumn[] = [];

  for (const header of headers) {
    const norm = header.toLowerCase().trim();
    let mappedTo: RecognizedColumn['mappedTo'] = 'unknown';
    let confidence = 0;

    // Match exact
    if (HEADER_MAP[norm]) {
      mappedTo = HEADER_MAP[norm];
      confidence = 95;
    } else {
      // Fuzzy
      for (const [key, val] of Object.entries(HEADER_MAP)) {
        if (norm.includes(key)) {
          mappedTo = val;
          confidence = 70;
          break;
        }
      }
    }

    // Détection par contenu si header inconnu
    const samples = sampleRows.map(r => r[header]).filter(v => v != null).slice(0,5);
    if (mappedTo === 'unknown') {
      const euroCount = samples.filter(v => parseEuroToCents(v) !== null).length;
      const dateCount = samples.filter(v => parseFrenchDate(v) !== null).length;
      if (euroCount >= 3) {
        mappedTo = 'amount';
        confidence = 60;
      } else if (dateCount >= 3) {
        mappedTo = 'date';
        confidence = 60;
      }
    }

    const col: RecognizedColumn = { originalHeader: header, mappedTo, confidence, sampleValues: sampleRows.map(r => r[header]).slice(0,3) };

    if (confidence < 80) {
      ambiguous.push({
        column: header,
        guesses: [{ mappedTo, confidence }],
        sampleValues: col.sampleValues,
        status: 'pending',
      });
    }
    recognized.push(col);
  }

  return { recognized, ambiguous };
}

export function recognizeData(sheets: AnalyzedSheet[], columnMappings?: Record<string, RecognizedColumn['mappedTo']>): { data: RecognizedData; ambiguous: AmbiguousColumn[] } {
  const allHeaders = sheets.flatMap(s => s.headers);
  const allRows = sheets.flatMap(s => s.rows);

  const { recognized, ambiguous } = detectColumns(allHeaders, allRows);

  // Applique corrections utilisateur = réexécution réelle
  const effectiveMapping = { ...Object.fromEntries(recognized.map(r => [r.originalHeader, r.mappedTo])), ...(columnMappings || {}) };

  const categories: RecognizedData['categories'] = [];
  const budgets: RecognizedData['budgets'] = [];
  const transactions: RecognizedData['transactions'] = [];
  const persons = new Set<string>();
  const goals: RecognizedData['goals'] = [];
  const years = new Set<number>();
  const formulas: RecognizedData['formulas'] = [];

  const partialWarnings: string[] = [];

  for (let i=0;i<allRows.length;i++) {
    const row = allRows[i];
    // Détection catégorie
    const catHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'category');
    const budgetHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'budget');
    const amountHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'amount' || effectiveMapping[k] === 'spent');
    const dateHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'date');
    const personHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'person');
    const labelHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'label');
    const goalHeader = Object.keys(effectiveMapping).find(k => effectiveMapping[k] === 'goal');

    if (catHeader && row[catHeader]) {
      categories.push({ name: String(row[catHeader]), sourceRow: i });
    }
    if (budgetHeader && amountHeader) {
      // budget
    }
    // Montants
    let amountCents: number | null = null;
    if (amountHeader) amountCents = parseEuroToCents(row[amountHeader]);
    if (budgetHeader) {
      const b = parseEuroToCents(row[budgetHeader]);
      if (b !== null && catHeader) {
        const year = dateHeader ? parseFrenchDate(row[dateHeader])?.getFullYear() : new Date().getFullYear();
        if (year) years.add(year);
        budgets.push({ category: String(row[catHeader]||'Sans catégorie'), amountCents: b, year, type: 'annual' });
      }
    }
    // Date
    let bookingDate: Date | null = null;
    if (dateHeader) bookingDate = parseFrenchDate(row[dateHeader]);
    if (!bookingDate) bookingDate = new Date();

    // Personne - conservation obligatoire
    let person: string | undefined;
    if (personHeader && row[personHeader]) {
      person = String(row[personHeader]);
      persons.add(person);
    }

    // Transaction si label + amount
    const label = labelHeader ? String(row[labelHeader]||'') : (catHeader ? String(row[catHeader]||'') : '');
    if (label && amountCents !== null) {
      if (bookingDate) years.add(bookingDate.getFullYear());
      transactions.push({
        label,
        amountCents,
        bookingDate,
        category: catHeader ? String(row[catHeader]||'') : undefined,
        person,
        hashDedup: hashDedup(bookingDate, amountCents, label),
        sourceRow: i,
      });
    }

    // Objectif
    if (goalHeader && row[goalHeader]) {
      goals.push({ name: String(row[goalHeader]), targetCents: amountCents || undefined });
    }

    // Formules
    for (const [k,v] of Object.entries(row)) {
      if (typeof v === 'string' && v.startsWith('=')) {
        const safe = isFormulaSafe(v);
        const converted = safe.safe ? convertFormulaSafe(v) : null;
        formulas.push({ raw: v, converted: converted || '', isSafe: safe.safe, row: i, col: k });
        if (!safe.safe) {
          partialWarnings.push(`Formule non sécurisée ligne ${i} col ${k}: ${v}`);
        }
      }
    }
  }

  const isPartial = categories.length === 0 || budgets.length === 0 || transactions.length === 0;
  if (categories.length === 0) partialWarnings.push("Aucune catégorie détectée");
  if (budgets.length === 0 && transactions.length > 0) partialWarnings.push("Dépenses trouvées mais aucun budget - création proposée");
  if (transactions.length === 0 && budgets.length > 0) partialWarnings.push("Budgets trouvés mais aucune dépense");

  return {
    data: {
      columns: recognized.map(r => ({ ...r, mappedTo: effectiveMapping[r.originalHeader] || r.mappedTo })),
      categories,
      budgets,
      transactions,
      persons: Array.from(persons),
      goals,
      years: Array.from(years).sort(),
      formulas,
      isPartial,
      partialWarnings,
    },
    ambiguous,
  };
}
