
// Prépare données fiables pour interface graphiques
// Valeurs internes en centimes Int, conversion euros uniquement présentation, pas d'arrondi interne

export interface ChartPoint {
  label: string;
  valueCents: number; // Int
  count?: number;
}

export interface ChartDataset {
  id: string;
  label: string;
  points: ChartPoint[];
}

// Conversion présentation seulement - jamais pour calcul
export function centsToEurosDisplay(cents: number): string {
  // Présentation seulement, garde 2 décimales pour affichage
  return (cents / 100).toFixed(2) + " €";
}

export function centsToEurosNumber(cents: number): number {
  // Pour graphique qui a besoin de number, mais valeur interne reste Int
  // On ne doit pas utiliser ce number pour recalcul financier
  return cents / 100;
}

export function prepareCategoryChart(data: { categoryId: string; categoryName: string; totalCents: number }[]): ChartDataset {
  return {
    id: "spending_by_category",
    label: "Dépenses par catégorie",
    points: data.map(d => ({ label: d.categoryName, valueCents: d.totalCents })),
  };
}

export function prepareMonthlyChart(data: { year: number; month: number; totalCents: number }[]): ChartDataset {
  return {
    id: "monthly_evolution",
    label: "Évolution mensuelle",
    points: data.map(d => ({ label: `${d.year}-${String(d.month).padStart(2,'0')}`, valueCents: d.totalCents })),
  };
}

export function preparePersonChart(data: { personId: string; totalCents: number }[]): ChartDataset {
  return {
    id: "by_person",
    label: "Par personne",
    points: data.map(d => ({ label: d.personId, valueCents: d.totalCents })),
  };
}

export function prepareBudgetVsSpentChart(data: { budgetedCents: number; spentCents: number; remainingCents: number; label: string }[]): { budgeted: ChartDataset; spent: ChartDataset; remaining: ChartDataset } {
  return {
    budgeted: { id: "budgeted", label: "Prévu", points: data.map(d => ({ label: d.label, valueCents: d.budgetedCents })) },
    spent: { id: "spent", label: "Dépensé", points: data.map(d => ({ label: d.label, valueCents: d.spentCents })) },
    remaining: { id: "remaining", label: "Restant", points: data.map(d => ({ label: d.label, valueCents: d.remainingCents })) },
  };
}
