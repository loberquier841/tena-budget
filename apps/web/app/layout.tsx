
export const metadata = {
  title: 'TENΛ Budget — Ton budget. Tes choix. Ta liberté.',
  description: 'Gère ton budget avec TENΛ Budget : une approche gratuite, locale et pensée pour garder tes données sous ton contrôle.',
};

import { ResponsiveNav } from '@/components/ResponsiveNav';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="manifest" href="/manifest.json" />
        <meta name="theme-color" content="#08090d" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body style={{ margin: 0, fontFamily: 'system-ui, -apple-system, sans-serif', background: '#08090d' }}>
        <ResponsiveNav />
        {children}        <style>{`
          @media (max-width: 768px) {
            .mobile-menu-btn { display: block !important; }
          }
        `}</style>
      </body>
    </html>
  );
}
