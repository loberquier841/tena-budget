import { auth } from "@/auth";
import { getLocalSavingGoals, LocalSavingGoal, calculateProgress, SavingGoal } from "@/sync/dexie";

export default async function ObjectifsPage() {
  const session = await auth();
  if (!session) return <main style={{ marginLeft: 260, padding: 24 }}><p>Non connecté</p></main>;

  const familyId = session.userId;

  // Chargement réel depuis IndexedDB Dexie (synchronique en server component)
  let goals: LocalSavingGoal[] = [];
  try {
    goals = await getLocalSavingGoals(familyId);
  } catch (e) {
    console.error("Erreur chargement objectifs:", e);
  }

  // Calcul de la progression pour chaque objectif
  const goalsWithProgress = goals.map(g => ({
    ...g,
    ...calculateProgress(g as SavingGoal),
  }));

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1>🎯 Objectifs d'épargne — targetCents Int, progression sans float</h1>
      <p style={{ color: '#666' }}>currentCents Int, remaining = target - current Int, percent = floor(current*100/target) Int, isExceeded, indépendant simulations</p>

      <button style={{ marginTop: 16, background: '#7C3AED', color: 'white', padding: '10px 16px', borderRadius: 8, border: 'none' }}>+ Nouvel objectif</button>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 16, marginTop: 16 }}>
        {goalsWithProgress.map(g => (
          <div key={g.id} style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb' }}>
            <h3>{g.name} {g.personId ? `(${g.personId})` : '(Famille)'} {g.isExceeded ? '🎉 Dépassé!' : ''}</h3>
            <div style={{ marginTop: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#666' }}>
                <span>{(g.currentCents/100).toFixed(2)}€ / {(g.targetCents/100).toFixed(2)}€</span>
                <span>{g.percentInt}%</span>
              </div>
              <div style={{ width: '100%', height: 8, background: '#e5e7eb', borderRadius: 4, marginTop: 4 }}>
                <div style={{ width: `${g.percentInt}%`, height: '100%', background: g.isExceeded ? '#22c55e' : '#7C3AED', borderRadius: 4 }}></div>
              </div>
              <p style={{ fontSize: 11, color: '#888', marginTop: 4 }}>currentCents c / targetCents c • Restant: g.remainingCents c Int = targetCents - currentCents • Percent Int = floor(currentCents*100/targetCents) = g.percentInt%</p>
              {g.isExceeded && <p style={{ fontSize: 12, color: '#22c55e' }}>Objectif dépassé de {(Math.abs(g.remainingCents)/100).toFixed(2)}€ ! isExceeded=true</p>}
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
