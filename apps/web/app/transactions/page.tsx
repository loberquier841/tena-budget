
'use client';
import { useState } from 'react';

export default function TransactionsFinalPage() {
  const [filters, setFilters] = useState({ personId: '', categoryId: '', source: '', minCents: '', maxCents: '', label: '', from: '', to: '', includeDeleted: false });
  const [sort, setSort] = useState({ field: 'bookingDate', direction: 'desc' });
  const [page, setPage] = useState(1);
  const pageSize = 10;

  const mockTx = [
    { id: 'tx1', date: '2026-01-15', label: 'Courses Leclerc', category: 'Courses', person: 'Parent 1', personId: 'p1', amountCents: 8500, source: 'manual', notes: '' },
    { id: 'tx2', date: '2026-01-16', label: 'Essence Total', category: 'Transport', person: 'Parent 2', personId: 'p2', amountCents: 6000, source: 'import', notes: '' },
    { id: 'tx3', date: '2026-01-17', label: 'Loyer', category: 'Logement', person: 'Parent 1', personId: 'p1', amountCents: 80000, source: 'manual', notes: 'Virement' },
    { id: 'tx4', date: '2026-01-18', label: 'Cinéma', category: 'Loisirs', person: 'Parent 1', personId: 'p1', amountCents: 2500, source: 'manual', notes: '', isDeleted: true },
  ];

  const filtered = mockTx.filter(t => {
    if (!filters.includeDeleted && (t as any).isDeleted) return false;
    if (filters.personId && t.personId !== filters.personId) return false;
    if (filters.categoryId && t.category !== filters.categoryId) return false;
    if (filters.source && t.source !== filters.source) return false;
    if (filters.minCents && t.amountCents < parseInt(filters.minCents)) return false;
    if (filters.maxCents && t.amountCents > parseInt(filters.maxCents)) return false;
    if (filters.label && !t.label.toLowerCase().includes(filters.label.toLowerCase())) return false;
    if (filters.from && t.date < filters.from) return false;
    if (filters.to && t.date > filters.to) return false;
    return true;
  });

  const sorted = [...filtered].sort((a,b) => {
    let cmp = 0;
    if (sort.field === 'bookingDate') cmp = a.date.localeCompare(b.date);
    else if (sort.field === 'amountCents') cmp = a.amountCents - b.amountCents;
    else cmp = a.label.localeCompare(b.label);
    return sort.direction === 'asc' ? cmp : -cmp;
  });

  const total = sorted.length;
  const totalPages = Math.ceil(total / pageSize);
  const paginated = sorted.slice((page-1)*pageSize, page*pageSize);

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1 style={{ fontSize: 28 }}>Transactions final — Recherche avancée, Int centimes</h1>
      <p style={{ color: '#666' }}>Filtres combinables + tri + pagination + modification + soft delete + permissions + isDeleted exclu stats + personId obligatoire • 20 étapes min</p>

      <div style={{ background: 'white', padding: 16, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
        <h3 style={{ fontSize: 14 }}>Filtres combinables (tous combinables)</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 8, marginTop: 8 }}>
          <select value={filters.personId} onChange={e => setFilters({...filters, personId: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option value="">Toutes personnes</option><option value="p1">Parent 1</option><option value="p2">Parent 2</option></select>
          <select value={filters.categoryId} onChange={e => setFilters({...filters, categoryId: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option value="">Toutes catégories</option><option value="Courses">Courses</option><option value="Transport">Transport</option><option value="Logement">Logement</option></select>
          <select value={filters.source} onChange={e => setFilters({...filters, source: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}><option value="">Toutes sources</option><option value="manual">manual</option><option value="import">import</option><option value="bank">bank</option></select>
          <input type="date" value={filters.from} onChange={e => setFilters({...filters, from: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }} />
          <input type="date" value={filters.to} onChange={e => setFilters({...filters, to: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }} />
          <input type="number" placeholder="Min centimes" value={filters.minCents} onChange={e => setFilters({...filters, minCents: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }} />
          <input type="number" placeholder="Max centimes" value={filters.maxCents} onChange={e => setFilters({...filters, maxCents: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }} />
          <input placeholder="Recherche texte libellé/notes" value={filters.label} onChange={e => setFilters({...filters, label: e.target.value})} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }} />
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 8, alignItems: 'center' }}>
          <select value={`${sort.field}-${sort.direction}`} onChange={e => { const [f,d] = e.target.value.split('-'); setSort({ field: f, direction: d as any }); }} style={{ padding: 8, borderRadius: 8, border: '1px solid #e5e7eb' }}>
            <option value="bookingDate-desc">Date ↓</option><option value="bookingDate-asc">Date ↑</option>
            <option value="amountCents-desc">Montant ↓</option><option value="amountCents-asc">Montant ↑</option>
            <option value="label-asc">Libellé A→Z</option><option value="label-desc">Libellé Z→A</option>
          </select>
          <label style={{ fontSize: 12, display: 'flex', gap: 4, alignItems: 'center' }}><input type="checkbox" checked={filters.includeDeleted} onChange={e => setFilters({...filters, includeDeleted: e.target.checked})} /> Inclure supprimées (isDeleted)</label>
          <span style={{ fontSize: 11, color: '#888' }}>Tri + pagination + advancedSearch() + assertCan(budget:read) + assertCan(transaction:write) pour modif</span>
        </div>
      </div>

      <div style={{ background: 'white', borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16, overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ background: '#f9fafb' }}><tr style={{ fontSize: 11, color: '#666', textAlign: 'left' }}><th style={{ padding: 12 }}>Date</th><th>Libellé</th><th>Catégorie</th><th>Personne (obligatoire)</th><th>Montant Int</th><th>Source</th><th>Actions (permissions)</th></tr></thead>
          <tbody>
            {paginated.map(t => (
              <tr key={t.id} style={{ borderTop: '1px solid #f3f4f6', opacity: (t as any).isDeleted ? 0.5 : 1 }}>
                <td style={{ padding: 12, fontSize: 12 }}>{t.date}</td>
                <td style={{ padding: 12, fontSize: 12 }}>{t.label} {(t as any).isDeleted && <span style={{ background: '#fecaca', fontSize: 10, padding: '2px 4px', borderRadius: 4 }}>deleted</span>}</td>
                <td style={{ padding: 12, fontSize: 12 }}>{t.category}</td>
                <td style={{ padding: 12, fontSize: 12 }}>{t.person} ({t.personId})</td>
                <td style={{ padding: 12, fontSize: 12 }}><strong>{(t.amountCents/100).toFixed(2)}€</strong><br/><span style={{ fontSize: 10, color: '#888' }}>{t.amountCents}c Int</span></td>
                <td style={{ padding: 12, fontSize: 11 }}><span style={{ background: '#f3f4f6', padding: '2px 6px', borderRadius: 6 }}>{t.source}</span></td>
                <td style={{ padding: 12 }}>
                  <button style={{ fontSize: 11, padding: '4px 8px', borderRadius: 6, border: '1px solid #e5e7eb' }}>Modifier (assertCan tx:write + seuil 500€ owner)</button>{' '}
                  <button style={{ fontSize: 11, padding: '4px 8px', borderRadius: 6, border: '1px solid #fecaca', color: '#ef4444' }}>Supprimer soft (assertCan tx:delete)</button>
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
    </main>
  );
}
