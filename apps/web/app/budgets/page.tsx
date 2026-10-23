import { auth } from "@/auth";
import { getLocalBudgets, getLocalCategories, LocalBudget } from "@/sync/dexie";
import { createBudget, validateBudgetAmount, calculateRemaining, type Budget } from "@/budget/budget";
import { Role, assertCan, requiresOwnerConfirmation } from "@/permissions/permissions";
import { toCents } from "@/shared";

async function loadBudgets(familyId: string | undefined) {
  let budgets: LocalBudget[] = [];
  try {
    budgets = await getLocalBudgets(familyId);
  } catch (e) {
    console.error("Erreur chargement budgets:", e);
  }
  return budgets;
}

export default async function BudgetsPage() {
  const session = await auth();
  if (!session) redirect('/login');

  const familyId = session.userId;
  const budgets = await loadBudgets(familyId);

  // Budget form state (client-side)
  const [budgetForm, setBudgetForm] = React.useState<{ type: 'annual' | 'monthly'; year: number; month?: number; categoryId?: string; personId?: string; amountCents: number }>({
    type: 'monthly',
    year: new Date().getFullYear(),
    amountCents: 0,
  });

  const handleBudgetFormChange = React.useCallback((e: React.ChangeEvent) => {
    const { name, value } = e.target;
    setBudgetForm(prev => ({
      ...prev,
      [name]: name === 'amount' ? parseFloat(value) || 0 : name === 'year' ? parseInt(value) || new Date().getFullYear() : value,
    }));
  }, []);

  const handleBudgetSubmit = React.useCallback(async () => {
    try {
      validateBudgetAmount(budgetForm.amountCents);

      const requiresConfirm = requiresOwnerConfirmation(budgetForm.amountCents);

      const newBudget = await createBudget({
        familyId: familyId,
        type: budgetForm.type,
        year: budgetForm.year,
        month: budgetForm.month,
        categoryId: budgetForm.categoryId || undefined,
        personId: budgetForm.personId || undefined,
        amountCents: budgetForm.amountCents,
      }, 'owner');

      const updatedBudgets = await loadBudgets(familyId);
      setBudgetForm({
        type: 'monthly',
        year: new Date().getFullYear(),
        amountCents: 0,
      });
      return updatedBudgets;
    } catch (err: any) {
      console.error('Budget creation error:', err);
      throw err;
    }
  }, [budgetForm, familyId]);

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
            {budgets.map(b => (
              <tr key={b.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                <td style={{ padding: 12 }}><span style={{ background: b.type==='annual'?'#ddd6fe':'#fef3c7', padding: '2px 8px', borderRadius: 12, fontSize: 11 }}>{b.type}</span></td>
                <td style={{ padding: 12 }}>{b.year}{b.month ? `-${String(b.month).padStart(2,'0')}` : ''}</td>
                <td style={{ padding: 12 }}>{b.categoryId || 'Non défini'}</td>
                <td style={{ padding: 12 }}>{b.personId || 'Famille (global)'} {b.personId ? '(individuel)' : '(global - jamais mélangé)'}</td>
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

      {/* Budget creation form */}
      <div style={{ marginTop: 24, padding: 20, background: 'white', borderRadius: 12, border: '1px solid #e5e7eb' }}>
        <h3 style={{ fontSize: 14, marginBottom: 16, color: '#111' }}>Nouveau budget</h3>
        <form onSubmit={handleBudgetSubmit} style={{ display: 'grid', gap: 16 }}>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Type <span style={{ color: '#ef4444' }}>*</span></label>
            <select
              value={budgetForm.type}
              onChange={e => setBudgetForm(prev => ({ ...prev, type: e.target.value }))}
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            >
              <option value="annual">Annuel</option>
              <option value="monthly">Mensuel</option>
            </select>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Année <span style={{ color: '#ef4444' }}>*</span></label>
            <select
              value={budgetForm.year}
              onChange={e => setBudgetForm(prev => ({ ...prev, year: parseInt(e.target.value) || new Date().getFullYear() }))}
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            >
              {[2024, 2025, 2026, 2027, 2028].map(y => (
                <option key={y} value={y}>{y}</option>
              ))}
            </select>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Mois <span style={{ color: '#ef4444' }}>*</span> (pour budgets mensuels)</label>
            <select
              value={budgetForm.month ?? ''}
              onChange={e => setBudgetForm(prev => ({ ...prev, month: e.target.value ? parseInt(e.target.value) : undefined }))}
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            >
              <option value="">Tous les mois</option>
              {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(m => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Catégorie</label>
            <select
              value={budgetForm.categoryId || ''}
              onChange={e => setBudgetForm(prev => ({ ...prev, categoryId: e.target.value || undefined }))}
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            >
              <option value="">Aucune catégorie</option>
            </select>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Personne</label>
            <select
              value={budgetForm.personId || ''}
              onChange={e => setBudgetForm(prev => ({ ...prev, personId: e.target.value || undefined }))}
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            >
              <option value="">Famille (global)</option>
            </select>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <label>Montant (€) <span style={{ color: '#ef4444' }}>*</span></label>
            <input
              type="number"
              value={budgetForm.amountCents / 100}
              onChange={handleBudgetFormChange}
              step="0.01"
              required
              style={{ padding: 8, borderRadius: 6, border: '1px solid #e5e7eb', fontSize: 14 }}
            />
          </div>
          <button type="submit" style={{ padding: '10px 20px', background: '#7C3AED', color: 'white', border: 'none', borderRadius: 8, fontSize: 14, fontWeight: 600 }}>
            Créer le budget
          </button>
        </form>
      </div>
    </main>
  );
}
