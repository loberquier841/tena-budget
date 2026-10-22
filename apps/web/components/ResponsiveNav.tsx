
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';

const links = [
  { href: '/onboarding', label: 'Onboarding', icon: '📝', desc: 'Questionnaire et profil local' },
  { href: '/dashboard', label: 'Tableau de bord', icon: '📊', desc: 'Budget prévu vs dépensé vs restant Int' },
  { href: '/budgets', label: 'Budgets', icon: '💰', desc: 'Annuels/mensuels Int centimes' },
  { href: '/transactions', label: 'Transactions', icon: '💳', desc: 'Liées personne, soft delete' },
  { href: '/recurrentes', label: 'Récurrentes', icon: '🔁', desc: 'Hebdo/mensuel, pending_validation' },
  { href: '/objectifs', label: 'Objectifs', icon: '🎯', desc: 'targetCents Int, progression % Int' },
  { href: '/famille', label: 'Famille', icon: '👨‍👩‍👧‍👦', desc: 'Roles + invitations + 3 appareils' },
  { href: '/historique', label: 'Historique', icon: '📈', desc: 'N vs N-1, Int diff' },
  { href: '/simulations', label: 'Simulations', icon: '🔮', desc: 'sim_ isolées, jamais réel modifié' },
  { href: '/assistant', label: 'Assistant', icon: '🤖', desc: 'Lecture autorisée, pas LLM payant' },
  { href: '/exports', label: 'Exports', icon: '📤', desc: 'Excel/CSV/PDF Int vérifiés' },
  { href: '/sauvegardes', label: 'Sauvegardes', icon: '💾', desc: 'AES-GCM + checksum' },
];

export function ResponsiveNav() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const pathname = usePathname();

  return (
    <>
      {/* Bouton mobile */}
      <button
        onClick={() => setMobileOpen(!mobileOpen)}
        style={{
          position: 'fixed', top: 12, left: 12, zIndex: 100,
          background: '#7C3AED', color: 'white', border: 'none',
          borderRadius: 8, padding: '8px 12px', cursor: 'pointer',
          display: 'none'
        }}
        className="mobile-menu-btn"
      >
        {mobileOpen ? '✕' : '☰'}
      </button>

      {/* Overlay mobile */}
      {mobileOpen && (
        <div
          onClick={() => setMobileOpen(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 40 }}
        />
      )}

      {/* Sidebar */}
      <nav
        style={{
          width: 260,
          background: '#0A0A0B',
          color: 'white',
          minHeight: '100vh',
          padding: 16,
          position: 'fixed',
          left: 0,
          top: 0,
          zIndex: 50,
          overflowY: 'auto',
          transform: mobileOpen ? 'translateX(0)' : undefined,
        }}
        className="sidebar"
      >
        <h2 style={{ color: '#7C3AED', marginBottom: 8 }}>TENΛ Budget</h2>
        <p style={{ fontSize: 10, color: '#666', marginBottom: 16 }}>20 étapes minimum • Offline-first • Int centimes</p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {links.map(l => {
            const active = pathname === l.href;
            return (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setMobileOpen(false)}
                style={{
                  padding: '10px 12px',
                  borderRadius: 8,
                  background: active ? '#7C3AED' : 'transparent',
                  color: 'white',
                  textDecoration: 'none',
                  display: 'flex',
                  flexDirection: 'column',
                  border: active ? '1px solid #7C3AED' : '1px solid transparent',
                }}
              >
                <span style={{ display: 'flex', gap: 8, fontWeight: active ? 'bold' : 'normal' }}>
                  <span>{l.icon}</span> {l.label}
                </span>
                <span style={{ fontSize: 10, color: active ? '#ddd' : '#888', marginTop: 2 }}>{l.desc}</span>
              </Link>
            );
          })}
        </div>

        <div style={{ marginTop: 24, padding: 12, background: '#1A1A1B', borderRadius: 8 }}>
          <p style={{ fontSize: 11, color: '#22c55e' }}>● PWA installable</p>
          <p style={{ fontSize: 11, color: '#22c55e' }}>● Offline Dexie</p>
          <p style={{ fontSize: 11, color: '#888' }}>● Permissions serveur</p>
          <p style={{ fontSize: 11, color: '#888' }}>● isDeleted exclu</p>
          <p style={{ fontSize: 11, color: '#888' }}>● Simulations isolées</p>
          <p style={{ fontSize: 11, color: '#888', marginTop: 8 }}>Étape 9 / 20</p>
        </div>
      </nav>

      <style>{`
        @media (max-width: 768px) {
          .sidebar {
            transform: translateX(-100%);
            transition: transform 0.3s ease;
          }
          .sidebar.open {
            transform: translateX(0);
          }
          .mobile-menu-btn {
            display: block !important;
          }
          main {
            margin-left: 0 !important;
            padding-top: 56px !important;
          }
        }
        @media (min-width: 769px) {
          .sidebar {
            transform: translateX(0) !important;
          }
        }
      `}</style>
    </>
  );
}
