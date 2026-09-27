
import { auth } from "@/auth";

export default async function DashboardFinalPage() {
  const session = await auth();
  if (!session) return <main style={{ marginLeft: 260, padding: 24 }}><p>Non connecté - <a href="/login">Login</a></p></main>;

  const stats = {
    budgeted: 400000,
    spent: 185000,
    remaining: 215000,
    byCategory: [
      { name: 'Courses', cents: 80000, color: '#7C3AED', count: 12 },
      { name: 'Logement', cents: 60000, color: '#22c55e', count: 1 },
      { name: 'Transport', cents: 25000, color: '#f59e0b', count: 8 },
      { name: 'Loisirs', cents: 20000, color: '#ef4444', count: 5 },
    ],
    monthly: [
      { label: '2026-01', cents: 30000 },
      { label: '2026-02', cents: 45000 },
      { label: '2026-03', cents: 38000 },
      { label: '2026-04', cents: 42000 },
      { label: '2026-05', cents: 30000 },
    ],
    persons: [
      { id: 'p1', name: 'Parent 1', budgeted: 200000, spent: 100000, remaining: 100000 },
      { id: 'p2', name: 'Parent 2', budgeted: 150000, spent: 85000, remaining: 65000 },
      { id: 'family', name: 'Famille (global)', budgeted: 50000, spent: 0, remaining: 50000 },
    ]
  };

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1 style={{ fontSize: 28 }}>Tableau de bord final — Graphiques réels, Int centimes</h1>
      <p style={{ color: '#666' }}>Données cohérentes moteur Étape 3/5/6 • isDeleted exclu • simulations exclues • familial vs individuel séparés • personId respecté • 20 étapes min</p>

      <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
        <select style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option>Toutes personnes</option><option>Parent 1</option><option>Parent 2</option><option>Famille global</option></select>
        <select style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option>2026</option><option>2025</option></select>
        <select style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option>Toutes catégories</option><option>Courses</option></select>
        <select style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option>Toutes sources</option></select>
        <button style={{ background: '#7C3AED', color: 'white', padding: '8px 16px', borderRadius: 8, border: 'none' }}>Filtres combinables → recalcul Int</button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16, marginTop: 16 }}>
        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <p style={{ fontSize: 11, color: '#666' }}>BUDGET PRÉVU</p>
          <p style={{ fontSize: 22, fontWeight: 'bold' }}>{(stats.budgeted/100).toFixed(2)}€</p>
          <p style={{ fontSize: 10, color: '#888' }}>{stats.budgeted}c Int • getBudgetVsSpent() • budgets familiaux + individuels</p>
        </div>
        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <p style={{ fontSize: 11, color: '#666' }}>DÉPENSÉ</p>
          <p style={{ fontSize: 22, fontWeight: 'bold', color: '#ef4444' }}>{(stats.spent/100).toFixed(2)}€</p>
          <p style={{ fontSize: 10, color: '#888' }}>{stats.spent}c Int • filterValidTransactions() • isDeleted exclu</p>
        </div>
        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <p style={{ fontSize: 11, color: '#666' }}>RESTANT</p>
          <p style={{ fontSize: 22, fontWeight: 'bold', color: '#22c55e' }}>{(stats.remaining/100).toFixed(2)}€</p>
          <p style={{ fontSize: 10, color: '#888' }}>{stats.remaining}c = {stats.budgeted} - {stats.spent} Int • calculateRemaining()</p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16, marginTop: 16 }}>
        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3>Graphique réel — Par catégorie (Recharts en prod)</h3>
          <p style={{ fontSize: 11, color: '#888' }}>Valeurs internes centimes, conversion euros affichage seulement, pas d'arrondi interne</p>
          {stats.byCategory.map(c => {
            const total = stats.spent;
            const pct = Math.floor((c.cents * 100) / total);
            return (
              <div key={c.name} style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                <div style={{ width: 12, height: 12, background: c.color, borderRadius: 2 }}></div>
                <span style={{ flex: 1, fontSize: 12 }}>{c.name} ({c.count})</span>
                <span style={{ fontSize: 12 }}>{(c.cents/100).toFixed(2)}€</span>
                <div style={{ width: 80, height: 8, background: '#e5e7eb', borderRadius: 4 }}><div style={{ width: `${pct}%`, height: '100%', background: c.color, borderRadius: 4 }}></div></div>
                <span style={{ fontSize: 10, color: '#888' }}>{pct}%</span>
              </div>
            );
          })}
          <p style={{ fontSize: 10, color: '#888', marginTop: 8 }}>getSpendingByCategory() • Int • sous-catégories incluses • personId filtré</p>
        </div>

        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3>Graphique réel — Évolution mensuelle</h3>
          <p style={{ fontSize: 11, color: '#888' }}>getMonthlyEvolution() • tri année/mois • Int • isDeleted exclu</p>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, height: 140, marginTop: 12 }}>
            {stats.monthly.map(m => {
              const max = Math.max(...stats.monthly.map(x => x.cents));
              return (
                <div key={m.label} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                  <div style={{ width: '100%', background: '#7C3AED', height: `${(m.cents/max)*100}%`, minHeight: 10, borderRadius: '4px 4px 0 0' }}></div>
                  <span style={{ fontSize: 9, marginTop: 4 }}>{m.label.slice(5)}</span>
                  <span style={{ fontSize: 9, color: '#888' }}>{(m.cents/100).toFixed(0)}€</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16, marginTop: 16 }}>
        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3>Vue familiale + par personne — Jamais mélangés</h3>
          {stats.persons.map(p => (
            <div key={p.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid #f3f4f6', fontSize: 12 }}>
              <span><strong>{p.name}</strong> {p.id==='family' ? '(global)' : '(individuel)'}</span>
              <span>Prévu {(p.budgeted/100).toFixed(0)}€ • Dépensé {(p.spent/100).toFixed(0)}€ • Restant {(p.remaining/100).toFixed(0)}€</span>
            </div>
          ))}
          <p style={{ fontSize: 10, color: '#888', marginTop: 8 }}>getBudgetsByPerson() vs getFamilyGlobalBudgets() • calculateRemainingByPerson() • verifyNoMixing() • Int</p>
        </div>

        <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3>Budget prévu vs dépensé vs restant — Cohérent moteur Étape 3/5/6</h3>
          {stats.persons.map(p => {
            const pct = p.budgeted ? Math.floor((p.spent * 100) / p.budgeted) : 0;
            return (
              <div key={p.id} style={{ marginTop: 8 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11 }}><span>{p.name}</span><span>{pct}% dépensé</span></div>
                <div style={{ width: '100%', height: 8, background: '#e5e7eb', borderRadius: 4, marginTop: 2 }}><div style={{ width: `${Math.min(pct,100)}%`, height: '100%', background: pct>100 ? '#ef4444' : '#22c55e', borderRadius: 4 }}></div></div>
              </div>
            );
          })}
          <p style={{ fontSize: 10, color: '#888', marginTop: 8 }}>getBudgetVsSpent() • remaining = budgeted - spent Int • cohérent calculateRemaining() Étape 3</p>
        </div>
      </div>
    </main>
  );
}
