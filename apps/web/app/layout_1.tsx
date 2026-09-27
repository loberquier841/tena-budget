
import { ResponsiveNav } from '@/components/ResponsiveNav';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="manifest" href="/manifest.json" />
        <meta name="theme-color" content="#7C3AED" />
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
      </head>
      <body style={{ margin: 0, fontFamily: 'system-ui, -apple-system, sans-serif', background: '#fafafa' }}>
        <ResponsiveNav />
        {children}
        <div style={{ position: 'fixed', bottom: 16, right: 16, background: '#0A0A0B', color: 'white', padding: '8px 12px', borderRadius: 20, fontSize: 11, display: 'flex', gap: 8, alignItems: 'center', zIndex: 30 }}>
          <span style={{ width: 8, height: 8, background: '#22c55e', borderRadius: '50%', display: 'inline-block' }}></span>
          PWA • Offline Dexie • Étape 9/20
        </div>
        <style>{`
          @media (max-width: 768px) {
            .mobile-menu-btn { display: block !important; }
          }
        `}</style>
      </body>
    </html>
  );
}
