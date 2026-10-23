'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { getLocalTransactions, type LocalTransaction } from '@tena/core/sync/dexie';
import { getMonthlyEvolution } from '@tena/core/analytics/stats';
import { getLocalFamilyIds } from '@/lib/localFamilyIds';

function formatCents(amountCents: number): string {
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(amountCents / 100);
}

export default function HistoriquePage() {
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
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
    if (!familyId) { setTransactions([]); return () => { active = false; }; }
    setLoading(true);
    getLocalTransactions(familyId).then((rows) => {
      if (active) setTransactions(rows);
    }).catch((cause: unknown) => {
      if (active) setError(cause instanceof Error ? cause.message : 'Impossible de lire les transactions locales.');
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [familyId]);

  const monthly = familyId ? getMonthlyEvolution(transactions.map((transaction) => ({
    ...transaction,
    source: transaction.source ?? 'manual' as const,
    createdAt: transaction.createdAt ?? transaction.updatedAt,
    createdByUserId: transaction.createdByUserId ?? 'local',
  })), { familyId }) : [];

  return (
    <main style={{ maxWidth: 900, margin: '0 auto', padding: '32px 20px', color: '#f5f5f7' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div><h1 style={{ margin: 0 }}>Historique</h1><p style={{ color: '#a0a0ab' }}>Dépenses mensuelles calculées depuis les transactions locales.</p></div>
        <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
      </header>
      {familyIds.length > 1 ? (
        <label style={{ display: 'grid', gap: 6, maxWidth: 420, margin: '20px 0' }}>Espace local
          <select value={familyId} onChange={(event) => setFamilyId(event.target.value)}>
            <option value="">Choisir un espace…</option>{familyIds.map((id) => <option key={id} value={id}>{id}</option>)}
          </select>
        </label>
      ) : null}
      {loading ? <p role="status">Chargement de l’historique…</p> : null}
      {error ? <p role="alert" style={{ color: '#fca5a5' }}>{error}</p> : null}
      {!loading && !error && familyIds.length === 0 ? <p>Aucune donnée locale à comparer.</p> : null}
      {!loading && familyId && monthly.length === 0 ? <p>Aucune dépense enregistrée pour cet espace.</p> : null}
      <div style={{ display: 'grid', gap: 8, marginTop: 20 }}>
        {monthly.map((entry) => (
          <article key={`${entry.year}-${entry.month}`} style={{ display: 'flex', justifyContent: 'space-between', padding: 14, border: '1px solid #2a2a30', borderRadius: 10 }}>
            <span>{new Date(entry.year, entry.month - 1, 1).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })}</span>
            <span>{formatCents(entry.totalCents)}</span>
          </article>
        ))}
      </div>
    </main>
  );
}
