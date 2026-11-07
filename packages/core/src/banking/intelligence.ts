// TENΛ Budget — Intelligence financière (fonctions pures, local-first)

export interface TxLike { amountCents: number; label: string; date: Date; category?: string; }

export function spendingByCategory(txs: TxLike[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const t of txs) {
    if (t.amountCents >= 0) continue;
    const c = t.category || 'autre';
    out[c] = (out[c] || 0) + Math.abs(t.amountCents);
  }
  return out;
}

export function monthlyTotal(txs: TxLike[], month: number, year: number): number {
  let s = 0;
  for (const t of txs) {
    if (t.date.getMonth() === month && t.date.getFullYear() === year) s += t.amountCents;
  }
  return s;
}

// Détection d'abonnements: labels récurrents mensuels
export function detectSubscriptions(txs: TxLike[]): { label: string; amountCents: number; occurrences: number }[] {
  const map = new Map<string, { amounts: number[]; dates: Date[] }>();
  for (const t of txs) {
    if (t.amountCents >= 0) continue;
    const key = t.label.trim().toLowerCase();
    if (!map.has(key)) map.set(key, { amounts: [], dates: [] });
    const e = map.get(key)!;
    e.amounts.push(Math.abs(t.amountCents));
    e.dates.push(t.date);
  }
  const res: { label: string; amountCents: number; occurrences: number }[] = [];
  for (const [label, e] of map) {
    if (e.dates.length < 2) continue;
    // check roughly monthly recurrence
    const sorted = [...e.dates].sort((a, b) => a.getTime() - b.getTime());
    let monthly = true;
    for (let i = 1; i < sorted.length; i++) {
      const days = (sorted[i].getTime() - sorted[i - 1].getTime()) / 86400000;
      if (days < 25 || days > 35) { monthly = false; break; }
    }
    if (!monthly) continue;
    const avg = Math.round(e.amounts.reduce((s, x) => s + x, 0) / e.amounts.length);
    res.push({ label, amountCents: avg, occurrences: e.dates.length });
  }
  return res;
}

// Opérations inhabituelles: z-score simple sur montants
export function detectUnusual(txs: TxLike[], threshold = 2.5): TxLike[] {
  if (txs.length < 3) return [];
  const vals = txs.map(t => Math.abs(t.amountCents));
  const mean = vals.reduce((s, x) => s + x, 0) / vals.length;
  const variance = vals.reduce((s, x) => s + (x - mean) ** 2, 0) / vals.length;
  const std = Math.sqrt(variance) || 1;
  return txs.filter(t => Math.abs(Math.abs(t.amountCents) - mean) / std > threshold);
}

// Prévision trésorerie: moyenne des 3 derniers mois
export function forecastCashflow(txs: TxLike[], monthsAhead = 3): number[] {
  const now = new Date();
  const monthly: number[] = [];
  for (let i = 1; i <= 3; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    monthly.push(monthlyTotal(txs, d.getMonth(), d.getFullYear()));
  }
  const avg = monthly.reduce((s, x) => s + x, 0) / monthly.length;
  return Array.from({ length: monthsAhead }, () => Math.round(avg));
}

// Catégorisation automatique par mot-clé
const KEYWORDS: Record<string, string[]> = {
  alimentation: ['carrefour', 'lidl', 'auchan', 'restaurant', 'mcdo', 'burger'],
  transport: ['sncf', 'ratp', 'uber', 'taxi', 'essence', 'total'],
  logement: ['loyer', 'edf', 'eau', 'internet', 'orange', 'sfr'],
  loisirs: ['netflix', 'spotify', 'cinema', 'steam'],
};
export function autoCategorize(label: string): string {
  const l = label.toLowerCase();
  for (const [cat, kws] of Object.entries(KEYWORDS)) {
    if (kws.some(k => l.includes(k))) return cat;
  }
  return 'autre';
}

export interface Alert { level: 'info' | 'warning' | 'critical'; message: string; }
export function generateAlerts(txs: TxLike[], budgetCents?: number): Alert[] {
  const alerts: Alert[] = [];
  const spend = txs.filter(t => t.amountCents < 0).reduce((s, t) => s + Math.abs(t.amountCents), 0);
  if (budgetCents && spend > budgetCents) alerts.push({ level: 'critical', message: 'Budget dépassé' });
  const subs = detectSubscriptions(txs);
  if (subs.length > 5) alerts.push({ level: 'warning', message: 'Nombreux abonnements détectés' });
  const unusual = detectUnusual(txs);
  if (unusual.length) alerts.push({ level: 'warning', message: 'Opérations inhabituelles détectées' });
  return alerts;
}
