import { analyzeFiles, type AnalyzedSheet, type OriginalFile } from '@tena/import-engine';

const MAX_IMPORT_BYTES = 10 * 1024 * 1024;

export function formatLocalImportError(error: unknown): string {
  const code = error instanceof Error ? error.message : String(error ?? '');
  const messages: Record<string, string> = {
    CSV_UNCLOSED_QUOTE: 'Le CSV contient un guillemet qui n’est pas refermé.',
    CSV_INVALID_QUOTE: 'Le CSV contient des guillemets mal placés.',
    CSV_DUPLICATE_HEADERS: 'Deux colonnes portent le même nom. Renomme-les puis réessaie.',
    CSV_HEADERS_REQUIRED: 'La première ligne du CSV doit contenir les noms de colonnes.',
    CSV_COLUMN_COUNT_MISMATCH: 'Une ligne du CSV contient plus de colonnes que l’en-tête.',
    XLSX_NO_SHEETS: 'Le classeur ne contient aucune feuille lisible.',
    XLSX_HEADERS_REQUIRED: 'La première ligne de la feuille doit contenir des noms de colonnes.',
    XLSX_DUPLICATE_HEADERS: 'Deux colonnes de cette feuille portent le même nom.',
    IMPORT_SHEET_TOO_LARGE: 'La feuille dépasse la limite de taille autorisée pour cet import.',
    IMPORT_FILE_UNSUPPORTED: 'Ce format de fichier n’est pas pris en charge.',
    LOCAL_VAULT_LOCKED: 'Déverrouille le coffre local avant d’importer.',
    LOCAL_IMPORT_ID_CONFLICT: 'Un conflit local a interrompu l’ajout. Aucune donnée existante n’a été remplacée.',
  };
  if (messages[code]) return messages[code];
  const mapping = code.match(/^IMPORT_MAPPING_(DATE|AMOUNT|LABEL)_REQUIRED$/);
  if (mapping) return `Choisis une colonne pour ${({ DATE: 'la date', AMOUNT: 'le montant', LABEL: 'le libellé' } as const)[mapping[1] as 'DATE' | 'AMOUNT' | 'LABEL']}.`;
  if (code === 'IMPORT_MAPPING_INVALID') return 'Chaque type d’information doit être associé à une colonne différente.';
  return code || 'Le fichier n’a pas pu être lu. Vérifie son format et son contenu.';
}

export async function analyzeLocalImportFile(file: File): Promise<AnalyzedSheet[]> {
  if (!file.size || file.size > MAX_IMPORT_BYTES) throw new Error('Choisis un fichier non vide de moins de 10 Mo.');
  const extension = file.name.toLocaleLowerCase().split('.').pop();
  const mime: OriginalFile['mime'] = extension === 'csv' ? 'csv' : extension === 'xlsx' ? 'xlsx' : 'unknown';
  if (mime === 'unknown') throw new Error('Format non pris en charge. Choisis un fichier CSV ou XLSX.');
  return analyzeFiles([{ id: 'local-import', name: file.name, mime, size: file.size, buffer: await file.arrayBuffer() }]);
}
