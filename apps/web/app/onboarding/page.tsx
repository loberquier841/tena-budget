'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import {
  createUserProfile,
  validateOnboardingAnswers,
  recommendForProfile,
  type OnboardingAnswers,
  type UserPriority,
  type ProductFeatureId,
  type HouseholdMode,
  type IncomePattern,
  type BudgetExperience,
  type NotificationPreference,
  type DashboardCardId,
} from '@tena/core';
import { createLocalVault, activateLocalVault } from '@/lib/tena-core-shims';
import {
  saveLocalUserProfile,
  getLocalUserProfile,
  saveLocalOnboardingProgress,
  getLocalOnboardingProgress,
} from '@/lib/tena-core-dexie';

type OnboardingStep =
  | 'vault'
  | 'householdMode'
  | 'incomePattern'
  | 'budgetExperience'
  | 'priorities'
  | 'wantedFeatures'
  | 'notificationPreference'
  | 'summary'
  | 'done';

const STEP_LABELS: Record<OnboardingStep, string> = {
  vault: 'Coffre de chiffrement local',
  householdMode: 'Votre foyer',
  incomePattern: 'Vos revenus',
  budgetExperience: 'Votre expérience budget',
  priorities: 'Vos priorités',
  wantedFeatures: 'Fonctions souhaitées',
  notificationPreference: 'Notifications',
  summary: 'Récapitulatif',
  done: 'Terminé',
};

const TOTAL_STEPS = 8;

const EMPTY_ANSWERS: Partial<OnboardingAnswers> = {
  householdMode: undefined,
  incomePattern: undefined,
  budgetExperience: undefined,
  priorities: [],
  wantedFeatures: [],
  notificationPreference: undefined,
};

const HOUSEHOLD_MODES: { value: HouseholdMode; label: string; desc: string }[] = [
  { value: 'personal', label: 'Personnel', desc: 'Je gère mes finances seul(e)' },
  { value: 'couple', label: 'Couple', desc: 'Nous gérons nos finances à deux' },
  { value: 'family', label: 'Famille', desc: 'Je gère un foyer familial' },
  { value: 'business-later', label: 'Professionnel (à venir)', desc: 'Intérêt pour une utilisation professionnelle future' },
];

const INCOME_PATTERNS: { value: IncomePattern; label: string; desc: string }[] = [
  { value: 'regular', label: 'Revenus réguliers', desc: 'Salaire fixe ou revenus prévisibles' },
  { value: 'variable', label: 'Revenus variables', desc: 'Freelance, commissions, revenus irréguliers' },
  { value: 'mixed', label: 'Revenus mixtes', desc: 'Partie fixe + partie variable' },
  { value: 'prefer-not-to-say', label: 'Je préfère ne pas le dire', desc: '' },
];

const BUDGET_EXPERIENCES: { value: BudgetExperience; label: string; desc: string }[] = [
  { value: 'starting', label: 'Débutant(e)', desc: 'Je commence à budgétiser' },
  { value: 'some-habits', label: 'Quelques habitudes', desc: 'Je fais déjà un suivi occasionnel' },
  { value: 'experienced', label: 'Expérimenté(e)', desc: 'Je budgétise régulièrement et précisément' },
];

const PRIORITIES: { value: UserPriority; label: string; desc: string }[] = [
  { value: 'understand-money', label: 'Comprendre mon argent', desc: 'Savoir où va chaque euro' },
  { value: 'control-spending', label: 'Contrôler mes dépenses', desc: 'Éviter les achats impulsifs' },
  { value: 'save', label: 'Épargner', desc: 'Constituer une épargne de précaution' },
  { value: 'prepare-expenses', label: 'Préparer mes dépenses', desc: 'Anticiper les factures à venir' },
  { value: 'manage-debt', label: 'Gérer mes dettes', desc: 'Rembourser crédits et dettes' },
  { value: 'family-visibility', label: 'Visibilité familiale', desc: 'Partager la vue d\'ensemble en famille' },
];

const WANTED_FEATURES: { value: ProductFeatureId; label: string; desc: string }[] = [
  { value: 'transactions', label: 'Transactions manuelles', desc: 'Saisir et catégoriser mes dépenses' },
  { value: 'budgets', label: 'Budgets', desc: 'Fixer des limites par catégorie' },
  { value: 'savings-goals', label: 'Objectifs d\'épargne', desc: 'Suivre mes objectifs financiers' },
  { value: 'forecast', label: 'Prévisions', desc: 'Projeter ma trésorerie future' },
  { value: 'simulations', label: 'Simulations', desc: 'Tester des scénarios financiers' },
  { value: 'import-csv', label: 'Import CSV', desc: 'Importer mes relevés bancaires' },
  { value: 'import-excel', label: 'Import Excel', desc: 'Importer des fichiers Excel' },
  { value: 'export-reports', label: 'Exports et rapports', desc: 'Exporter mes données' },
  { value: 'offline', label: 'Hors ligne', desc: 'Utiliser l\'application sans internet' },
  { value: 'encrypted-backups', label: 'Sauvegardes chiffrées', desc: 'Sauvegarder et restaurer mes données' },
];

const NOTIFICATION_PREFERENCES: { value: NotificationPreference; label: string; desc: string }[] = [
  { value: 'essential', label: 'Essentielles uniquement', desc: 'Alertes importantes seulement' },
  { value: 'balanced', label: 'Équilibré', desc: 'Résumé régulier, pas d\'excès' },
  { value: 'none', label: 'Aucune', desc: 'Je ne veux pas de notifications' },
];

export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState<OnboardingStep>('vault');
  const [answers, setAnswers] = useState<Partial<OnboardingAnswers>>({ ...EMPTY_ANSWERS });
  const [passphrase, setPassphrase] = useState('');
  const [passphraseConfirm, setPassphraseConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [profile, setProfile] = useState<any>(null);
  const [recommendation, setRecommendation] = useState<any>(null);
  const [vaultReady, setVaultReady] = useState(false);

  useEffect(() => {
    let mounted = true;
    async function restore() {
      try {
        const existing = await getLocalUserProfile();
        if (existing) {
          router.replace('/dashboard');
          return;
        }
        const progress = await getLocalOnboardingProgress();
        if (progress && progress.answers) {
          setAnswers({ ...progress.answers });
          const steps: OnboardingStep[] = [
            'householdMode', 'incomePattern', 'budgetExperience', 'priorities',
            'wantedFeatures', 'notificationPreference', 'summary',
          ];
          const nextStepIndex = Math.min(Math.max(progress.currentStep, 1), TOTAL_STEPS - 1);
          if (nextStepIndex < steps.length) {
            setStep(steps[nextStepIndex]);
          }
        }
      } catch (err: any) {
        if (mounted) setError(err.message || 'Erreur de restauration');
      }
    }
    restore();
    return () => { mounted = false; };
  }, [router]);

  const handleVaultCreate = useCallback(async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (passphrase.trim().length < 12) {
      setError('Le passphrase doit contenir au moins 12 caractères.');
      return;
    }
    if (passphrase !== passphraseConfirm) {
      setError('Les passphrases ne correspondent pas.');
      return;
    }
    setIsLoading(true);
    try {
      const { metadata, key } = await createLocalVault(passphrase);
      activateLocalVault(key);
      setVaultReady(true);
      setStep('householdMode');
      const now = new Date().toISOString();
      await saveLocalOnboardingProgress({
        id: 'primary',
        schemaVersion: 1,
        status: 'in-progress',
        currentStep: 0,
        startedAt: now,
        updatedAt: now,
        answers: { ...EMPTY_ANSWERS } as OnboardingAnswers,
        dashboard: { visibleCards: [], compact: false },
      });
    } catch (err: any) {
      setError(err.message || 'Impossible de créer le coffre de chiffrement.');
    } finally {
      setIsLoading(false);
    }
  }, [passphrase, passphraseConfirm]);

  const saveProgress = useCallback(async (currentStepIndex: number) => {
    if (!vaultReady) return;
    try {
      const now = new Date().toISOString();
      await saveLocalOnboardingProgress({
        id: 'primary',
        schemaVersion: 1,
        status: 'in-progress',
        currentStep: currentStepIndex,
        startedAt: (answers as any).startedAt ?? now,
        updatedAt: now,
        answers: answers as OnboardingAnswers,
        dashboard: { visibleCards: [], compact: false },
      });
    } catch (err: any) {
      setError(err.message || 'Erreur de sauvegarde de progression.');
    }
  }, [vaultReady, answers]);

  const goNext = useCallback(async () => {
    setError(null);
    const steps: OnboardingStep[] = [
      'householdMode', 'incomePattern', 'budgetExperience', 'priorities',
      'wantedFeatures', 'notificationPreference', 'summary',
    ];
    const currentIndex = steps.indexOf(step);
    if (currentIndex < 0 || currentIndex >= steps.length - 1) return;
    const nextStep = steps[currentIndex + 1];
    await saveProgress(currentIndex + 1);
    setStep(nextStep);
  }, [step, answers, saveProgress]);

  const goPrevious = useCallback(() => {
    setError(null);
    const steps: OnboardingStep[] = [
      'vault', 'householdMode', 'incomePattern', 'budgetExperience', 'priorities',
      'wantedFeatures', 'notificationPreference', 'summary',
    ];
    const currentIndex = steps.indexOf(step);
    if (currentIndex > 0) setStep(steps[currentIndex - 1]);
  }, [step]);

  const handleFinish = useCallback(async () => {
    setError(null);
    setIsLoading(true);
    try {
      validateOnboardingAnswers(answers as OnboardingAnswers);
      const newProfile = createUserProfile(answers as OnboardingAnswers);
      await saveLocalUserProfile(newProfile);
      const rec = recommendForProfile(newProfile);
      setProfile(newProfile);
      setRecommendation(rec);
      setStep('done');
    } catch (err: any) {
      setError(err.message || 'Impossible de créer le profil.');
    } finally {
      setIsLoading(false);
    }
  }, [answers]);

  if (step === 'vault') {
    return (
      <main style={{ padding: 24, maxWidth: 480, margin: '0 auto', background: '#fafafa', minHeight: '100vh' }}>
        <h1 style={{ fontSize: 26, marginBottom: 8 }}>TENΛ Budget — Onboarding</h1>
        <p style={{ color: '#666', marginBottom: 24 }}>
          Protégez vos données financières avec un coffre de chiffrement local (AES-GCM, PBKDF2).
          Ce passphrase est nécessaire pour déverrouiller vos données à chaque session.
        </p>
        {error && <p style={{ color: '#ef4444', marginBottom: 16 }}>{error}</p>}
        <form onSubmit={handleVaultCreate} style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontWeight: 600, marginBottom: 6 }}>Passphrase de démarrage</label>
            <input
              type="password"
              value={passphrase}
              onChange={e => setPassphrase(e.target.value)}
              placeholder="Au moins 12 caractères"
              style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #e5e7eb', fontSize: 14, boxSizing: 'border-box' }}
              required
              minLength={12}
            />
            <p style={{ fontSize: 11, color: '#888', marginTop: 4 }}>Ce passphrase chiffre vos données locales. Sans lui, TENΛ ne peut pas les déchiffrer.</p>
          </div>
          <div style={{ marginBottom: 20 }}>
            <label style={{ display: 'block', fontWeight: 600, marginBottom: 6 }}>Confirmer le passphrase</label>
            <input
              type="password"
              value={passphraseConfirm}
              onChange={e => setPassphraseConfirm(e.target.value)}
              placeholder="Retapez le passphrase"
              style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #e5e7eb', fontSize: 14, boxSizing: 'border-box' }}
              required
            />
          </div>
          <button
            type="submit"
            disabled={isLoading}
            style={{ background: '#7C3AED', color: 'white', padding: '10px 20px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 14, fontWeight: 600, width: '100%' }}
          >
            {isLoading ? 'Création du coffre…' : 'Créer le coffre et continuer'}
          </button>
        </form>
        <p style={{ marginTop: 16, fontSize: 12, color: '#888' }}>
          TENΛ Budget — local-first. Aucune donnée n'est envoyée à un serveur durant l'onboarding.
        </p>
      </main>
    );
  }

  if (step === 'summary' || step === 'done') {
    const completedAnswers = answers as OnboardingAnswers;
    const cards = recomputeCards(completedAnswers.priorities);
    return (
      <main style={{ padding: 24, maxWidth: 480, margin: '0 auto', background: '#fafafa', minHeight: '100vh' }}>
        <h1 style={{ fontSize: 26, marginBottom: 16 }}>{step === 'done' ? 'Profil créé !' : 'Récapitulatif avant validation'}</h1>
        {step === 'summary' ? (
          <>
            <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginBottom: 16 }}>
              <h2 style={{ fontSize: 16, marginBottom: 12 }}>Vos réponses</h2>
              <dl style={{ display: 'grid', gridTemplateColumns: '140px 1fr', gap: 8, fontSize: 13 }}>
                <dt>Foyer</dt><dd>{completedAnswers.householdMode}</dd>
                <dt>Revenus</dt><dd>{completedAnswers.incomePattern}</dd>
                <dt>Expérience budget</dt><dd>{completedAnswers.budgetExperience}</dd>
                <dt>Priorités</dt><dd>{completedAnswers.priorities.join(', ')}</dd>
                <dt>Fonctions</dt><dd>{completedAnswers.wantedFeatures.join(', ')}</dd>
                <dt>Notifications</dt><dd>{completedAnswers.notificationPreference}</dd>
              </dl>
            </div>
            <div style={{ display: 'flex', gap: 12 }}>
              <button onClick={goPrevious} style={{ padding: '10px 20px', borderRadius: 8, border: '1px solid #e5e7eb', background: 'white', cursor: 'pointer' }}>Modifier</button>
              <button onClick={handleFinish} disabled={isLoading} style={{ background: '#7C3AED', color: 'white', padding: '10px 20px', borderRadius: 8, border: 'none', cursor: 'pointer', fontWeight: 600 }}>Créer mon profil</button>
            </div>
            {isLoading && <p style={{ marginTop: 12, fontSize: 12, color: '#666' }}>Création du profil en cours…</p>}
            {error && <p style={{ marginTop: 12, color: '#ef4444' }}>{error}</p>}
          </>
        ) : (
          <>
            <div style={{ background: '#f0fdf4', padding: 20, borderRadius: 12, border: '1px solid #bbf7d0', marginBottom: 16 }}>
              <h2 style={{ fontSize: 16, color: '#166534', marginBottom: 8 }}>Votre profil est prêt</h2>
              <p style={{ fontSize: 13, color: '#166534', margin: 0 }}>
                Votre profil local a été créé et chiffré. Votre tableau de bord affichera les cartes :
                <strong>{cards.join(', ') || 'aucune'}</strong>.
              </p>
            </div>
            {recommendation && (
              <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginBottom: 16 }}>
                <h2 style={{ fontSize: 16, marginBottom: 8 }}>Projection d'offre produit</h2>
                <p style={{ fontSize: 13, marginBottom: 8 }}><strong>Niveau projeté :</strong> {recommendation.offerProjection.tier}</p>
                <p style={{ fontSize: 13, marginBottom: 8 }}><strong>Disponibilité :</strong> {recommendation.offerProjection.availability}</p>
                <p style={{ fontSize: 13, marginBottom: 8 }}><strong>Raisons :</strong> {recommendation.offerProjection.reasons.join(' ')}</p>
                <p style={{ fontSize: 12, color: '#666', marginBottom: 0 }}>
                  {recommendation.offerProjection.priceConfigured ? '' : 'Note : formule, prix et déverrouillage non disponibles (projection produit uniquement).'}
                </p>
                <ul style={{ fontSize: 12, color: '#666', marginTop: 8 }}>
                  <li>Fonctions disponibles : {recommendation.availableFeatures.join(', ') || 'aucune'}</li>
                  <li>Fonctions à venir : {recommendation.upcomingFeatures.join(', ') || 'aucune'}</li>
                </ul>
              </div>
            )}
            <div style={{ display: 'flex', gap: 12 }}>
              <button onClick={goPrevious} style={{ padding: '10px 20px', borderRadius: 8, border: '1px solid #e5e7eb', background: 'white', cursor: 'pointer' }}>Modifier mes réponses</button>
              <button onClick={() => router.push('/dashboard')} style={{ background: '#7C3AED', color: 'white', padding: '10px 20px', borderRadius: 8, border: 'none', cursor: 'pointer', fontWeight: 600 }}>Accéder au tableau de bord</button>
            </div>
          </>
        )}
      </main>
    );
  }

  const currentStepLabel = STEP_LABELS[step];
  const stepIndex = [
    'vault', 'householdMode', 'incomePattern', 'budgetExperience', 'priorities',
    'wantedFeatures', 'notificationPreference', 'summary',
  ].indexOf(step);

  const renderField = () => {
    if (step === 'householdMode') {
      return (
        <>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 16 }}>
            Qui gérez-vous dans TENΛ Budget ? Cela aide à adapter votre expérience et à projeter l'offre adaptée.
          </p>
          {HOUSEHOLD_MODES.map(opt => (
            <label
              key={opt.value}
              style={{ display: 'block', padding: 12, marginBottom: 10, borderRadius: 8, border: '1px solid #e5e7eb', cursor: 'pointer', background: answers.householdMode === opt.value ? '#f3e8ff' : 'white' }}
              onClick={() => setAnswers({ ...answers, householdMode: opt.value })}
            >
              <strong>{opt.label}</strong> — {opt.desc}
            </label>
          ))}
        </>
      );
    }
    if (step === 'incomePattern') {
      return (
        <>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 16 }}>
            Comment décririez-vous vos revenus ? Cette information n'est utilisée que pour l'adaptation de l'expérience.
          </p>
          {INCOME_PATTERNS.map(opt => (
            <label
              key={opt.value}
              style={{ display: 'block', padding: 12, marginBottom: 10, borderRadius: 8, border: '1px solid #e5e7eb', cursor: 'pointer', background: answers.incomePattern === opt.value ? '#f3e8ff' : 'white' }}
              onClick={() => setAnswers({ ...answers, incomePattern: opt.value })}
            >
              <strong>{opt.label}</strong> — {opt.desc}
            </label>
          ))}
        </>
      );
    }
    if (step === 'budgetExperience') {
      return (
        <>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 16 }}>
            Quel est votre niveau d'expérience avec le budget ?
          </p>
          {BUDGET_EXPERIENCES.map(opt => (
            <label
              key={opt.value}
              style={{ display: 'block', padding: 12, marginBottom: 10, borderRadius: 8, border: '1px solid #e5e7eb', cursor: 'pointer', background: answers.budgetExperience === opt.value ? '#f3e8ff' : 'white' }}
              onClick={() => setAnswers({ ...answers, budgetExperience: opt.value })}
            >
              <strong>{opt.label}</strong> — {opt.desc}
            </label>
          ))}
        </>
      );
    }
    if (step === 'priorities') {
      return (
        <>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 16 }}>
            Sélectionnez une ou plusieurs priorités. Elles déterminent les cartes affichées sur votre tableau de bord.
          </p>
          {PRIORITIES.map(opt => {
            const selected = answers.priorities?.includes(opt.value);
            return (
              <label
                key={opt.value}
                style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 12, marginBottom: 10, borderRadius: 8, border: '1px solid #e5e7eb', cursor: 'pointer', background: selected ? '#f3e8ff' : 'white' }}
                onClick={() => {
                  const current = answers.priorities ?? [];
                  const next = selected ? current.filter(p => p !== opt.value) : [...current, opt.value];
                  setAnswers({ ...answers, priorities: next });
                }}
              >
                <input type="checkbox" defaultChecked={selected} readOnly style={{ width: 18, height: 18 }} />
                <div>
                  <strong>{opt.label}</strong><br />
                  <span style={{ fontSize: 11, color: '#666' }}>{opt.desc}</span>
                </div>
              </label>
            );
          })}
          <p style={{ fontSize: 12, color: '#888', marginTop: 8 }}>
            Au moins une priorité est requise.
          </p>
        </>
      );
    }
    if (step === 'wantedFeatures') {
      return (
        <>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 16 }}>
            Quelles fonctions souhaitez-vous utiliser ? Certaines sont disponibles immédiatement, d'autres sont en projet.
          </p>
          {WANTED_FEATURES.map(opt => {
            const selected = answers.wantedFeatures?.includes(opt.value);
            return (
              <label
                key={opt.value}
                style={{ display: 'flex', alignItems: 'center', gap: 10, padding: 12, marginBottom: 10, borderRadius: 8, border: '1px solid #e5e7eb', cursor: 'pointer', background: selected ? '#f3e8ff' : 'white' }}
                onClick={() => {
                  const current = answers.wantedFeatures ?? [];
                  const next = selected ? current.filter(f => f !== opt.value) : [...current, opt.value];
                  setAnswers({ ...answers, wantedFeatures: next });
                }}
              >
                <input type="checkbox" defaultChecked={selected} readOnly style={{ width: 18, height: 18 }} />
                <div>
                  <strong>{opt.label}</strong><br />
                  <span style={{ fontSize: 11, color: '#666' }}>{opt.desc}</span>
                </div>
              </label>
            );
          })}
        </>
      );
    }
    if (step === 'notificationPreference') {
      return (
        <>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 16 }}>
            À quelle fréquence souhaitez-vous recevoir des notifications ?
          </p>
          {NOTIFICATION_PREFERENCES.map(opt => (
            <label
              key={opt.value}
              style={{ display: 'block', padding: 12, marginBottom: 10, borderRadius: 8, border: '1px solid #e5e7eb', cursor: 'pointer', background: answers.notificationPreference === opt.value ? '#f3e8ff' : 'white' }}
              onClick={() => setAnswers({ ...answers, notificationPreference: opt.value })}
            >
              <strong>{opt.label}</strong> — {opt.desc}
            </label>
          ))}
        </>
      );
    }
    return null;
  };

  const canNext = () => {
    switch (step) {
      case 'householdMode': return !!answers.householdMode;
      case 'incomePattern': return !!answers.incomePattern;
      case 'budgetExperience': return !!answers.budgetExperience;
      case 'priorities': return !!(answers.priorities?.length);
      case 'wantedFeatures': return true;
      case 'notificationPreference': return !!answers.notificationPreference;
      default: return true;
    }
  };

  return (
    <main style={{ padding: 24, maxWidth: 600, margin: '0 auto', background: '#fafafa', minHeight: '100vh' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <h1 style={{ fontSize: 20, margin: 0 }}>TENΛ Budget — Onboarding</h1>
        <span style={{ fontSize: 12, color: '#666' }}>Étape {stepIndex + 1} / {TOTAL_STEPS}</span>
      </div>
      <div style={{ background: '#e5e7eb', height: 6, borderRadius: 3, marginBottom: 24, overflow: 'hidden' }}>
        <div style={{ width: `${((stepIndex + 1) / TOTAL_STEPS) * 100}%`, height: '100%', background: '#7C3AED' }}></div>
      </div>
      <h2 style={{ fontSize: 18, marginBottom: 8 }}>{currentStepLabel}</h2>
      {error && <p style={{ color: '#ef4444', marginBottom: 16 }}>{error}</p>}
      <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
        {renderField()}
      </div>
      <div style={{ display: 'flex', gap: 12, marginTop: 20, justifyContent: 'space-between' }}>
        {stepIndex > 0 && (
          <button onClick={goPrevious} style={{ padding: '10px 20px', borderRadius: 8, border: '1px solid #e5e7eb', background: 'white', cursor: 'pointer' }}>
            ← Précédent
          </button>
        )}
        <button
          onClick={goNext}
          disabled={!canNext()}
          style={{ background: canNext() ? '#7C3AED' : '#c4b5fd', color: 'white', padding: '10px 20px', borderRadius: 8, border: 'none', cursor: canNext() ? 'pointer' : 'not-allowed', fontWeight: 600 }}
        >
          {step === 'notificationPreference' ? 'Voir le récapitulatif' : 'Suivant →'}
        </button>
      </div>
    </main>
  );
}

function recomputeCards(priorities: UserPriority[]): DashboardCardId[] {
  const ordered: DashboardCardId[] = [];
  const allCards: DashboardCardId[] = ['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'];
  const add = (...items: DashboardCardId[]) => items.forEach(item => { if (!ordered.includes(item)) ordered.push(item); });
  for (const item of priorities) {
    if (item === 'understand-money') add('spending', 'recent-transactions');
    if (item === 'control-spending' || item === 'manage-debt') add('spending', 'alerts');
    if (item === 'save') add('goals');
    if (item === 'prepare-expenses') add('forecast', 'spending');
    if (item === 'family-visibility') add('recent-transactions', 'goals');
  }
  add(...allCards);
  return ordered;
}
