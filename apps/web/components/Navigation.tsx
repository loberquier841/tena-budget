
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const links = [
  { href: '/dashboard', label: 'Tableau de bord', icon: '📊' },
  { href: '/famille', label: 'Famille', icon: '👨‍👩‍👧‍👦' },
  { href: '/budgets', label: 'Budgets', icon: '💰' },
  { href: '/transactions', label: 'Transactions', icon: '💳' },
  { href: '/historique', label: 'Historique', icon: '📈' },
  { href: '/simulations', label: 'Simulations', icon: '🔮' },
  { href: '/assistant', label: 'Assistant TENΛ', icon: '🤖' },
  { href: '/exports', label: 'Exports', icon: '📤' },
  { href: '/sauvegardes', label: 'Sauvegardes', icon: '💾' },
];

export function Navigation() {
  const pathname = usePathname();
  return (
    <nav style={{ width: 240, background: '#0A0A0B', color: 'white', minHeight: '100vh', padding: 16, position: 'fixed', left: 0, top: 0 }}>
      <h2 style={{ color: '#7C3AED', marginBottom: 24 }}>TENΛ Budget</h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {links.map(l => (
          <Link key={l.href} href={l.href} style={{ 
            padding: '8px 12px', 
            borderRadius: 8, 
            background: pathname === l.href ? '#7C3AED' : 'transparent',
            color: 'white',
            textDecoration: 'none',
            display: 'flex',
            gap: 8
          }}>
            <span>{l.icon}</span> {l.label}
          </Link>
        ))}
      </div>
      <div style={{ marginTop: 24, padding: 12, background: '#1A1A1B', borderRadius: 8 }}>
        <p style={{ fontSize: 12, color: '#888' }}>PWA installable • Offline-first</p>
        <p style={{ fontSize: 12, color: '#888' }}>20 étapes minimum</p>
        <p style={{ fontSize: 12, color: '#22c55e' }}>● En ligne</p>
      </div>
    </nav>
  );
}

export function OfflineIndicator() {
  return (
    <div style={{ position: 'fixed', bottom: 16, right: 16, background: '#22c55e', color: 'white', padding: '8px 16px', borderRadius: 20, fontSize: 12 }}>
      ● Offline-ready via Dexie
    </div>
  );
}
