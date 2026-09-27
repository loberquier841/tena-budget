
import { RecognizedData, DuplicateGroup, ComparisonItem } from "./types";

export function detectDuplicates(incoming: RecognizedData['transactions'], existing: { id: string; amountCents: number; bookingDate: Date; label: string; hashDedup: string }[]): DuplicateGroup[] {
  const groups: DuplicateGroup[] = [];
  const hashMap = new Map<string, typeof existing>();

  for (const ex of existing) {
    const list = hashMap.get(ex.hashDedup) || [];
    list.push(ex);
    hashMap.set(ex.hashDedup, list);
  }

  for (const inc of incoming) {
    const matches = hashMap.get(inc.hashDedup);
    if (matches && matches.length > 0) {
      // Exact duplicate
      groups.push({
        id: `dup_${inc.hashDedup}`,
        type: 'exact',
        transactions: [inc],
        existingTransactionIds: matches.map(m => m.id),
      });
    } else {
      // Likely duplicate: même montant + date proche + label similaire
      const likely = existing.filter(e => 
        e.amountCents === inc.amountCents &&
        Math.abs(e.bookingDate.getTime() - inc.bookingDate.getTime()) < 2*24*60*60*1000 &&
        e.label.toLowerCase().includes(inc.label.toLowerCase().slice(0,5))
      );
      if (likely.length > 0) {
        groups.push({
          id: `dup_likely_${inc.hashDedup}`,
          type: 'likely',
          transactions: [inc],
          existingTransactionIds: likely.map(l => l.id),
        });
      }
    }
  }

  return groups;
}

export function compareDuplicates(groups: DuplicateGroup[], existingMap: Map<string, { id: string; label: string; amountCents: number; bookingDate: Date }>): ComparisonItem[] {
  const items: ComparisonItem[] = [];
  for (const g of groups) {
    for (const inc of g.transactions) {
      const existingId = g.existingTransactionIds?.[0];
      const existing = existingId ? existingMap.get(existingId) : undefined;
      const diff: string[] = [];
      if (existing) {
        if (existing.label !== inc.label) diff.push(`Libellé différent: "${existing.label}" vs "${inc.label}"`);
        if (existing.amountCents !== inc.amountCents) diff.push(`Montant différent: ${existing.amountCents} vs ${inc.amountCents}`);
      }
      items.push({ incoming: inc, existing, diff });
    }
  }
  return items;
}

export function applyDuplicateDecisions(groups: DuplicateGroup[], decisions: Record<string, DuplicateGroup['decision']>): { toImport: RecognizedData['transactions']; toIgnore: RecognizedData['transactions'] } {
  const toImport: RecognizedData['transactions'] = [];
  const toIgnore: RecognizedData['transactions'] = [];

  for (const g of groups) {
    const decision = decisions[g.id] || 'keep_both'; // par défaut conserver les deux, jamais suppression silencieuse
    if (decision === 'keep_both') {
      toImport.push(...g.transactions);
    } else if (decision === 'keep_first') {
      // keep existing, ignore incoming
      toIgnore.push(...g.transactions);
    } else if (decision === 'keep_second') {
      toImport.push(...g.transactions);
    } else if (decision === 'compare') {
      // L'utilisateur doit choisir après comparaison - pour l'instant on garde en attente
      toIgnore.push(...g.transactions);
    }
  }

  return { toImport, toIgnore };
}
