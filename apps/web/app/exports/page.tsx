'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { exportLocalBudgetsCsv, exportLocalTransactionsCsv } from '@/lib/csvExport';
import { getLocalFamilyIds } from '@/lib/localFamilyIds';

type ExportKind = 'transactions' | 'budgets';

function downloadCsv(contents: string, filename: string) {
  const url = URL.createObjectURL(new Blob([contents], { type: 'text/csv;charset=utf-8' }));
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export default function ExportsPage() {
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
  const [busy, setBusy] = useState<ExportKind | ''>('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');

  useEffect(() => {
    let active = true;
    getLocalFamilyIds().then((ids) => {
      if (!active) return;
      setFamilyIds(ids);
      if (ids.length === 1) setFamilyId(ids[0]);
    }).catch(() => {
      if (active) setError('Impossible de lire les données locales. Déverrouille le coffre puis réessaie.');
    });
    return () => { active = false; };
  }, []);

  async function handleExport(kind: ExportKind) {
    if (!familyId) return;
    setBusy(kind);
    setError('');
    setStatus('');
    try {
      const contents = kind === 'transactions'
        ? await exportLocalTransactionsCsv(familyId)
        : await exportLocalBudgetsCsv(familyId);
      const prefix = kind === 'transactions' ? 'transactions' : 'budgets';
      downloadCsv(contents, `tena-${prefix}-${new Date().toISOString().slice(0, 10)}.csv`);
      setStatus(`Export ${prefix} téléchargé depuis le stockage local.`);
    } catch {
      setError('L’export n’a pas pu être créé. Vérifie que le coffre local est déverrouillé puis réessaie.');
    } finally {
      setBusy('');
    }
  }

  return (
    <main style={{ maxWidth: 900, margin: '0 auto', padding: '32px 20px', color: '#f5f5f7' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div><h1 style={{ margin: 0 }}>Exporter mes données</h1><p style={{ color: '#a0a0ab' }}>Les fichiers sont générés depuis les données locales de cet appareil.</p></div>
        <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
      </header>

      {familyIds.length > 1 ? <label style={{ display: 'grid', gap: 6, maxWidth: 420, margin: '24px 0' }}>Espace local
        <select value={familyId} onChange={(event) => setFamilyId(event.target.value)}>
          <option value="">Choisir un espace…</option>{familyIds.map((id) => <option key={id} value={id}>{id}</option>)}
        </select>
      </label> : null}
      {familyIds.length === 0 && !error ? <p>Aucune donnée locale exportable trouvée.</p> : null}

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: 14, marginTop: 22 }}>
        <article style={{ border: '1px solid #34343c', borderRadius: 12, padding: 18 }}>
          <h2>Transactions en CSV</h2><p>Transactions non supprimées, avec date, libellé, source, identifiants de catégorie/personne et montants en centimes et en euros.</p>
          <button type="button" disabled={!familyId || Boolean(busy)} onClick={() => void handleExport('transactions')}>{busy === 'transactions' ? 'Préparation…' : 'Télécharger les transactions'}</button>
        </article>
        <article style={{ border: '1px solid #34343c', borderRadius: 12, padding: 18 }}>
          <h2>Budgets en CSV</h2><p>Budgets enregistrés, avec période, identifiants de catégorie/personne et montants en centimes et en euros.</p>
          <button type="button" disabled={!familyId || Boolean(busy)} onClick={() => void handleExport('budgets')}>{busy === 'budgets' ? 'Préparation…' : 'Télécharger les budgets'}</button>
        </article>
      </section>
      {error ? <p role="alert" style={{ color: '#fca5a5' }}>{error}</p> : null}
      {status ? <p role="status" style={{ color: '#86efac' }}>{status}</p> : null}
      <p style={{ marginTop: 22, color: '#aaaab4' }}>Les exports Excel et PDF ne sont pas disponibles dans cette version. Les données ne sont pas envoyées à un service externe.</p>
    </main>
  );
}
