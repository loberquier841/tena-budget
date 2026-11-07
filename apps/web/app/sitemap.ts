import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_SITE_URL || 'https://example.invalid';
  const now = new Date();
  const routes = ['/', '/download', '/onboarding', '/dashboard', '/transactions', '/budgets', '/objectifs', '/simulations', '/assistant', '/import', '/exports', '/sauvegardes', '/famille', '/historique', '/recurrentes', '/banking', '/beta', '/audit'];
  return routes.map((r) => ({ url: `${base}${r}`, lastModified: now, changeFrequency: 'weekly' as const, priority: r === '/' ? 1 : 0.6 }));
}
