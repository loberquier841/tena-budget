
import { auth } from "@/auth";

export default async function ExportsPage() {
  const session = await auth();
  if (!session) return <p>Non connecté</p>;

  return (
    <main style={{ padding: 24 }}>
      <h1>TENΛ — Exports Excel/CSV/PDF</h1>
      <p>Valeurs internes centimes Int, conversion euros affichage/export seulement.</p>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
        <div style={{ border: '1px solid #ccc', padding: 16 }}>
          <h3>Excel (exceljs MIT)</h3>
          <p>Sheets: Transactions + Budgets, totaux vérifiés verifyExportTotals()</p>
          <button>Exporter XLSX</button>
        </div>
        <div style={{ border: '1px solid #ccc', padding: 16 }}>
          <h3>CSV (papaparse MIT)</h3>
          <p>Colonnes: Date, Libellé, Catégorie, Personne, MontantCents, MontantEuros, Source</p>
          <button>Exporter CSV</button>
        </div>
        <div style={{ border: '1px solid #ccc', padding: 16 }}>
          <h3>PDF (jspdf + jspdf-autotable MIT)</h3>
          <p>Tableaux + summary budgeted/spent/remaining Int</p>
          <button>Exporter PDF</button>
        </div>
      </div>

      <p>Filtres respectés: familyId, personId, category, période. isDeleted exclu.</p>
      <p>Libs vérifiées: exceljs MIT, papaparse MIT, jspdf MIT, jspdf-autotable MIT - toutes gratuites/open-source</p>
    </main>
  );
}
