import { describe, expect, it } from 'vitest';
import { analyzeLocalImportFile, formatLocalImportError } from './localImport';

describe('sélection des fichiers d’import local', () => {
  it('refuse les extensions autres que CSV et XLSX sans lire ni envoyer le fichier', async () => {
    const file = { name: 'releve.pdf', size: 12, arrayBuffer: async () => { throw new Error('ne doit pas lire'); } } as unknown as File;
    await expect(analyzeLocalImportFile(file)).rejects.toThrow('Format non pris en charge');
  });

  it('refuse les fichiers vides ou au-dessus de la limite locale', async () => {
    const empty = { name: 'vide.csv', size: 0 } as File;
    const large = { name: 'releve.csv', size: 10 * 1024 * 1024 + 1 } as File;
    await expect(analyzeLocalImportFile(empty)).rejects.toThrow('moins de 10 Mo');
    await expect(analyzeLocalImportFile(large)).rejects.toThrow('moins de 10 Mo');
  });

  it('présente les erreurs d’association et de lecture en français clair', () => {
    expect(formatLocalImportError(new Error('IMPORT_MAPPING_AMOUNT_REQUIRED'))).toContain('colonne pour le montant');
    expect(formatLocalImportError(new Error('CSV_UNCLOSED_QUOTE'))).toContain('guillemet');
  });
});
