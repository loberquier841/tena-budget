import type { Metadata } from 'next';
import { ResponsiveNav } from '@/components/ResponsiveNav';

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://example.invalid';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'TENΛ Budget — Gestion financière locale, claire et privée',
    template: '%s — TENΛ Budget',
  },
  description:
    'Application de budget local-first : transactions, budgets, objectifs, prévisions, sauvegardes chiffrées et justificatifs. Données sur votre appareil, sans serveur financier obligatoire.',
  openGraph: {
    type: 'website',
    locale: 'fr_FR',
    siteName: 'TENΛ Budget',
    title: 'TENΛ Budget — Gestion financière locale, claire et privée',
    description:
      'Budget local-first : transactions, budgets, objectifs, prévisions et sauvegardes chiffrées. Données sur votre appareil.',
    images: [{ url: '/icon-512.png', width: 512, height: 512, alt: 'TENΛ Budget' }],
  },
  twitter: { card: 'summary', title: 'TENΛ Budget', description: 'Gestion financière locale et privée.' },
  robots: { index: true, follow: true },
  manifest: '/manifest.json',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body
        style={{
          margin: 0,
          fontFamily: 'system-ui, -apple-system, sans-serif',
          background: '#09090b',
          color: '#f5f5f7',
        }}
      >
        <ResponsiveNav />
        {children}
      </body>
    </html>
  );
}
