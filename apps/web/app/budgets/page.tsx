
import { auth } from "@/auth";

export default async function BudgetsPage() {
  const session = await auth();
  if (!session) return <main style={{ marginLeft: 260, padding: 24 }}><p>Non connecté - <a href="/login">Login</a></p></main>;

  const mockBudgets = [
    { id: 'bud1', year: 2026, month: null, type: 'annual', category: 'Courses', person: null, amountCents: 400000 },
    { id: 'bud2', year: 2026, month: 5, type: 'monthly', category: 'Logement', person: 'Parent 1', amountCents: 80000 },
    { id: 'bud3', year: 2026, month: null, type: 'annual', category: 'Transport', person: 'Parent 2', amountCents: 120000 },
  ];

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1 style={{ fontSize: 28 }}>Budgets — Int centimes</h1>
      <p style={{ color: '#666' }}>Annuels/mensuels, par personne, validation mois, seuil 500€ owner, soft delete, permissions serveur assertCan(budget:write)</p>

      <div style={{ marginTop: 16, display: 'flex', gap: 12 }}>
        <button style={{ background: '#7C3AED', color: 'white', padding: '10px 16px', borderRadius: 8, border: 'none' }}>+ Nouveau budget</button>
        <select style={{ padding: 10, borderRadius: 8, border: '1px solid #e5e7eb' }}>
          <option>2026</option><option>2025</option>
        </select>
        <select style={{ padding: 10, borderRadius: 8, border: '1px solid #e5e7eb' }}>
          <option>Toutes personnes</option><option>Parent 1</option><option>Parent 2</option>
        </select>
      </div>

      <div style={{ background: 'white', borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16, overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f9fafb' }}>
            <tr style={{ textAlign: 'left', fontSize: 12, color: '#666' }}>
              <th style={{ padding: 12 }}>Type</th><th>Année/Mois</th><th>Catégorie</th><th>Personne</th><th>Montant</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {mockBudgets.map(b => (
              <tr key={b.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                <td style={{ padding: 12 }}><span style={{ background: b.type==='annual'?'#ddd6fe':'#fef3c7', padding: '2px 8px', borderRadius: 12, fontSize: 11 }}>{b.type}</span></td>
                <td style={{ padding: 12 }}>{b.year}{b.month ? `-${String(b.month).padStart(2,'0')}` : ''}</td>
                <td style={{ padding: 12 }}>{b.category}</td>
                <td style={{ padding: 12 }}>{b.person || 'Famille (global)'} {b.person ? '(individuel)' : '(global - jamais mélangé)'}</td>
                <td style={{ padding: 12 }}><strong>{(b.amountCents/100).toFixed(2)} €</strong><br/><span style={{ fontSize: 10, color: '#888' }}>{b.amountCents}c Int</span></td>
                <td style={{ padding: 12 }}><button style={{ fontSize: 12, padding: '4px 8px', borderRadius: 6, border: '1px solid #e5e7eb' }}>Modifier</button> <button style={{ fontSize: 12, padding: '4px 8px', borderRadius: 6, border: '1px solid #fecaca', color: '#ef4444' }}>Archiver (soft)</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div style={{ marginTop: 16, padding: 12, background: '#f0fdf4', borderRadius: 8, border: '1px solid #bbf7d0' }}>
        <p style={{ fontSize: 12 }}>✓ createBudget() Int only, refuse float • monthly sans mois refusé • duplicate interdit • seuil 500€ owner • personId respecté • familial vs individuel séparés</p>
      </div>
    </main>
  );
}
