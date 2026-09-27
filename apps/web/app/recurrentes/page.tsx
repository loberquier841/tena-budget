
import { auth } from "@/auth";

export default async function RecurrentesPage() {
  const session = await auth();
  if (!session) return <main style={{ marginLeft: 260, padding: 24 }}><p>Non connecté</p></main>;

  const mockRules = [
    { id: 'rec1', label: 'Abonnement sport', amountCents: 3000, periodicity: 'weekly', day: 'Lundi (1)', next: '2026-06-02', person: 'Parent 1', status: 'active' },
    { id: 'rec2', label: 'Loyer', amountCents: 80000, periodicity: 'monthly', day: '5', next: '2026-06-05', person: null, status: 'active' },
  ];

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1>🔁 Dépenses récurrentes — Règle distincte, jamais auto création réelle</h1>
      <p style={{ color: '#666' }}>Hebdo/mensuel, pending_validation, historique générations, soft delete, Int centimes, seuil 500€ owner</p>

      <button style={{ marginTop: 16, background: '#7C3AED', color: 'white', padding: '10px 16px', borderRadius: 8, border: 'none' }}>+ Nouvelle règle récurrente</button>

      <div style={{ background: 'white', borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
        {mockRules.map(r => (
          <div key={r.id} style={{ padding: 16, borderBottom: '1px solid #f3f4f6', display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <strong>{r.label}</strong> <span style={{ background: r.periodicity==='weekly'?'#ddd6fe':'#fef3c7', fontSize: 11, padding: '2px 8px', borderRadius: 12 }}>{r.periodicity}</span>
              <p style={{ fontSize: 12, color: '#666', marginTop: 4 }}>Montant: {(r.amountCents/100).toFixed(2)}€ ({r.amountCents}c) • Jour: {r.day} • Personne: {r.person || 'Famille'} • Prochaine: {r.next}</p>
              <p style={{ fontSize: 11, color: '#888' }}>Règle distincte des transactions réelles • Générations en pending_validation • Historique via RecurringGenerationLog</p>
            </div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
              <button style={{ fontSize: 12, padding: '6px 12px', borderRadius: 6, border: '1px solid #e5e7eb' }}>Générer occurrences</button>
              <button style={{ fontSize: 12, padding: '6px 12px', borderRadius: 6, border: '1px solid #fecaca', color: '#ef4444' }}>Supprimer (soft)</button>
            </div>
          </div>
        ))}
      </div>

      <div style={{ background: 'white', borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16, padding: 16 }}>
        <h3>Historique générations</h3>
        <p style={{ fontSize: 12, color: '#666' }}>Dernières générations: pending_validation → generated après validation utilisateur, jamais auto</p>
        <table style={{ width: '100%', marginTop: 8, fontSize: 12 }}>
          <thead><tr style={{ color: '#666' }}><th style={{ textAlign: 'left' }}>Période</th><th>Montant</th><th>Status</th><th>Transaction liée</th></tr></thead>
          <tbody>
            <tr><td>05/05/2026 - 05/06/2026</td><td>80000c</td><td><span style={{ background: '#fef3c7', padding: '2px 6px', borderRadius: 6 }}>pending_validation</span></td><td>— (en attente validation)</td></tr>
            <tr><td>05/04/2026 - 05/05/2026</td><td>80000c</td><td><span style={{ background: '#bbf7d0', padding: '2px 6px', borderRadius: 6 }}>generated</span></td><td>tx_abc123 (réelle créée après validation)</td></tr>
          </tbody>
        </table>
      </div>
    </main>
  );
}
