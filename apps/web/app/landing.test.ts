import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

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

  it('uses the same dark and gold brand colors as the website', () => {
    expect(manifest.background_color).toBe('#08090d');
    expect(manifest.theme_color).toBe('#e7c979');
  });
});
