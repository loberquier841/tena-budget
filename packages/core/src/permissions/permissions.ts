
// Vérification côté serveur uniquement - jamais frontend seul
export type Role = 'owner' | 'admin' | 'member' | 'child';
export type Action = 'family:delete' | 'budget:write' | 'budget:read' | 'transaction:read' | 'transaction:write' | 'transaction:delete' | 'import:write' | 'bank:connect' | 'bank:revoke';

const MATRIX: Record<Role, Action[]> = {
  owner: ['family:delete','budget:write','budget:read','transaction:read','transaction:write','transaction:delete','import:write','bank:connect','bank:revoke'],
  admin: ['budget:write','budget:read','transaction:read','transaction:write','transaction:delete','import:write','bank:connect','bank:revoke'],
  member: ['budget:read','transaction:read','transaction:write'],
  child: ['budget:read'],
};

export function can(role: Role, action: Action): boolean {
  return (MATRIX[role] || []).includes(action);
}

export function assertCan(role: Role, action: Action) {
  if (!can(role, action)) throw new Error(`PERMISSION_DENIED: ${role} cannot ${action}`);
}

// Pas de suppression silencieuse - soft delete obligatoire
export function mustSoftDelete() {
  return { isDeleted: true, deletedAt: new Date() };
}

// Seuil financier important
export const FINANCIAL_THRESHOLD_CENTS = 50000; // 500€

export function requiresOwnerConfirmation(amountCents: number): boolean {
  return Math.abs(amountCents) >= FINANCIAL_THRESHOLD_CENTS;
}
