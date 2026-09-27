
 // RGPD - Registre des traitements - Étape 14

export interface ProcessingActivity {
  id: string;
  name: string;
  purpose: string;
  dataCategories: string[];
  legalBasis: string;
  retention: string;
  recipients: string[];
  securityMeasures: string[];
  familyIdIsolated: boolean;
  isDeletedExcluded: boolean;
}

export const REGISTRY: ProcessingActivity[] = [
  {
    id: 'budget',
    name: 'Gestion budgets familiaux',
    purpose: 'Suivi budget prévu/dépensé/restant par famille et personne',
    dataCategories: ['familyId', 'personId', 'amountCents Int', 'year', 'month', 'categoryId', 'isDeleted', 'createdByUserId'],
    legalBasis: 'Contrat (gestion budget familiale)',
    retention: 'Durée vie compte + 30j soft delete + anonymisation',
    recipients: ['Famille uniquement (familyId isolé)', 'Aucun tiers'],
    securityMeasures: ['assertCan(budget:write)', 'familyId filtré', 'isDeleted exclu stats', 'Int centimes', 'seuil 500€ owner'],
    familyIdIsolated: true,
    isDeletedExcluded: true,
  },
  {
    id: 'transaction',
    name: 'Gestion transactions',
    purpose: 'Suivi dépenses/recettes par personne, recherche avancée, stats',
    dataCategories: ['familyId', 'personId', 'amountCents Int', 'bookingDate', 'label', 'categoryId', 'source manual/import/bank', 'isDeleted', 'hashDedup', 'createdByUserId'],
    legalBasis: 'Contrat',
    retention: 'Durée vie compte + 30j soft delete + anonymisation après 30j + hard delete encadré owner',
    recipients: ['Famille uniquement'],
    securityMeasures: ['assertCan(transaction:write/delete)', 'familyId isolé', 'personId obligatoire', 'isDeleted exclu', 'Int centimes', 'hashDedup réimport'],
    familyIdIsolated: true,
    isDeletedExcluded: true,
  },
  {
    id: 'export',
    name: 'Export données Excel/CSV/PDF',
    purpose: 'Droit accès RGPD, export famille/personne',
    dataCategories: ['Transactions, Budgets, totalCents Int'],
    legalBasis: 'Obligation légale (droit accès) + Contrat',
    retention: 'Export ponctuel, pas stocké serveur',
    recipients: ['Utilisateur demandeur (familyId filtré)'],
    securityMeasures: ['assertCan(budget:read)', 'familyId isolé', 'isDeleted exclu', 'verifyExportTotals'],
    familyIdIsolated: true,
    isDeletedExcluded: true,
  },
  {
    id: 'backup',
    name: 'Sauvegardes chiffrées',
    purpose: 'Sauvegarde/restauration familiale chiffrée',
    dataCategories: ['Transactions, Budgets, hashDedup, checksum SHA-256'],
    legalBasis: 'Contrat + Intérêt légitime (sauvegarde)',
    retention: "Jusqu'à suppression manuelle, chiffrée AES-GCM 256, password utilisateur",
    recipients: ['Famille uniquement, chiffrée côté client'],
    securityMeasures: ['AES-GCM 256', 'PBKDF2 100000', 'SHA-256 checksum', 'BACKUP_INTEGRITY_FAILED si corrompu', 'familyId isolé', '!isDeleted'],
    familyIdIsolated: true,
    isDeletedExcluded: true,
  },
  {
    id: 'banking_mock',
    name: 'Banking préparation mock',
    purpose: 'Préparation bancaire lecture seule, aucun SDK réel',
    dataCategories: ['BankConnection mock, BankAccount ibanMasked FR76 ****, BankTransactionRaw hashDedup, rawData mock'],
    legalBasis: 'Contrat (préparation, pas de vraie banque)',
    retention: 'Mock uniquement, pas de vraie donnée bancaire, consent 90j mock',
    recipients: ['Famille uniquement, lecture seule'],
    securityMeasures: ['MOCK_ONLY=true', 'NO_REAL_SDK=true', 'READ_ONLY=true', 'ibanMasked **** jamais complet', 'aucun secret bancaire', 'validation humaine obligatoire'],
    familyIdIsolated: true,
    isDeletedExcluded: true,
  },
  {
    id: 'sync',
    name: 'Synchronisation PWA Dexie',
    purpose: 'Offline-first, sync Vercel+Neon',
    dataCategories: ['LocalTransaction syncStatus pending/synced/conflict, SyncQueue, ConflictLog'],
    legalBasis: 'Contrat + Intérêt légitime (offline)',
    retention: "SyncQueue jusqu'à synced, ConflictLog conserve trace même après résolution",
    recipients: ['Vercel API + Neon Postgres (familyId filtré)'],
    securityMeasures: ['Dexie where(familyId)', 'SyncQueue ne perd jamais donnée', 'ConflictLog localVersion/serverVersion', 'familyId isolé'],
    familyIdIsolated: true,
    isDeletedExcluded: true,
  },
];

export function verifyRegistry(): { check: string; status: boolean; details: string }[] {
  return REGISTRY.map(activity => ({
    check: `Registre ${activity.id}`,
    status: activity.familyIdIsolated && activity.isDeletedExcluded,
    details: `${activity.name}: ${activity.purpose} - familyId isolé: ${activity.familyIdIsolated}, isDeleted exclu: ${activity.isDeletedExcluded}, base légale: ${activity.legalBasis}`,
  }));
}
