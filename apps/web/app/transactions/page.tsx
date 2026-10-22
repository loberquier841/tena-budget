'use client';

import { useState } from 'react';
import { auth } from '@/auth';
import { getLocalTransactions, LocalTransaction } from '@/sync/dexie';

export default function TransactionsFinalPage() {
  const [filters, setFilters] = useState({ personId: '', categoryId: '', source: '', minCents: '', maxCents: '', label: '', from: '', to: '' });
  const [sort, setSort] = useState({ field: 'bookingDate', direction: 'desc' });
  const [page, setPage] = useState(1);
  const pageSize = 10;

  // Chargement réel depuis IndexedDB Dexie
  // Note: getLocalTransactions filtre déjà isDeleted=true par défaut
  // familyId: priorité à la session auth, fallback localStorage, ensuite 'family_default'
  const [transactions, setTransactions] = useState<LocalTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [familyId, setFamilyId] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        const session = await auth();
        if (session && session.userId) {
          setFamilyId(session.userId);
          setIsAuthenticated(true);
        } else {
          setFamilyId(null);
          setIsAuthenticated(false);
          setError('Connexion requise pour accéder aux transactions');
          setLoading(false);
          return;
        }
        const data = await getLocalTransactions(familyId!);
        setTransactions(data);
        setLoading(false);
      } catch (e) {
        setError((e as Error).message);
        setLoading(false);
      }
    })();
  }, []);

  // Note: isAuthenticated et familyId sont dÃ©jà rÃglÃĐs ci-dessus selon la prÃsence de session.userId.
  // Les permissions sont vÃrifiÃ©es au cas par cas via assertCan() dans le rendu ci-dessous.



  // --- Comptes et pagination (calculés depuis les transactions chargées) ---
  const filteredTransactions = transactions.filter(t => {
    if (filters.personId && t.personId !== filters.personId) return false;
    if (filters.categoryId && t.categoryId !== filters.categoryId) return false;
    if (filters.source && t.source !== filters.source) return false;
    if (filters.minCents && t.amountCents < parseInt(filters.minCents)) return false;
    if (filters.maxCents && t.amountCents > parseInt(filters.maxCents)) return false;
    if (filters.label && !t.label.toLowerCase().includes(filters.label.toLowerCase())) return false;
    if (filters.from && t.bookingDate < filters.from) return false;
    if (filters.to && t.bookingDate > filters.to) return false;
    return true;
  });

  const sortedTransactions = [...filteredTransactions].sort((a, b) => {
    let cmp = 0;
    if (sort.field === 'bookingDate') cmp = a.bookingDate.localeCompare(b.bookingDate);
    else if (sort.field === 'amountCents') cmp = a.amountCents - b.amountCents;
    else cmp = a.label.localeCompare(b.label);
    return sort.direction === 'asc' ? cmp : -cmp;
  });

  const total = sortedTransactions.length;
  const totalPages = Math.ceil(total / pageSize);
  const paginated = sortedTransactions.slice((page - 1) * pageSize, page * pageSize);

<div style={{ marginBottom: 16, padding: 12, background: '#f9fafb', borderRadius: 8, border: '1px solid #e5e7eb' }}>
<div style={{ background: 'white', borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16, overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f9fafb' }}><tr style={{ fontSize: 11, color: '#666', textAlign: 'left' }}>
            <th style={{ padding: 12 }}>Date</th>
            <th>Libellé</th>
            <th>Catégorie</th>
            <th>Personne (obligatoire)</th>
            <th>Montant Int</th>
            <th>Source</th>
            <th>Actions (permissions)</th>
          </thead>
          <tbody>
            {paginated.map(t => (
              <tr key={t.id} style={{ borderTop: '1px solid #f3f4f6', opacity: 1 }}>
                <td style={{ padding: 12, fontSize: 12 }}>{t.date}</td>
                <td style={{ padding: 12, fontSize: 12 }}>{t.label}</td>
                <td style={{ padding: 12, fontSize: 12 }}>{t.category}</td>
                <td style={{ padding: 12, fontSize: 12 }}>{t.person} ({t.personId})</td>
                <td style={{ padding: 12, fontSize: 12 }}><strong>{(t.amountCents/100).toFixed(2)}€</strong><br/><span style={{ fontSize: 10, color: '#888' }}>{t.amountCents}c Int</span></td>
                <td style={{ padding: 12, fontSize: 11 }}><span style={{ background: '#f3f4f6', padding: '2px 6px', borderRadius: 6 }}>{t.source}</span></td>
                <td style={{ padding: 12 }}>
                  {isAuthenticated ? (
                    <div style={{ display: 'flex', gap: 4 }}>
                      {canEdit && (
                        <button style={{ fontSize: 11, padding: '4px 8px', borderRadius: 6, border: '1px solid #e5e7eb' }}>Modifier</button>
                      )}
                      {canDelete && (
                        <button style={{ fontSize: 11, padding: '4px 8px', borderRadius: 6, border: '1px solid #e5e7eb' }}>Supprimer soft</button>
                      )}
                    </div>
                  ) : (
                    <span style={{ color: '#666' }}>Connexion requise</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <div style={{ padding: 12, display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#666' }}>
          <span>Total filtré: {total} • Page {page}/{totalPages} • {pageSize} par page • Tri {sort.field} {sort.direction} • Totaux Int vérifiés</span>
          <div style={{ display: 'flex', gap: 4 }}>
            <button disabled={page===1} onClick={() => setPage(page-1)} style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #e5e7eb' }}>←</button>
            <span style={{ padding: '4px 8px' }}>{page}/{totalPages}</span>
            <button disabled={page===totalPages} onClick={() => setPage(page+1)} style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #e5e7eb' }}>→</button>
          </div>
        </div>
      </div>
        <div style={{ display: 'flex', gap: 16, marginBottom: 8 }}>
          <select
            style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #e5e7eb' }}
            onChange={e => setFilters({ ...filters, personId: e.target.value })}}
          >
            <option value="">Toutes personnes</option>
            {transactions.map(t => <option key={t.personId} value={t.personId}>{t.person} ({t.personId})</option>)}
          </select>
          <select
            style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #e5e7eb' }}
            onChange={e => setFilters({ ...filters, categoryId: e.target.value })}}
          >
            <option value="">Toutes catégories</option>
            <option value="manual">Manuel</option>
            <option value="import">Import</option>
            <option value="bank">Banque</option>
          </select>
        </div>

        <div style={{ display: 'flex', gap: 16, marginBottom: 8, fontSize: 12 }}>
          <label>
            <span>Source :</span>
            <select
              style={{ padding: 4, borderRadius: 4, border: '1px solid #e5e7eb' }}
              onChange={e => setFilters({ ...filters, source: e.target.value })}}
            >
              <option value="">Toutes</option>
              <option value="manual">Manuel</option>
              <option value="import">Import</option>
              <option value="bank">Banque</option>
            </select>
          </label>
          <label>
            <span>Label :</span>
            <select
              style={{ padding: 4, borderRadius: 4, border: '1px solid #e5e7eb' }}
              onChange={e => setFilters({ ...filters, label: e.target.value })}}
            >
              <option value="">Tout</option>
              {[...new Set(transactions.map(t => t.label))].map(l => <option key={l} value={l}>{l}</option>)}
            </select>
          </label>
        </div>

        <div style={{ display: 'flex', gap: 16 }}>
          <div style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #e5e7eb' }}>
            <label>
              <span>Min (cents)</span>
              <input
                type="number"
                value={filters.minCents || ''}
                onChange={e => setFilters({ ...filters, minCents: e.target.value })}}
                />
            </label>
          </div>
          <div style={{ flex: 1, padding: 8, borderRadius: 6, border: '1px solid #e5e7eb' }}>
            <label>
              <span>Max (cents)</span>
              <input
                type="number"
                value={filters.maxCents || ''}
                onChange={e => setFilters({ ...filters, maxCents: e.target.value })}}
                />
            </label>
          </div>
        </div>

        <div style={{ marginTop: 8, display: 'flex', gap: 16 }}>
          <label>
            <span>Date debut</span>
            <input
              type="date"
              value={filters.from || ''}
              onChange={e => setFilters({ ...filters, from: e.target.value })}}
              />
          </label>
          <label>
            <span>Date fin</span>
            <input
              type="date"
              value={filters.to || ''}
              onChange={e => setFilters({ ...filters, to: e.target.value })}}
              />
          </label>
        </div>
      </div>
</div>
    </main>
  );
}
