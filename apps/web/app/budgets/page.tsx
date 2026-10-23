'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { getLocalBudgets, getLocalTransactions, type LocalBudget, type LocalTransaction } from '@tena/core/sync/dexie';
import { getBudgetVsSpent } from '@tena/core/analytics/stats';
import { getLocalFamilyIds } from '@/lib/localFamilyIds';

function formatCents(amountCents: number): string {
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(amountCents / 100);
}

export default function BudgetsPage() {
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
  const [budgets, setBudgets] = useState<LocalBudget[]>([]);
  const [transactions, setTransactions] = useState<LocalTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    getLocalFamilyIds().then((ids) => {
      if (!active) return;
      setFamilyIds(ids);
      if (ids.length === 1) setFamilyId(ids[0]);
      setLoading(false);
    }).catch((cause: unknown) => {
      if (active) { setError(cause instanceof Error ? cause.message : 'Impossible de lire les espaces locaux.'); setLoading(false); }
    });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    let active = true;
    if (!familyId) { setBudgets([]); return () => { active = false; }; }
    setLoading(true);
    Promise.all([getLocalBudgets(familyId), getLocalTransactions(familyId)]).then(([rows, txs]) => {
      if (active) { setBudgets(rows); setTransactions(txs); }
    }).catch((cause: unknown) => {
      if (active) setError(cause instanceof Error ? cause.message : 'Impossible de lire les budgets locaux.');
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [familyId]);

  const usage = familyId ? getBudgetVsSpent(
    budgets.map((budget) => ({ ...budget, type: budget.month ? 'monthly' as const : 'annual' as const, createdAt: budget.updatedAt })),
    transactions.map((transaction) => ({
      ...transaction,
      source: transaction.source ?? 'manual' as const,
      createdAt: transaction.createdAt ?? transaction.bookingDate,
      createdByUserId: transaction.createdByUserId ?? 'local-owner',
    })),
    { familyId },
  ) : [];
  const usageById = new Map(usage.map((item) => [item.budgetId, item]));

  return (
    <main style={{ maxWidth: 1120, margin: '0 auto', padding: '32px 20px', color: '#f5f5f7' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div><h1 style={{ margin: 0 }}>Budgets</h1><p style={{ color: '#a0a0ab' }}>Budgets enregistrés localement sur cet appareil.</p></div>
        <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
      </header>
      {familyIds.length > 1 ? (
        <label style={{ display: 'grid', gap: 6, maxWidth: 420, margin: '20px 0' }}>Espace local
          <select value={familyId} onChange={(event) => setFamilyId(event.target.value)}>
            <option value="">Choisir un espace…</option>{familyIds.map((id) => <option key={id} value={id}>{id}</option>)}
          </select>
        </label>
      ) : null}
      {loading ? <p role="status">Chargement des budgets…</p> : null}
      {error ? <p role="alert" style={{ color: '#fca5a5' }}>{error}</p> : null}
      {!loading && !error && familyIds.length === 0 ? <p>Aucun budget enregistré sur cet appareil.</p> : null}
      {!loading && familyId && budgets.length === 0 ? <p>Aucun budget dans cet espace local.</p> : null}
      {budgets.length > 0 ? (
        <div style={{ overflowX: 'auto', border: '1px solid #2a2a30', borderRadius: 12 }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead><tr><th scope="col">Période</th><th scope="col">Catégorie</th><th scope="col">Personne</th><th scope="col">Montant prévu</th><th scope="col">Dépensé</th><th scope="col">Restant</th></tr></thead>
            <tbody>{budgets.map((budget) => (
              (() => { const current = usageById.get(budget.id); return (
              <tr key={budget.id} style={{ borderTop: '1px solid #2a2a30' }}>
                <td style={{ padding: 10 }}>{budget.month ? `${budget.year}-${String(budget.month).padStart(2, '0')}` : `Année ${budget.year}`}</td>
                <td style={{ padding: 10 }}>{budget.categoryId ?? 'Toutes catégories'}</td>
                <td style={{ padding: 10 }}>{budget.personId ?? 'Espace local'}</td>
                <td style={{ padding: 10 }}>{formatCents(budget.amountCents)}</td>
                <td style={{ padding: 10 }}>{formatCents(current?.spentCents ?? 0)}</td>
                <td style={{ padding: 10 }}>{formatCents(current?.remainingCents ?? budget.amountCents)}</td>
              </tr>
              ); })()
            ))}</tbody>
          </table>
        </div>
      ) : null}
    </main>
  );
}
