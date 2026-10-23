'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { createEncryptedLocalBackup, prepareLocalBackupRestore, restorePreparedLocalBackup, type PreparedLocalRestore } from '@/lib/localBackup';
import { getLocalFamilyIds } from '@/lib/localFamilyIds';

type BackupCounts = { transactions: number; deletedTransactions: number; budgets: number; goals: number; contributions: number; profile: number };

export default function SauvegardesPage() {
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [counts, setCounts] = useState<BackupCounts | null>(null);
  const [restoreFile, setRestoreFile] = useState<File | null>(null);
  const [restorePassword, setRestorePassword] = useState('');
  const [preparedRestore, setPreparedRestore] = useState<PreparedLocalRestore | null>(null);
  const [restoreBusy, setRestoreBusy] = useState(false);

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

  async function handleCreate(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!familyId) { setError('Choisis un espace local.'); return; }
    if (password.length < 8) { setError('Le mot de passe doit contenir au moins 8 caractères.'); return; }
    setBusy(true);
    setError('');
    setStatus('');
    setCounts(null);
    try {
      const result = await createEncryptedLocalBackup(familyId, password);
      const file = new Blob([JSON.stringify(result.encrypted)], { type: 'application/json' });
      const url = URL.createObjectURL(file);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = `tena-budget-${new Date().toISOString().slice(0, 10)}.tenla.enc`;
      anchor.click();
      URL.revokeObjectURL(url);
      setCounts(result.counts);
      setStatus('Sauvegarde chiffrée téléchargée. Conserve son mot de passe séparément : il ne peut pas être récupéré par TENΛ.');
      setPassword('');
    } catch (cause) {
      setError(cause instanceof Error && cause.message === 'LOCAL_VAULT_LOCKED'
        ? 'Le coffre local est verrouillé. Déverrouille-le puis réessaie.'
        : 'La sauvegarde n’a pas pu être créée. Vérifie que le coffre local est déverrouillé et réessaie.');
    } finally {
      setBusy(false);
    }
  }

  async function handleInspectRestore(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!restoreFile) { setError('Choisis un fichier de sauvegarde.'); return; }
    if (restoreFile.size > 50 * 1024 * 1024) { setError('Le fichier dépasse la limite de 50 Mo.'); return; }
    setBusy(true);
    setError('');
    setStatus('');
    setPreparedRestore(null);
    try {
      const payload: unknown = JSON.parse(await restoreFile.text());
      const prepared = await prepareLocalBackupRestore(payload, restorePassword);
      setPreparedRestore(prepared);
      setStatus(prepared.conflicts.length
        ? 'Le fichier est lisible, mais des éléments existent déjà. Aucune donnée n’a été modifiée.'
        : 'Fichier déchiffré et contrôlé. Vérifie le contenu avant de lancer la restauration.');
    } catch (cause) {
      const reason = cause instanceof Error ? cause.message : '';
      setError(reason.startsWith('BACKUP_CONTENT_UNSUPPORTED')
        ? 'Ce fichier contient des catégories, des personnes ou des règles récurrentes que cette version ne sait pas encore restaurer. Rien n’a été écrit.'
        : reason.startsWith('BACKUP_VERSION_UNSUPPORTED')
          ? 'Cette version de sauvegarde n’est pas compatible avec cette application. Rien n’a été écrit.'
        : reason === 'LOCAL_VAULT_LOCKED'
          ? 'Le coffre local est verrouillé. Déverrouille-le puis réessaie.'
          : 'Impossible de vérifier ce fichier. Vérifie le fichier et son mot de passe. Aucune donnée n’a été modifiée.');
    } finally {
      setBusy(false);
    }
  }

  async function handleRestore() {
    if (!preparedRestore || preparedRestore.conflicts.length) return;
    if (preparedRestore.profileDisposition === 'replace_onboarding_progress' &&
        !window.confirm('Cette sauvegarde remplacera la progression inachevée du questionnaire sur cet appareil. Les autres données seront ajoutées, sans remplacer les données financières existantes. Continuer ?')) {
      setStatus('Restauration annulée. Aucune donnée n’a été modifiée.');
      return;
    }
    setRestoreBusy(true);
    setError('');
    try {
      const restored = await restorePreparedLocalBackup(preparedRestore);
      setCounts(restored);
      setPreparedRestore(null);
      setRestorePassword('');
      setRestoreFile(null);
      setStatus('Restauration terminée. Les données ont été ajoutées localement et chiffrées dans le coffre.');
    } catch (cause) {
      const reason = cause instanceof Error ? cause.message : '';
      setError(reason.startsWith('RESTORE_CONFLICT:')
        ? 'Des données ont changé depuis l’aperçu. La restauration a été annulée sans écrasement; vérifie à nouveau le fichier.'
        : 'La restauration a échoué et les écritures locales ont été annulées. Vérifie que le coffre est déverrouillé puis réessaie.');
    } finally {
      setRestoreBusy(false);
    }
  }

  return (
    <main style={{ maxWidth: 850, margin: '0 auto', padding: '32px 20px', color: '#f5f5f7' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <div><h1 style={{ margin: 0 }}>Sauvegarde locale chiffrée</h1><p style={{ color: '#a0a0ab' }}>Le fichier est créé sur cet appareil, sans envoi à un serveur.</p></div>
        <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
      </header>

      <section style={{ marginTop: 24, padding: 20, border: '1px solid #33333a', borderRadius: 14 }}>
        <h2>Créer un fichier de sauvegarde</h2>
        {familyIds.length === 0 ? <p>Aucun espace avec des données locales n’a été trouvé. Ajoute des données puis reviens ici.</p> : (
          <form onSubmit={handleCreate} style={{ display: 'grid', gap: 14, maxWidth: 480 }}>
            {familyIds.length > 1 ? <label style={{ display: 'grid', gap: 6 }}>Espace local
              <select value={familyId} onChange={(event) => setFamilyId(event.target.value)} required>
                <option value="">Choisir un espace…</option>{familyIds.map((id) => <option key={id} value={id}>{id}</option>)}
              </select>
            </label> : <p>Espace sélectionné : {familyId}</p>}
            <label style={{ display: 'grid', gap: 6 }}>Mot de passe de la sauvegarde
              <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} minLength={8} autoComplete="new-password" required />
            </label>
            <button type="submit" disabled={busy || !familyId}>{busy ? 'Création…' : 'Chiffrer et télécharger'}</button>
          </form>
        )}
        {error ? <p role="alert" style={{ color: '#fca5a5' }}>{error}</p> : null}
        {status ? <p role="status" style={{ color: '#86efac' }}>{status}</p> : null}
        {counts ? <p>Contenu : {counts.transactions} transactions (dont {counts.deletedTransactions} dans la corbeille), {counts.budgets} budgets, {counts.goals} objectifs, {counts.contributions} versements{counts.profile ? ' et le profil ou la progression du questionnaire' : ''}.</p> : null}
      </section>

      <section style={{ marginTop: 18, padding: 20, border: '1px solid #33333a', borderRadius: 14, color: '#c5c5cc' }}>
        <h2>À savoir</h2>
        <p>Le contenu de la sauvegarde est chiffré avec AES-GCM avant le téléchargement. Le mot de passe n’est pas envoyé ni conservé par TENΛ. Si tu le perds, le fichier ne pourra pas être déchiffré.</p>
        <p>La sauvegarde inclut les transactions actives et dans la corbeille, les budgets, objectifs actifs ou supprimés, leurs versements et le profil terminé ou la progression du questionnaire présent sur cet appareil. Les identifiants de catégorie ou de personne portés par les transactions et budgets sont inclus avec ces lignes.</p>
        <p>Les catégories et personnes n’ont pas de table de données dans cette version; la page des règles récurrentes affiche seulement des exemples. Si un ancien fichier contient des catégories, personnes ou règles récurrentes enregistrées, la restauration le refusera avant toute écriture. Les éléments absents d’une ancienne sauvegarde ne peuvent pas être reconstruits.</p>
        <p>Le coffre, sa phrase secrète, les clés, la file de synchronisation temporaire et les journaux de conflits ne sont pas exportés. La sauvegarde est restaurable dans un nouveau coffre avec son propre mot de passe. Une phrase secrète oubliée ne peut pas être récupérée; sans fichier et mot de passe de sauvegarde valides, les données chiffrées restent illisibles.</p>
      </section>

      <section style={{ marginTop: 18, padding: 20, border: '1px solid #33333a', borderRadius: 14 }}>
        <h2>Restaurer depuis un fichier</h2>
        <p>La restauration ajoute les données financières sans remplacer celles qui existent. Les conflits et doublons bloquent l’opération. Un profil sauvegardé peut remplacer une progression de questionnaire inachevée, uniquement après confirmation.</p>
        <form onSubmit={handleInspectRestore} style={{ display: 'grid', gap: 14, maxWidth: 480 }}>
          <label style={{ display: 'grid', gap: 6 }}>Fichier TENΛ chiffré
            <input type="file" accept=".enc,.json,application/json" onChange={(event) => { setRestoreFile(event.target.files?.[0] ?? null); setPreparedRestore(null); }} required />
          </label>
          <label style={{ display: 'grid', gap: 6 }}>Mot de passe de la sauvegarde
            <input type="password" value={restorePassword} onChange={(event) => setRestorePassword(event.target.value)} autoComplete="current-password" required />
          </label>
          <button type="submit" disabled={busy || !restoreFile}>{busy ? 'Vérification…' : 'Déchiffrer et vérifier'}</button>
        </form>
        {preparedRestore ? <div style={{ marginTop: 16 }}>
          <p>Aperçu : {preparedRestore.counts.transactions} transactions (dont {preparedRestore.counts.deletedTransactions} dans la corbeille), {preparedRestore.counts.budgets} budgets, {preparedRestore.counts.goals} objectifs, {preparedRestore.counts.contributions} versements{preparedRestore.counts.profile ? ' et un profil ou questionnaire' : ''}.</p>
          <p>{preparedRestore.profileDisposition === 'replace_onboarding_progress'
            ? 'Profil questionnaire inclus : il remplacera la progression inachevée après confirmation.'
            : preparedRestore.profileDisposition === 'keep_local_profile'
              ? 'Profil questionnaire inclus : le profil déjà présent sur cet appareil sera conservé.'
              : preparedRestore.profileDisposition === 'add_backup_profile'
                ? 'Profil questionnaire inclus : il sera ajouté.'
                : 'Profil questionnaire : absent ou non modifié.'}</p>
          {preparedRestore.conflicts.length ? <ul role="alert" style={{ color: '#fca5a5' }}>{preparedRestore.conflicts.map((conflict) => <li key={conflict}>{conflict}</li>)}</ul> : (
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <button type="button" onClick={() => void handleRestore()} disabled={restoreBusy}>{restoreBusy ? 'Restauration…' : 'Ajouter ces données à mon stockage local'}</button>
              <button type="button" onClick={() => { setPreparedRestore(null); setStatus('Aperçu annulé. Aucune donnée n’a été modifiée.'); }} disabled={restoreBusy}>Annuler l’aperçu</button>
            </div>
          )}
        </div> : null}
      </section>
    </main>
  );
}
