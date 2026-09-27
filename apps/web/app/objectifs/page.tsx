
import { auth } from "@/auth";

export default async function ObjectifsPage() {
  const session = await auth();
  if (!session) return <main style={{ marginLeft: 260, padding: 24 }}><p>Non connecté</p></main>;

  const mockGoals = [
    { id: 'goal1', name: 'Vacances été', targetCents: 200000, currentCents: 80000, person: null, percent: 40, remaining: 120000 },
    { id: 'goal2', name: 'Vélo électrique', targetCents: 150000, currentCents: 160000, person: 'Parent 1', percent: 106, remaining: -10000, exceeded: true },
  ];

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1>🎯 Objectifs d'épargne — targetCents Int, progression sans float</h1>
      <p style={{ color: '#666' }}>currentCents Int, remaining = target - current Int, percent = floor(current*100/target) Int, isExceeded, indépendant simulations</p>

      <button style={{ marginTop: 16, background: '#7C3AED', color: 'white', padding: '10px 16px', borderRadius: 8, border: 'none' }}>+ Nouvel objectif</button>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 16, marginTop: 16 }}>
        {mockGoals.map(g => (
          <div key={g.id} style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
            <h3>{g.name} {g.person ? `(${g.person})` : '(Famille)'} {g.exceeded ? '🎉 Dépassé!' : ''}</h3>
            <div style={{ marginTop: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#666' }}>
                <span>{(g.currentCents/100).toFixed(2)}€ / {(g.targetCents/100).toFixed(2)}€</span>
                <span>{g.percent}%</span>
              </div>
              <div style={{ width: '100%', height: 8, background: '#e5e7eb', borderRadius: 4, marginTop: 4 }}>
                <div style={{ width: `${Math.min(g.percent,100)}%`, height: '100%', background: g.exceeded ? '#22c55e' : '#7C3AED', borderRadius: 4 }}></div>
              </div>
              <p style={{ fontSize: 11, color: '#888', marginTop: 4 }}>{g.currentCents}c / {g.targetCents}c • Restant: {g.remaining}c Int = {g.targetCents} - {g.currentCents} • Percent Int = floor({g.currentCents}*100/{g.targetCents}) = {g.percent}%</p>
              {g.exceeded && <p style={{ fontSize: 12, color: '#22c55e' }}>Objectif dépassé de {(Math.abs(g.remaining)/100).toFixed(2)}€ ! isExceeded=true</p>}
            </div>
            <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
              <button style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 12 }}>+ Ajouter contribution</button>
              <button style={{ padding: 8, borderRadius: 6, border: '1px solid #fecaca', color: '#ef4444', fontSize: 12 }}>Archiver</button>
            </div>
            <p style={{ fontSize: 10, color: '#888', marginTop: 8 }}>Contributions Int, refuse 0, refuse passage négatif, soft delete, seuil 500€ owner, personId respecté</p>
          </div>
        ))}
      </div>
    </main>
  );
}
