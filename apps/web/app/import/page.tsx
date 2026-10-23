'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { getLocalTransactions, getLocalDeletedTransactions, importLocalTransactionsBatch, type LocalTransaction } from '@tena/core/sync/dexie';
import { prepareImportRows, suggestImportMapping, type AnalyzedSheet, type ImportColumnMapping, type PreparedImportRow } from '@tena/import-engine';
import { analyzeLocalImportFile, formatLocalImportError } from '../../lib/localImport';
import { getLocalFamilyIds } from '../../lib/localFamilyIds';

const panel: React.CSSProperties = { border: '1px solid #30303a', borderRadius: 16, padding: 20, background: '#17171d', marginTop: 18 };
const field: React.CSSProperties = { background: '#22222b', color: '#f5f5f7', border: '1px solid #444451', borderRadius: 8, padding: '9px 12px' };

export default function ImportPage() {
  const [families, setFamilies] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
  const [sheets, setSheets] = useState<AnalyzedSheet[]>([]);
  const [sheetIndex, setSheetIndex] = useState(0);
  const [mapping, setMapping] = useState<ImportColumnMapping>({ date: '', amount: '', label: '' });
  const [existing, setExisting] = useState<LocalTransaction[]>([]);
  const [rows, setRows] = useState<PreparedImportRow[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [fileName, setFileName] = useState('');

  useEffect(() => { getLocalFamilyIds().then(ids => { setFamilies(ids); setFamilyId(ids[0] ?? ''); }).catch(() => setMessage('Impossible de lire les espaces locaux.')); }, []);
  useEffect(() => {
    if (!familyId) { setExisting([]); return; }
    Promise.all([getLocalTransactions(familyId), getLocalDeletedTransactions(familyId)]).then(([active, deleted]) => setExisting([...active, ...deleted])).catch(() => setMessage('Déverrouille le coffre local avant d’importer.'));
  }, [familyId]);

  const sheet = sheets[sheetIndex];
  const analysis = useMemo(() => {
    if (!sheet) return { rows: [], blankCount: 0 };
    try { return prepareImportRows(sheet, mapping, existing); }
    catch { return { rows: [], blankCount: 0 }; }
  }, [sheet, mapping, existing]);
  const mappingError = sheet ? (() => { try { prepareImportRows({ ...sheet, rows: [] }, mapping, existing); return ''; } catch (error) { return formatLocalImportError(error); } })() : '';
  const selectedCount = analysis.rows.filter(row => !row.error && (rows.find(item => item.sourceRow === row.sourceRow)?.selected ?? row.selected)).length;
  const validRows = analysis.rows.filter(row => !row.error);

  async function chooseFile(file?: File) {
    if (!file) return;
    setBusy(true); setMessage(''); setSheets([]); setRows([]); setFileName(file.name);
    try {
      const parsed = await analyzeLocalImportFile(file);
      setSheets(parsed); setSheetIndex(0); setMapping(suggestImportMapping(parsed[0]?.headers ?? []));
      setMessage(`${parsed.reduce((sum, item) => sum + item.rows.length, 0)} ligne(s) analysée(s) sur cet appareil.`);
    } catch (error) { setMessage(formatLocalImportError(error)); }
    finally { setBusy(false); }
  }

  function toggleRow(row: PreparedImportRow, checked: boolean) {
    setRows(current => {
      const currentValue = current.length ? current : analysis.rows;
      return currentValue.map(item => item.sourceRow === row.sourceRow ? { ...item, selected: checked } : item);
    });
  }

  async function importSelected() {
    const selected = analysis.rows.filter(row => !row.error && (rows.find(item => item.sourceRow === row.sourceRow)?.selected ?? row.selected));
    if (!selected.length || !familyId) return;
    if (!window.confirm(`Ajouter ${selected.length} transaction(s) à cet espace local ? Les données existantes ne seront pas remplacées.`)) return;
    setBusy(true); setMessage('');
    try {
      const imported = await importLocalTransactionsBatch(selected.map(row => ({
        familyId, label: row.label, bookingDate: row.bookingDate!, amountCents: row.amountCents!, categoryId: row.category,
      })));
      setMessage(`${imported.length} transaction(s) ajoutée(s) localement. Aucun fichier n’a été envoyé.`);
      setRows([]);
      const [active, deleted] = await Promise.all([getLocalTransactions(familyId), getLocalDeletedTransactions(familyId)]);
      setExisting([...active, ...deleted]);
    } catch (error) { setMessage(`Import annulé : ${formatLocalImportError(error)} Aucune ligne n’a été remplacée.`); }
    finally { setBusy(false); }
  }

  const selectMapping = (key: keyof ImportColumnMapping, value: string) => setMapping(current => ({ ...current, [key]: value || undefined }));
  const chooser = (key: keyof ImportColumnMapping, title: string, required = false) => <label style={{ display: 'grid', gap: 7, color: '#c7c7d0' }}>{title}{required ? ' *' : ' (facultatif)'}<select style={field} value={mapping[key] ?? ''} onChange={event => selectMapping(key, event.target.value)}><option value=''>— choisir —</option>{sheet?.headers.map(header => <option key={header} value={header}>{header}</option>)}</select></label>;

  return <main style={{ maxWidth: 1040, margin: '0 auto', padding: '40px 20px', color: '#f5f5f7' }}>
    <p style={{ color: '#e8cc6a', fontSize: 12, letterSpacing: '.12em' }}>IMPORT LOCAL · PRIVÉ</p>
    <h1>Importer des transactions</h1>
    <p style={{ color: '#a0a0ab', lineHeight: 1.7 }}>Le fichier est lu dans ton navigateur et reste sur cet appareil. Les formats CSV et XLSX sont acceptés, sans connexion à un serveur d’import.</p>
    <section style={panel}>
      <h2 style={{ marginTop: 0 }}>1. Choisir un fichier</h2>
      <input type="file" accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" disabled={busy} onChange={event => chooseFile(event.target.files?.[0])} />
      {fileName && <p style={{ color: '#aaa' }}>{fileName}</p>}
      {families.length > 1 && <label style={{ display: 'grid', gap: 8, marginTop: 16 }}>Espace local<select style={field} value={familyId} onChange={event => setFamilyId(event.target.value)}>{families.map(id => <option key={id} value={id}>{id}</option>)}</select></label>}
      {!families.length && <p style={{ color: '#e8cc6a' }}>Crée d’abord une transaction ou un budget local pour établir un espace de destination.</p>}
    </section>
    {sheet && <>
      {sheets.length > 1 && <section style={panel}><label>Feuille <select style={field} value={sheetIndex} onChange={event => { const index = Number(event.target.value); setSheetIndex(index); setMapping(suggestImportMapping(sheets[index].headers)); setRows([]); }} >{sheets.map((item, index) => <option key={`${item.fileId}-${item.sheetName}`} value={index}>{item.sheetName}</option>)}</select></label></section>}
      <section style={panel}>
        <h2 style={{ marginTop: 0 }}>2. Associer les colonnes</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 14 }}>{chooser('date', 'Date', true)}{chooser('amount', 'Montant', true)}{chooser('label', 'Libellé', true)}{chooser('category', 'Catégorie')}</div>
        {mappingError && <p role="alert" style={{ color: '#ffb18e' }}>Association incomplète : {mappingError}</p>}
      </section>
      {!mappingError && <section style={panel}>
        <h2 style={{ marginTop: 0 }}>3. Vérifier avant import</h2>
        <p style={{ color: '#aaa' }}>{validRows.length} ligne(s) exploitable(s), {analysis.rows.filter(row => row.error).length} erreur(s), {analysis.rows.filter(row => row.duplicate).length} doublon(s), {analysis.blankCount} ligne(s) vide(s). Les doublons sont décochés par défaut.</p>
        <div style={{ overflowX: 'auto' }}><table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 700 }}><thead><tr>{['Importer','Ligne','Date','Libellé','Montant','Catégorie','État'].map(label => <th key={label} style={{ textAlign: 'left', padding: 9, borderBottom: '1px solid #444' }}>{label}</th>)}</tr></thead><tbody>
          {analysis.rows.slice(0, 200).map(row => { const current = rows.find(item => item.sourceRow === row.sourceRow) ?? row; return <tr key={row.sourceRow}>
            <td style={{ padding: 9 }}><input aria-label={`Importer ligne ${row.sourceRow}`} type="checkbox" disabled={Boolean(row.error)} checked={current.selected} onChange={event => toggleRow(row, event.target.checked)} /></td>
            <td style={{ padding: 9 }}>{row.sourceRow}</td><td style={{ padding: 9 }}>{row.bookingDate?.toLocaleDateString('fr-FR') ?? '—'}</td><td style={{ padding: 9 }}>{row.label || '—'}</td><td style={{ padding: 9 }}>{row.amountCents === undefined ? '—' : (row.amountCents / 100).toLocaleString('fr-FR', { style: 'currency', currency: 'EUR' })}</td><td style={{ padding: 9 }}>{row.category || '—'}</td><td style={{ padding: 9, color: row.error ? '#ffb18e' : row.duplicate ? '#e8cc6a' : '#9ad6a0' }}>{row.error ?? (row.duplicate === 'existing' ? 'Déjà présent' : row.duplicate === 'file' ? 'Doublon dans le fichier' : 'Prêt')}</td>
          </tr>; })}
        </tbody></table></div>
        {analysis.rows.length > 200 && <p>Les 200 premières lignes sont affichées ; toutes les lignes valides sélectionnées seront importées.</p>}
        <button type="button" disabled={busy || !familyId || selectedCount === 0} onClick={importSelected} style={{ ...field, marginTop: 16, background: '#e8cc6a', color: '#17171d', fontWeight: 700, cursor: 'pointer' }}>{busy ? 'Traitement…' : `Ajouter ${selectedCount} transaction(s)`}</button>
      </section>}
    </>}
    {message && <p role="status" style={{ ...panel, color: '#d6d6dd' }}>{message}</p>}
    <p style={{ marginTop: 24 }}><Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link></p>
  </main>;
}
