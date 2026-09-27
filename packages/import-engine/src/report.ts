
import { ImportReport } from "./types";

export function formatReport(report: ImportReport): string {
  return `
Import terminé:
- Importés: ${report.imported.transactions} transactions, ${report.imported.budgets} budgets, ${report.imported.categories} catégories
- Ignorés: ${report.ignored.count}
- Modifiés: ${report.modified.count}
- Ambigus: ${report.ambiguous.count} (${report.ambiguous.columns.join(', ')})
- Doublons: ${report.duplicates.count}
- Erreurs: ${report.errors.count}
- Attention: ${report.attention.count}
- Années: ${report.yearsImported.join(', ')}
- Partiel: ${report.isPartial ? 'Oui - ' + report.attention.items.join('; ') : 'Non'}
  `.trim();
}
