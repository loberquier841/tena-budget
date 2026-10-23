export const APP_NAME = 'TENΛ Budget';
export const APP_VERSION = '1.1.0-fondations';

export const ROLES = ['owner', 'admin', 'member', 'child'] as const;
export type Role = typeof ROLES[number];
export const TRANSACTION_SOURCES = ['manual', 'import', 'bank'] as const;

// Montants en centimes pour éviter float
// Utilise Math.round pour arrondi standard, lance des erreurs pour valeurs invalides
export const toCents = (euros: number): number => {
  const amount = Number(euros);
  if (Number.isNaN(amount)) {
    throw new Error('TO_CENTS_INVALID: montant invalide');
  }
  if (!Number.isFinite(amount)) {
    throw new Error('TO_CENTS_INVALID: montant non fini');
  }
  return Math.round(amount * 100);
};

export const fromCents = (cents: number): number => {
  const amount = Number(cents);
  if (Number.isNaN(amount)) {
    throw new Error('FROM_CENTS_INVALID: montant en centimes invalide');
  }
  if (!Number.isFinite(amount)) {
    throw new Error('FROM_CENTS_INVALID: montant en centimes non fini');
  }
  return amount / 100;
};

// 6 couches immuables import
