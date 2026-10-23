import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { MonthlyChart } from '../components/Charts';

const page = readFileSync(new URL('./page.tsx', import.meta.url), 'utf8');
const styles = readFileSync(new URL('./landing.module.css', import.meta.url), 'utf8');
const manifest = JSON.parse(
  readFileSync(new URL('../public/manifest.json', import.meta.url), 'utf8'),
) as { background_color: string; theme_color: string };

describe('TENΛ Budget landing page', () => {
  it('keeps the onboarding path and privacy information visible', () => {
    expect(page).toContain('href="/onboarding"');
    expect(page).toContain('src="/icon-192.png"');
    expect(page).toContain('Où sont enregistrées mes réponses ?');
    expect(page).toContain('Le questionnaire crée un profil dans le stockage local');
    expect(page).toContain('La connexion bancaire réelle n’est pas activée.');
  });

  it('provides a CSS module selector for every class used by the page', () => {
    const usedClasses = new Set(
      [...page.matchAll(/styles\.([A-Za-z_][A-Za-z0-9_]*)/g)].map((match) => match[1]),
    );
    const definedClasses = new Set(
      [...styles.matchAll(/\.([A-Za-z_][A-Za-z0-9_-]*)/g)].map((match) => match[1]),
    );

    expect(usedClasses.size).toBeGreaterThan(0);

    for (const className of usedClasses) {
      expect(definedClasses, `Missing CSS selector for styles.${className}`).toContain(className);
    }
  });

  it('announces chart periods and euro values to screen readers', () => {
    const markup = renderToStaticMarkup(
      createElement(MonthlyChart, {
        data: [
          { month: 'Sem. 1', totalCents: 28000 },
          { month: 'Sem. 2', totalCents: 0 },
        ],
      }),
    );

    expect(markup).toContain('role="img"');
    expect(markup).toContain('aria-label="Évolution mensuelle des dépenses. Sem. 1 : 280,00');
    expect(markup).toContain('Sem. 2 : 0,00');
    expect(markup).toContain('height:6%');
  });

  it('explains when the chart has no data', () => {
    const markup = renderToStaticMarkup(createElement(MonthlyChart, { data: [] }));

    expect(markup).toContain('Aucune donnée');
  });

  it('ships the app icons referenced by the web manifest', () => {
    expect(existsSync(new URL('../public/icon-192.png', import.meta.url))).toBe(true);
    expect(existsSync(new URL('../public/icon-512.png', import.meta.url))).toBe(true);
    expect(page).toContain('src="/icon-192.png"');
  });

  it('uses the same dark and gold palette as the Flutter app', () => {
    expect(styles).toContain('--bg: #09090b');
    expect(styles).toContain('--gold: #d4af37');
    expect(styles).toContain('--gold-light: #e8cc6a');
    expect(manifest.background_color).toBe('#09090b');
    expect(manifest.theme_color).toBe('#d4af37');
  });
});
