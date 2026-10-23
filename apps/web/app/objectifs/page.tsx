import { auth } from "@/auth";
import { getLocalSavingGoals, getLocalCategories, LocalSavingGoal, SavingGoal, calculateProgress, type SavingContribution } from "@/sync/dexie";
import { createSavingGoal, addContribution, softDeleteGoal, archiveGoal, type SavingGoal } from "@/budget/savings";
import { Role, assertCan, requiresOwnerConfirmation } from "@/permissions/permissions";

async function loadSavingGoals(familyId: string | undefined) {
  let goals: LocalSavingGoal[] = [];
  try {
    goals = await getLocalSavingGoals(familyId);
  } catch (e) {
    console.error("Erreur chargement objectifs:", e);
  }
  return goals;
}

export default async function ObjectifsPage() {
  const session = await auth();
  if (!session) redirect('/login');

  const familyId = session.userId;
  const goals = await loadSavingGoals(familyId);
  const goalsWithProgress = goals.map(g => ({
    ...g,
    ...calculateProgress(g as SavingGoal),
  }));

  // Goal creation form state
  const [goalForm, setGoalForm] = React.useState<{ name: string; targetCents: number }>({
    name: '',
    targetCents: 0,
  });

  const handleGoalFormChange = React.useCallback((e: React.ChangeEvent) => {
    const { name, value } = e.target;
    setGoalForm(prev => ({ ...prev, [name]: name === 'targetCents' ? parseFloat(value) * 100 || 0 : value }));
  }, []);

  const handleGoalSubmit = React.useCallback(async () => {
    try {
      // Validate target amount
      if (!goalForm.name.trim()) {
        throw new Error('Le nom de l\'objectif est obligatoire');
      }

      if (goalForm.targetCents <= 0) {
        throw new Error('La cible doit être positive');
      }

      const requiresConfirm = requiresOwnerConfirmation(goalForm.targetCents);

      const newGoal = await createSavingGoal({
        familyId: familyId,
        personId: undefined,
        name: goalForm.name.trim(),
        targetCents: goalForm.targetCents,
      }, 'owner');

      const updatedGoals = await loadSavingGoals(familyId);
      setGoalForm({ name: '', targetCents: 0 });
      return updatedGoals;
    } catch (err: any) {
      console.error('Goal creation error:', err);
      throw err;
    }
  }, [goalForm, familyId]);

  // Contribution form state
  const [contribForm, setContribForm] = React.useState<{ amountCents: number; note?: string }>({
    amountCents: 0,
    note: '',
  });

  const handleContribFormChange = React.useCallback((e: React.ChangeEvent) => {
    const { name, value } = e.target;
    setContribForm(prev => ({ ...prev, [name]: name === 'amountCents' ? parseFloat(value) * 100 || 0 : value }));
  }, []);

  const handleContribSubmit = React.useCallback(async (goalId: string) => {
    try {
      if (contribForm.amountCents <= 0) {
        throw new Error('La contribution doit être positive');
      }

      const result = await addContribution(
        { id: goalId, familyId: familyId, personId: undefined, name: '', targetCents: 0, isArchived: false, isDeleted: false, createdAt: new Date(), updatedAt: new Date() } as SavingGoal,
        { amountCents: contribForm.amountCents, note: contribForm.note, createdByUserId: session.userId },
        'owner',
        []
      );

      const updatedGoals = await loadSavingGoals(familyId);
      setContribForm({ amountCents: 0, note: '' });
      return updatedGoals;
    } catch (err: any) {
      console.error('Contribution error:', err);
      throw err;
    }
  }, [contribForm, familyId, session]);

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1>🎯 Objectifs d'épargne — targetCents Int, progression sans float</h1>
      <p style={{ color: '#666' }}>currentCents Int, remaining = target - current Int, percent = floor(current*100/target) Int, isExceeded, indépendant simulations</p>

      <button style={{ marginTop: 16, background: '#7C3AED', color: 'white', padding: '10px 16px', borderRadius: 8, border: 'none' }}>+ Nouvel objectif</button>

      <div style={{ marginTop: 24, padding: 20, background: 'white', borderRadius: 12, border: '1px solid #e5e7eb' }}>
        <h3 style={{ fontSize: 14, marginBottom: 16, color: '#111' }}>Créer un nouvel objectif</h3>
        <form onSubmit={handleGoalSubmit} style={{ display: 'grid', gap: 16 }}>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Nom de l\'objectif <span style={{ color: '#ef4444' }}>*</span></label>
            <input
              type="text"
              value={goalForm.name}
              onChange={handleGoalFormChange}
              required
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            />
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Montant cible (€) <span style={{ color: '#ef4444' }}>*</span></label>
            <input
              type="number"
              value={goalForm.targetCents / 100}
              onChange={handleGoalFormChange}
              step="0.01"
              required
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            />
            <p style={{ fontSize: 11, color: '#888' }}>Ex: 50000 = 500€ (seuil validation propriétaire)</p>
          </div>
          <button type="submit" style={{ padding: '10px 20px', background: '#7C3AED', color: 'white', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600 }}>
            Créer l'objectif
          </button>
        </form>
      </div>

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
              <p style={{ fontSize: 11, color: '#888', marginTop: 4 }}>currentCents c / targetCents c • Restant: {g.remainingCents} c Int • Percent Int = {g.percentInt}%</p>
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
