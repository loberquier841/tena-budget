import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { readFileSync } from 'node:fs';
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

  it('renders the existing monthly chart accessibly and handles zero-value weeks', () => {
    const markup = renderToStaticMarkup(
      createElement(MonthlyChart, {
        data: [
          { month: 'Sem. 1', totalCents: 28000 },
          { month: 'Sem. 2', totalCents: 0 },
        ],
      }),
    );

    expect(markup).toContain('aria-label="Évolution mensuelle des dépenses"');
    expect(markup).toContain('Sem. 1');
    expect(markup).toContain('height:6%');
  });

  it('uses the same dark and gold brand colors as the website', () => {
    expect(manifest.background_color).toBe('#08090d');
    expect(manifest.theme_color).toBe('#e7c979');
  });
});
