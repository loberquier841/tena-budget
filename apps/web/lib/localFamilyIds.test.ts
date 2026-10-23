import { describe, expect, it } from 'vitest';
import { resolveLocalFamilyIds } from './localFamilyIds';

describe('premier espace local', () => {
  it('ne crée l’espace initial qu’après la création du profil', () => {
    expect(resolveLocalFamilyIds([], false, undefined, () => 'generated')).toEqual([]);
    expect(resolveLocalFamilyIds([], true, undefined, () => 'generated')).toEqual(['generated']);
  });

  it('garde les espaces existants et réutilise l’identifiant principal sauvegardé', () => {
    expect(resolveLocalFamilyIds(['fam-b', 'fam-a'], true, 'fam-primary', () => 'unused')).toEqual(['fam-a', 'fam-b']);
    expect(resolveLocalFamilyIds([], true, 'fam-primary')).toEqual(['fam-primary']);
  });
});
