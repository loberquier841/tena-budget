'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { calculateProgress } from '@tena/core/budget/savings';
import { getLocalSavingGoals, type LocalSavingGoal } from '@tena/core/sync/dexie';
import { getLocalFamilyIds } from '@/lib/localFamilyIds';

function formatCents(amountCents: number): string {
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(amountCents / 100);
}

export default function ObjectifsPage() {
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
  const [goals, setGoals] = useState<LocalSavingGoal[]>([]);
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
    if (!familyId) { setGoals([]); return () => { active = false; }; }
    setLoading(true);
    getLocalSavingGoals(familyId).then((rows) => {
      if (active) setGoals(rows);
    }).catch((cause: unknown) => {
      if (active) setError(cause instanceof Error ? cause.message : 'Impossible de lire les objectifs locaux.');
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [familyId]);

  return (
    <main style={{ maxWidth: 900, margin: '0 auto', padding: '32px 20px', color: '#f5f5f7' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div><h1 style={{ margin: 0 }}>Objectifs d’épargne</h1><p style={{ color: '#a0a0ab' }}>Progression calculée depuis les objectifs locaux.</p></div>
        <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
      </header>
      {familyIds.length > 1 ? (
        <label style={{ display: 'grid', gap: 6, maxWidth: 420, margin: '20px 0' }}>Espace local
          <select value={familyId} onChange={(event) => setFamilyId(event.target.value)}>
            <option value="">Choisir un espace…</option>{familyIds.map((id) => <option key={id} value={id}>{id}</option>)}
          </select>
        </label>
      ) : null}
      {loading ? <p role="status">Chargement des objectifs…</p> : null}
      {error ? <p role="alert" style={{ color: '#fca5a5' }}>{error}</p> : null}
      {!loading && !error && familyIds.length === 0 ? <p>Aucun objectif enregistré sur cet appareil.</p> : null}
      {!loading && familyId && goals.length === 0 ? <p>Aucun objectif dans cet espace local.</p> : null}
      <section aria-label="Objectifs enregistrés" style={{ display: 'grid', gap: 12, marginTop: 20 }}>
        {goals.map((goal) => {
          const progress = calculateProgress(goal);
          return (
            <article key={goal.id} style={{ padding: 18, border: '1px solid #2a2a30', borderRadius: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
                <h2 style={{ margin: 0, fontSize: 17 }}>{goal.name}</h2><span>{progress.percentInt}%</span>
              </div>
              <p style={{ color: '#a0a0ab' }}>{formatCents(progress.currentCents)} sur {formatCents(progress.targetCents)} · reste {formatCents(progress.remainingCents)}</p>
              <progress max={100} value={Math.max(0, Math.min(100, progress.percentInt))} aria-label={`Progression de ${goal.name}`} />
            </article>
          );
        })}
      </section>
    </main>
  );
}
