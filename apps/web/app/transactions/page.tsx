'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { getLocalTransactions, type LocalTransaction } from '@tena/core/sync/dexie';
import { getLocalFamilyIds } from '../../lib/localFamilyIds';

type TransactionFilters = {
  categoryId: string;
  source: string;
  minCents: string;
  maxCents: string;
  label: string;
  from: string;
  to: string;
};

type SortField = 'bookingDate' | 'amountCents' | 'label';

const EMPTY_FILTERS: TransactionFilters = {
  categoryId: '',
  source: '',
  minCents: '',
  maxCents: '',
  label: '',
  from: '',
  to: '',
};

function localDateValue(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatCents(amountCents: number): string {
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(amountCents / 100);
}

export default function TransactionsPage() {
  const [familyIds, setFamilyIds] = useState<string[]>([]);
  const [familyId, setFamilyId] = useState('');
  const [transactions, setTransactions] = useState<LocalTransaction[]>([]);
  const [filters, setFilters] = useState<TransactionFilters>(EMPTY_FILTERS);
  const [sortField, setSortField] = useState<SortField>('bookingDate');
  const [sortAscending, setSortAscending] = useState(false);
  const [page, setPage] = useState(1);
  const [loadingFamilies, setLoadingFamilies] = useState(true);
  const [loadingTransactions, setLoadingTransactions] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const pageSize = 10;

  useEffect(() => {
    let active = true;

    async function loadLocalSpaces() {
      try {
        const choices = await getLocalFamilyIds();
        if (!active) return;
        setFamilyIds(choices);
        if (choices.length === 1) setFamilyId(choices[0]);
      } catch (cause) {
        if (active) setError(cause instanceof Error ? cause.message : 'Impossible de lire les espaces locaux.');
      } finally {
        if (active) setLoadingFamilies(false);
      }
    }

    void loadLocalSpaces();
    return () => { active = false; };
  }, []);

  useEffect(() => {
    let active = true;
    if (!familyId) {
      setTransactions([]);
      return () => { active = false; };
    }

    async function loadTransactions() {
      setLoadingTransactions(true);
      setError(null);
      try {
        const rows = await getLocalTransactions(familyId);
        if (active) setTransactions(rows);
      } catch (cause) {
        if (active) setError(cause instanceof Error ? cause.message : 'Impossible de lire les transactions locales.');
      } finally {
        if (active) setLoadingTransactions(false);
      }
    }

    void loadTransactions();
    return () => { active = false; };
  }, [familyId]);

  const filtered = useMemo(() => transactions.filter((transaction) => {
    if (filters.categoryId && transaction.categoryId !== filters.categoryId) return false;
    if (filters.source && (transaction.source ?? 'manual') !== filters.source) return false;
    if (filters.minCents && transaction.amountCents < Number(filters.minCents)) return false;
    if (filters.maxCents && transaction.amountCents > Number(filters.maxCents)) return false;
    if (filters.label && !transaction.label.toLocaleLowerCase('fr-FR').includes(filters.label.toLocaleLowerCase('fr-FR'))) return false;
    const date = localDateValue(transaction.bookingDate);
    if (filters.from && date < filters.from) return false;
    if (filters.to && date > filters.to) return false;
    return true;
  }), [transactions, filters]);

  const sorted = useMemo(() => [...filtered].sort((a, b) => {
    let result = 0;
    if (sortField === 'bookingDate') result = a.bookingDate.getTime() - b.bookingDate.getTime();
    else if (sortField === 'amountCents') result = a.amountCents - b.amountCents;
    else result = a.label.localeCompare(b.label, 'fr');
    return sortAscending ? result : -result;
  }), [filtered, sortAscending, sortField]);

  const pageCount = Math.max(1, Math.ceil(sorted.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const pageRows = sorted.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  const categories = [...new Set(transactions.map((transaction) => transaction.categoryId).filter((id): id is string => Boolean(id)))].sort();

  function updateFilter<K extends keyof TransactionFilters>(key: K, value: TransactionFilters[K]) {
    setFilters((current) => ({ ...current, [key]: value }));
    setPage(1);
  }

  return (
    <main style={{ maxWidth: 1120, margin: '0 auto', padding: '32px 20px', color: '#f5f5f7' }}>
      <header style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 28 }}>Transactions</h1>
          <p style={{ color: '#a0a0ab', marginBottom: 0 }}>Données lues depuis le stockage local de cet appareil.</p>
        </div>
        <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
      </header>

      {loadingFamilies ? <p role="status">Recherche des données locales…</p> : null}

      {!loadingFamilies && familyIds.length > 1 ? (
        <label style={{ display: 'grid', gap: 6, maxWidth: 440, margin: '24px 0' }}>
          <span>Choisir un espace local</span>
          <select value={familyId} onChange={(event) => { setFamilyId(event.target.value); setPage(1); }} style={{ padding: 10 }}>
            <option value="">Sélectionner…</option>
            {familyIds.map((id) => <option key={id} value={id}>{id}</option>)}
          </select>
        </label>
      ) : null}

      {error ? <p role="alert" style={{ color: '#fca5a5' }}>{error}</p> : null}

      {!loadingFamilies && familyIds.length === 0 && !error ? (
        <section style={{ marginTop: 28, padding: 24, border: '1px solid #2a2a30', borderRadius: 14 }}>
          <h2 style={{ marginTop: 0 }}>Aucune transaction locale</h2>
          <p style={{ color: '#a0a0ab' }}>Les transactions apparaîtront ici lorsqu’elles seront enregistrées sur cet appareil.</p>
          <Link href="/onboarding" style={{ color: '#e8cc6a' }}>Découvrir le questionnaire</Link>
        </section>
      ) : null}

      {familyId ? (
        <>
          <section aria-label="Filtres des transactions" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 180px), 1fr))', gap: 12, margin: '24px 0' }}>
            <label style={{ display: 'grid', gap: 5 }}>Recherche
              <input value={filters.label} onChange={(event) => updateFilter('label', event.target.value)} placeholder="Libellé" />
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Catégorie
              <select value={filters.categoryId} onChange={(event) => updateFilter('categoryId', event.target.value)}>
                <option value="">Toutes</option>
                {categories.map((id) => <option key={id} value={id}>{id}</option>)}
              </select>
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Source
              <select value={filters.source} onChange={(event) => updateFilter('source', event.target.value)}>
                <option value="">Toutes</option><option value="manual">Manuelle</option><option value="import">Import</option><option value="bank">Banque</option>
              </select>
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Montant minimum (centimes)
              <input type="number" min="0" step="1" value={filters.minCents} onChange={(event) => updateFilter('minCents', event.target.value)} />
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Montant maximum (centimes)
              <input type="number" min="0" step="1" value={filters.maxCents} onChange={(event) => updateFilter('maxCents', event.target.value)} />
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Du
              <input type="date" value={filters.from} onChange={(event) => updateFilter('from', event.target.value)} />
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Au
              <input type="date" value={filters.to} onChange={(event) => updateFilter('to', event.target.value)} />
            </label>
            <label style={{ display: 'grid', gap: 5 }}>Trier par
              <select value={sortField} onChange={(event) => { setSortField(event.target.value as SortField); setPage(1); }}>
                <option value="bookingDate">Date</option><option value="amountCents">Montant</option><option value="label">Libellé</option>
              </select>
            </label>
            <button type="button" onClick={() => { setFilters(EMPTY_FILTERS); setPage(1); }}>Effacer les filtres</button>
          </section>

          {loadingTransactions ? <p role="status">Chargement des transactions…</p> : null}
          {!loadingTransactions && !error && sorted.length === 0 ? <div><p>{transactions.length ? 'Aucune transaction ne correspond à ces filtres.' : 'Aucune transaction dans cet espace local.'}</p><Link href="/import" style={{ color: '#e8cc6a' }}>Importer un relevé CSV ou XLSX</Link></div> : null}

          {pageRows.length > 0 ? (
            <div style={{ overflowX: 'auto', border: '1px solid #2a2a30', borderRadius: 12 }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                <thead><tr><th scope="col">Date</th><th scope="col">Libellé</th><th scope="col">Catégorie</th><th scope="col">Montant</th><th scope="col">Source</th></tr></thead>
                <tbody>
                  {pageRows.map((transaction) => (
                    <tr key={transaction.id} style={{ borderTop: '1px solid #2a2a30' }}>
                      <td style={{ padding: 10 }}>{localDateValue(transaction.bookingDate)}</td>
                      <td style={{ padding: 10 }}>{transaction.label}</td>
                      <td style={{ padding: 10 }}>{transaction.categoryId ?? '—'}</td>
                      <td style={{ padding: 10 }}>{formatCents(transaction.amountCents)}</td>
                      <td style={{ padding: 10 }}>{transaction.source ?? 'manual'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <nav aria-label="Pagination des transactions" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: 12 }}>
                <span>{sorted.length} résultat{sorted.length > 1 ? 's' : ''} · page {currentPage} sur {pageCount}</span>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button type="button" disabled={currentPage <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>Précédent</button>
                  <button type="button" disabled={currentPage >= pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))}>Suivant</button>
                  <button type="button" onClick={() => setSortAscending((value) => !value)} aria-label={`Changer le sens du tri, actuellement ${sortAscending ? 'croissant' : 'décroissant'}`}>
                    Tri {sortAscending ? 'croissant' : 'décroissant'}
                  </button>
                </div>
              </nav>
            </div>
          ) : null}
        </>
      ) : null}
    </main>
  );
}
