export type HouseholdMode = 'personal' | 'couple' | 'family' | 'business-later';
export type IncomePattern = 'regular' | 'variable' | 'mixed' | 'prefer-not-to-say';
export type BudgetExperience = 'starting' | 'some-habits' | 'experienced';
export type NotificationPreference = 'essential' | 'balanced' | 'none';
export type UserPriority = 'understand-money' | 'control-spending' | 'save' | 'prepare-expenses' | 'manage-debt' | 'family-visibility';
export type ProductFeatureId = 'transactions' | 'budgets' | 'savings-goals' | 'forecast' | 'simulations' | 'import-csv' | 'import-excel' | 'export-reports' | 'documents' | 'bank-sync' | 'notifications' | 'price-comparator' | 'savings-assistant' | 'ai-assistant' | 'family-space' | 'business-space' | 'offline' | 'encrypted-backups';
export type DashboardCardId = 'spending' | 'goals' | 'recent-transactions' | 'alerts' | 'forecast';
export type OfferTier = 'free' | 'plus' | 'pro' | 'premium' | 'premium-plus' | 'family' | 'enterprise';

export interface OnboardingAnswers {
  householdMode: HouseholdMode;
  incomePattern: IncomePattern;
  budgetExperience: BudgetExperience;
  priorities: UserPriority[];
  wantedFeatures: ProductFeatureId[];
  notificationPreference: NotificationPreference;
}

export interface UserProfile {
  id: 'primary'; schemaVersion: 1; createdAt: string; updatedAt: string; completedAt: string;
  answers: OnboardingAnswers;
  dashboard: { visibleCards: DashboardCardId[]; compact: boolean };
}

/** Chiffré dans le même coffre que le profil final, afin de reprendre le questionnaire après fermeture. */
export interface OnboardingProgress {
  id: 'primary';
  schemaVersion: 1;
  status: 'in-progress';
  currentStep: number;
  startedAt: string;
  updatedAt: string;
  answers: OnboardingAnswers;
  dashboard: { visibleCards: DashboardCardId[]; compact: boolean };
}

export interface ProductCapability {
  id: ProductFeatureId; label: string;
  status: 'available-local' | 'partial' | 'mock-only' | 'planned';
  note: string;
}

export const PRODUCT_CAPABILITIES: readonly ProductCapability[] = [
  { id: 'transactions', label: 'Transactions manuelles', status: 'available-local', note: 'Création, consultation et corbeille locales.' },
  { id: 'budgets', label: 'Budgets', status: 'available-local', note: 'Enregistrés localement et calculés depuis les transactions.' },
  { id: 'savings-goals', label: 'Objectifs et versements', status: 'available-local', note: 'Persistés localement.' },
  { id: 'forecast', label: 'Prévisions', status: 'partial', note: 'Logique existante, intégration selon le client à terminer.' },
  { id: 'simulations', label: 'Simulations', status: 'partial', note: 'Core isolé des données réelles, interface à consolider.' },
  { id: 'import-csv', label: 'Import CSV', status: 'partial', note: 'Moteur existant, raccordement à la persistance à terminer.' },
  { id: 'import-excel', label: 'Import Excel', status: 'partial', note: 'Pipeline XLSX existant, raccordement à terminer.' },
  { id: 'export-reports', label: 'Exports et rapports', status: 'partial', note: 'Fonctions Core existantes, parcours client à terminer.' },
  { id: 'documents', label: 'Documents financiers', status: 'planned', note: 'Gestion complète non disponible.' },
  { id: 'bank-sync', label: 'Synchronisation bancaire', status: 'mock-only', note: 'Connecteur mock uniquement; aucune banque réelle.' },
  { id: 'notifications', label: 'Notifications et alertes', status: 'partial', note: 'Services et écrans partiels.' },
  { id: 'price-comparator', label: 'Comparateur de prix', status: 'partial', note: 'Interface présente, parcours réel à compléter.' },
  { id: 'savings-assistant', label: 'Aide aux économies', status: 'partial', note: 'Règles à consolider; aucune action automatique.' },
  { id: 'ai-assistant', label: 'TENΛ AI', status: 'partial', note: 'Assistant préparatoire, pas un conseil financier certifié.' },
  { id: 'family-space', label: 'Espace famille', status: 'partial', note: 'Permissions présentes, collaboration à construire.' },
  { id: 'business-space', label: 'Espace entreprise', status: 'planned', note: 'Phase future; aucune offre activée.' },
  { id: 'offline', label: 'Fonctionnement hors ligne', status: 'available-local', note: 'Données React conservées sur l’appareil.' },
  { id: 'encrypted-backups', label: 'Sauvegardes chiffrées', status: 'partial', note: 'Parcours local, parité des clients à poursuivre.' },
];

export interface OfferProjection { tier: OfferTier; availability: 'current' | 'not-launched'; reasons: string[]; priceConfigured: false; unlocksFeatures: false }
export interface ProfileRecommendations { availableFeatures: ProductFeatureId[]; upcomingFeatures: ProductFeatureId[]; dashboardCards: DashboardCardId[]; offerProjection: OfferProjection }
export const OFFER_CATALOG: readonly { tier: OfferTier; label: string; availability: 'current' | 'not-launched'; focus: string[]; priceConfigured: false; paymentVerified: false }[] = [
  { tier: 'free', label: 'Free', availability: 'current', focus: ['transactions', 'budgets', 'savings-goals', 'offline'], priceConfigured: false, paymentVerified: false },
  { tier: 'plus', label: 'Plus', availability: 'not-launched', focus: ['import-csv', 'import-excel', 'export-reports'], priceConfigured: false, paymentVerified: false },
  { tier: 'pro', label: 'Pro', availability: 'not-launched', focus: ['forecast', 'simulations', 'export-reports'], priceConfigured: false, paymentVerified: false },
  { tier: 'premium', label: 'Premium', availability: 'not-launched', focus: ['ai-assistant', 'price-comparator', 'savings-assistant'], priceConfigured: false, paymentVerified: false },
  { tier: 'premium-plus', label: 'Premium+', availability: 'not-launched', focus: ['ai-assistant', 'simulations', 'automation'], priceConfigured: false, paymentVerified: false },
  { tier: 'family', label: 'Famille', availability: 'not-launched', focus: ['family-space', 'shared-goals', 'member-permissions'], priceConfigured: false, paymentVerified: false },
  { tier: 'enterprise', label: 'Entreprise (future)', availability: 'not-launched', focus: ['business-space', 'accounting', 'team-permissions'], priceConfigured: false, paymentVerified: false },
];
const featureById = new Map(PRODUCT_CAPABILITIES.map(feature => [feature.id, feature]));
const allDashboardCards: DashboardCardId[] = ['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'];
export function validateOnboardingAnswers(answers: OnboardingAnswers): void {
  if (!['personal', 'couple', 'family', 'business-later'].includes(answers.householdMode)) throw new Error('PROFILE_HOUSEHOLD_INVALID');
  if (!['regular', 'variable', 'mixed', 'prefer-not-to-say'].includes(answers.incomePattern)) throw new Error('PROFILE_INCOME_PATTERN_INVALID');
  if (!['starting', 'some-habits', 'experienced'].includes(answers.budgetExperience)) throw new Error('PROFILE_EXPERIENCE_INVALID');
  if (!['essential', 'balanced', 'none'].includes(answers.notificationPreference)) throw new Error('PROFILE_NOTIFICATION_PREFERENCE_INVALID');
  if (!Array.isArray(answers.priorities) || !answers.priorities.length || answers.priorities.some(x => !['understand-money', 'control-spending', 'save', 'prepare-expenses', 'manage-debt', 'family-visibility'].includes(x))) throw new Error('PROFILE_PRIORITY_REQUIRED');
  if (!Array.isArray(answers.wantedFeatures) || answers.wantedFeatures.some(x => !featureById.has(x))) throw new Error('PROFILE_FEATURE_INVALID');
}

export function cardsForPriorities(priorities: UserPriority[]): DashboardCardId[] {
  const ordered: DashboardCardId[] = [];
  const add = (...items: DashboardCardId[]) => items.forEach(item => { if (!ordered.includes(item)) ordered.push(item); });
  for (const item of priorities) {
    if (item === 'understand-money') add('spending', 'recent-transactions');
    if (item === 'control-spending' || item === 'manage-debt') add('spending', 'alerts');
    if (item === 'save') add('goals');
    // La projection de trésorerie n'est pas encore intégrée au tableau de bord.
    // Pour cette priorité, montrer les dépenses et budgets qui aident déjà à
    // préparer les échéances, sans annoncer une prévision indisponible.
    if (item === 'prepare-expenses') add('spending');
    if (item === 'family-visibility') add('recent-transactions', 'goals');
  }
  // Les cartes présentes dans le profil correspondent à de vraies priorités.
  // Ne pas ajouter toutes les cartes ici : cela neutraliserait la personnalisation.
  return ordered;
}

/** Corrige à l'affichage les anciens profils qui avaient reçu toutes les cartes par défaut. */
export function getProfileDashboardCards(profile: Pick<UserProfile, 'answers' | 'dashboard'>): DashboardCardId[] {
  const selected = profile.dashboard.visibleCards;
  const hadUnpersonalizedDefault = selected.length === allDashboardCards.length &&
    allDashboardCards.every(card => selected.includes(card));
  return hadUnpersonalizedDefault ? cardsForPriorities(profile.answers.priorities) : selected;
}

export function createUserProfile(answers: OnboardingAnswers, now = new Date()): UserProfile {
  validateOnboardingAnswers(answers);
  const timestamp = now.toISOString();
  return { id: 'primary', schemaVersion: 1, createdAt: timestamp, updatedAt: timestamp, completedAt: timestamp,
    answers: { ...answers, priorities: [...new Set(answers.priorities)], wantedFeatures: [...new Set(answers.wantedFeatures)] },
    dashboard: { visibleCards: cardsForPriorities(answers.priorities), compact: false } };
}

export function updateUserProfile(profile: UserProfile, patch: { answers?: OnboardingAnswers; visibleCards?: DashboardCardId[]; compact?: boolean }, now = new Date()): UserProfile {
  const answers = patch.answers ?? profile.answers;
  validateOnboardingAnswers(answers);
  const visibleCards = patch.visibleCards ?? profile.dashboard.visibleCards;
  if (visibleCards.some(card => !allDashboardCards.includes(card))) throw new Error('PROFILE_DASHBOARD_CARD_INVALID');
  return { ...profile, updatedAt: now.toISOString(), completedAt: now.toISOString(),
    answers: { ...answers, priorities: [...new Set(answers.priorities)], wantedFeatures: [...new Set(answers.wantedFeatures)] },
    dashboard: { visibleCards: [...new Set(visibleCards)], compact: patch.compact ?? profile.dashboard.compact } };
}

export function recommendForProfile(profile: UserProfile): ProfileRecommendations {
  const wanted = new Set(profile.answers.wantedFeatures);
  const availableFeatures = [...wanted].filter(id => ['available-local', 'partial'].includes(featureById.get(id)?.status ?? ''));
  const upcomingFeatures = [...wanted].filter(id => ['planned', 'mock-only'].includes(featureById.get(id)?.status ?? ''));
  let tier: OfferTier = 'free';
  const reasons: string[] = [];
  if (profile.answers.householdMode === 'family') { tier = 'family'; reasons.push('Tu as indiqué gérer un foyer familial.'); }
  else if (profile.answers.householdMode === 'business-later') { tier = 'enterprise'; reasons.push('Tu as indiqué un intérêt professionnel futur.'); }
  else if (wanted.has('ai-assistant') || wanted.has('simulations') || wanted.has('bank-sync')) {
    tier = wanted.has('simulations') && wanted.has('ai-assistant') ? 'premium-plus' : 'premium';
    reasons.push('Tu as choisi des fonctions avancées comme l’analyse, les simulations ou la banque.');
  } else if (wanted.has('forecast') || wanted.has('import-excel') || wanted.has('export-reports')) {
    tier = profile.answers.budgetExperience === 'experienced' ? 'pro' : 'plus';
    reasons.push('Tes besoins incluent les projections ou l’import et l’analyse de données.');
  } else reasons.push('Les fonctions personnelles de base correspondent à ton besoin actuel.');
  if (tier !== 'free') reasons.push('Projection produit uniquement : formule, prix et déverrouillage non disponibles.');
  return { availableFeatures, upcomingFeatures, dashboardCards: profile.dashboard.visibleCards,
    offerProjection: { tier, availability: tier === 'free' ? 'current' : 'not-launched', reasons, priceConfigured: false, unlocksFeatures: false } };
}
