
'use client';
import { useState } from 'react';

const providers = [
  { id: 'mock', name: 'Mock (tests)', status: 'Mock uniquement - Étape 11', cost: 'Gratuit', license: 'Interne', pros: 'Tests sans SDK', cons: 'Pas de vraie banque', readOnly: true },
  { id: 'gocardless', name: 'GoCardless (ex Nordigen)', status: 'À comparer - pas choisi', cost: 'Gratuit 100 comptes, puis payant', license: 'API', pros: 'Gratuit début, 2000+ banques EU, PSD2, lecture seule', cons: 'Limite 100, support variable', readOnly: true },
  { id: 'tink', name: 'Tink (Visa)', status: 'À comparer - pas choisi', cost: 'Payant (sur devis)', license: 'API', pros: 'Très large couverture EU, UX consent, catégorisation', cons: 'Payant, contrat', readOnly: true },
  { id: 'plaid', name: 'Plaid', status: 'À comparer - pas choisi', cost: 'Payant US/EU', license: 'API', pros: 'Standard US, bonne doc', cons: 'Moins EU, payant', readOnly: true },
  { id: 'budget-insight', name: 'Budget Insight / Powens', status: 'À comparer - pas choisi', cost: 'Payant (sur devis)', license: 'API', pros: 'FR leader, 200+ banques FR, bon support FR', cons: 'Payant, contrat', readOnly: true },
];

export default function BankingPage() {
  const [selected, setSelected] = useState('mock');
  const [consent, setConsent] = useState<any>(null);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [raw, setRaw] = useState<any[]>([]);
  const [validated, setValidated] = useState(false);

  const createConsent = () => {
    setConsent({ consentId: `consent_mock_${Date.now()}`, expiresAt: new Date(Date.now()+90*86400000).toISOString().slice(0,10), status: 'active' });
  };

  const fetchAccounts = () => {
    setAccounts([
      { id: 'acc1', name: 'Compte Courant Mock', ibanMasked: 'FR76 **** **** 1234', balanceCents: 250000 },
      { id: 'acc2', name: 'Livret A Mock', ibanMasked: 'FR76 **** **** 5678', balanceCents: 500000 },
    ]);
  };

  const fetchTransactions = () => {
    setRaw([
      { id: 'raw1', label: 'Courses Leclerc', amountCents: -8500, date: '2026-01-15', hashDedup: 'abc123', accountId: 'acc1' },
      { id: 'raw2', label: 'Loyer', amountCents: -80000, date: '2026-01-05', hashDedup: 'def456', accountId: 'acc1' },
      { id: 'raw3', label: 'Salaire', amountCents: 250000, date: '2026-01-01', hashDedup: 'ghi789', accountId: 'acc1' },
    ]);
  };

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1 style={{ fontSize: 28 }}>🏦 Banking — Préparation (Étape 11) — Aucun SDK réel, aucun fournisseur choisi</h1>
      <p style={{ color: '#ef4444', fontWeight: 'bold' }}>⚠ Étape 11 = Préparatoire uniquement — Aucune connexion vraie banque — Mocks + interfaces + tests — Lecture seule uniquement — familyId isolé — Simulations exclues — PC personnel jamais nécessaire</p>
      <p style={{ color: '#666' }}>Réutilise exactement pipeline import 11 étapes • Validation humaine obligatoire avant Transaction réelle • Aucun identifiant bancaire stocké • 20 étapes minimum</p>

      <div style={{ background: 'white', padding: 16, borderRadius: 12, border: '2px solid #f59e0b', marginTop: 16 }}>
        <h2>Fournisseurs compatibles à comparer (sans choix automatique)</h2>
        <p style={{ fontSize: 11, color: '#666' }}>Aucun fournisseur définitif choisi — à comparer avec propriétaire après Étape 11 — Tous lecture seule PSD2</p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 12, marginTop: 12 }}>
          {providers.map(p => (
            <div key={p.id} onClick={() => setSelected(p.id)} style={{ border: `2px solid ${selected===p.id ? '#7C3AED' : '#e5e7eb'}`, borderRadius: 12, padding: 12, cursor: 'pointer', background: selected===p.id ? '#f5f3ff' : 'white' }}>
              <h3 style={{ fontSize: 14 }}>{p.name}</h3>
              <p style={{ fontSize: 11, color: p.id==='mock' ? '#22c55e' : '#f59e0b' }}>{p.status}</p>
              <p style={{ fontSize: 11 }}><strong>Coût:</strong> {p.cost}</p>
              <p style={{ fontSize: 11 }}><strong>Licence:</strong> {p.license} • <strong>Lecture seule:</strong> {p.readOnly ? 'Oui ✓' : 'Non'}</p>
              <p style={{ fontSize: 11, color: '#22c55e' }}>Pros: {p.pros}</p>
              <p style={{ fontSize: 11, color: '#ef4444' }}>Cons: {p.cons}</p>
              {selected===p.id && <p style={{ fontSize: 11, color: '#7C3AED', marginTop: 4 }}>→ Sélectionné pour démo mock (pas définitif)</p>}
            </div>
          ))}
        </div>
        <p style={{ fontSize: 11, color: '#888', marginTop: 8 }}>Tous compatibles: GoCardless, Tink, Plaid, Budget Insight — aucun choisi automatiquement — décision propriétaire après comparatif complet coût/couverture/support/RGPD</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16, marginTop: 16 }}>
        <div style={{ background: 'white', padding: 16, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3>Pipeline 11 étapes réutilisé pour bancaire</h3>
          <ol style={{ fontSize: 12, paddingLeft: 16 }}>
            <li>Sélection compte bancaire (mock)</li>
            <li>Analyse rawTransactions (hashDedup)</li>
            <li>Détection colonnes + EUR + dates FR</li>
            <li>Résumé catégories/personnes/années</li>
            <li>Corrections mapping → réexécution réelle</li>
            <li>Doublons exact/likely via hashDedup</li>
            <li>Comparaison côte à côte</li>
            <li>Prévisualisation sélection années</li>
            <li>Validation humaine obligatoire</li>
            <li>Import (après validation uniquement)</li>
            <li>Rapport complet</li>
          </ol>
          <p style={{ fontSize: 11, color: '#22c55e' }}>✓ Même pipeline que import-engine • bankingToImportPipeline() • Int centimes</p>
        </div>

        <div style={{ background: 'white', padding: 16, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3>Architecture sans PC personnel</h3>
          <p style={{ fontSize: 11 }}>Téléphones PWA Dexie ↕ HTTPS ↕ Vercel API ↕ Neon Postgres</p>
          <p style={{ fontSize: 11, marginTop: 8 }}><strong>PC éteint:</strong> App continue, auth continue, sync continue, données accessibles</p>
          <p style={{ fontSize: 11 }}><strong>PC allumé:</strong> Uniquement dev + git push + prisma migrate</p>
          <p style={{ fontSize: 11, color: '#22c55e', marginTop: 8 }}>✓ Aucun serveur local sur PC • Aucune base SQLite locale • Aucun tunnel ngrok • Aucun dossier partagé</p>
        </div>
      </div>

      <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
        <h2>Démo Mock — Lecture seule — Validation humaine obligatoire</h2>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 12 }}>
          <button onClick={createConsent} style={{ background: '#7C3AED', color: 'white', padding: '8px 16px', borderRadius: 8, border: 'none' }}>1. Créer consent mock (90j)</button>
          <button onClick={fetchAccounts} disabled={!consent} style={{ background: consent ? '#7C3AED' : '#e5e7eb', color: consent ? 'white' : '#888', padding: '8px 16px', borderRadius: 8, border: 'none' }}>2. Lister comptes (IBAN masqué)</button>
          <button onClick={fetchTransactions} disabled={accounts.length===0} style={{ background: accounts.length ? '#7C3AED' : '#e5e7eb', color: accounts.length ? 'white' : '#888', padding: '8px 16px', borderRadius: 8, border: 'none' }}>3. Fetch transactions mock (hashDedup)</button>
        </div>

        {consent && <p style={{ fontSize: 12, marginTop: 12 }}>✓ Consent: {consent.consentId} • Expire: {consent.expiresAt} • Status: {consent.status} • Lecture seule • 90j</p>}

        {accounts.length > 0 && (
          <div style={{ marginTop: 12 }}>
            <p style={{ fontSize: 12 }}><strong>Comptes (IBAN masqué uniquement, jamais complet):</strong></p>
            {accounts.map(a => (
              <div key={a.id} style={{ padding: 8, background: '#f9fafb', borderRadius: 6, marginTop: 4, fontSize: 12 }}>
                {a.name} • {a.ibanMasked} • {(a.balanceCents/100).toFixed(2)}€ ({a.balanceCents}c Int) • familyId isolé
              </div>
            ))}
          </div>
        )}

        {raw.length > 0 && (
          <div style={{ marginTop: 12 }}>
            <p style={{ fontSize: 12 }}><strong>Transactions brutes (rawData lecture seule, aucun secret bancaire):</strong></p>
            <table style={{ width: '100%', fontSize: 12, marginTop: 8 }}>
              <thead><tr style={{ color: '#666' }}><th>Date</th><th>Libellé</th><th>Montant</th><th>hashDedup</th><th>Doublon?</th></tr></thead>
              <tbody>
                {raw.map(r => (
                  <tr key={r.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                    <td>{r.date}</td><td>{r.label}</td><td>{(r.amountCents/100).toFixed(2)}€ ({r.amountCents}c)</td><td style={{ fontSize: 10 }}>{r.hashDedup}</td><td><span style={{ background: '#bbf7d0', padding: '2px 6px', borderRadius: 6, fontSize: 10 }}>Nouveau (pas de hash existant)</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p style={{ fontSize: 11, color: '#888', marginTop: 8 }}>Réimport/doublons gérés via hashDedup = date|amount|label.lower() • Simulations toujours exclues • familyId isolé</p>

            <div style={{ marginTop: 16, padding: 12, background: '#fef2f2', borderRadius: 8, border: '1px solid #fecaca' }}>
              <p style={{ fontSize: 12, fontWeight: 'bold', color: '#ef4444' }}>Validation humaine obligatoire avant transformation en Transaction réelle</p>
              <label style={{ display: 'flex', gap: 8, marginTop: 8, fontSize: 12 }}>
                <input type="checkbox" checked={validated} onChange={e => setValidated(e.target.checked)} />
                Je confirme avoir vérifié les {raw.length} transactions brutes et je veux les transformer en Transactions réelles (après validation). Je comprends que familyId sera isolé et simulations exclues.
              </label>
              {validated && <p style={{ fontSize: 12, color: '#22c55e', marginTop: 8 }}>✓ Validé — transformToTransactionAfterValidation() autorisé — crée Transaction avec source=bank + hashDedup + personId + familyId isolé</p>}
              {!validated && <p style={{ fontSize: 11, color: '#ef4444', marginTop: 4 }}>⚠ Aucune Transaction réelle créée sans validation — requiresHumanValidation() = true — VALIDATION_REQUIRED</p>}
            </div>
          </div>
        )}
      </div>

      <div style={{ marginTop: 16, padding: 12, background: '#f0fdf4', borderRadius: 8, border: '1px solid #bbf7d0' }}>
        <p style={{ fontSize: 11 }}>✓ Aucun SDK bancaire réel • Aucun fournisseur définitif choisi • Aucune connexion vraie banque • Interfaces + mocks + tests uniquement • Lecture seule • Aucun IBAN complet/mot de passe stocké • familyId isolé • Simulations exclues • Réimport/doublons hashDedup • Validation humaine obligatoire • Pipeline 11 étapes réutilisé • PC personnel jamais nécessaire • 20 étapes minimum</p>
      </div>
    </main>
  );
}
