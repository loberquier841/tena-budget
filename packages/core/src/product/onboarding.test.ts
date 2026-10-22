import { afterEach, describe, expect, it } from \"vitest\";
import {
  createUserProfile,
  validateOnboardingAnswers,
  recommendForProfile,
  type OnboardingAnswers,
} from \"./profile\";
import {
  activateLocalVault,
  createLocalVault,
  lockLocalVault,
} from \"../localVault\";
import {
  getLocalUserProfile,
  getLocalOnboardingProgress,
  saveLocalOnboardingProgress,
  saveLocalUserProfile,
} from \"../sync/dexie\";

const ANSWERS: OnboardingAnswers = {
  householdMode: \"personal\",
  incomePattern: \"variable\",
  budgetExperience: \"some-habits\",
  priorities: [\"save\", \"control-spending\"],
  wantedFeatures: [\"transactions\", \"savings-goals\", \"import-excel\"],
  notificationPreference: \"balanced\",
};

afterEach(() => lockLocalVault());

describe(\"onboarding: questionnaire → profil → persistance chiffrée\", () => {
  it(\"valide les réponses, crée le profil, le persiste et le relit depuis le coffre\", async () => {
    // 1. Créer et déverrouiller le coffre local (requis pour toute persistance)
    const passphrase = \"phrase de test onboarding 2026\";
    const { metadata, key } = await createLocalVault(passphrase);
    activateLocalVault(key);

    // 2. Valider les réponses du questionnaire avec la fonction métier du core
    expect(() => validateOnboardingAnswers(ANSWERS)).not.toThrow();

    // 3. Créer le profil avec la fonction métier du core
    const profile = createUserProfile(ANSWERS, new Date(\"2026-10-07T12:00:00.000Z\"));
    expect(profile.id).toBe(\"primary\");
    expect(profile.schemaVersion).toBe(1);
    expect(profile.completedAt).toBe(\"2026-10-07T12:00:00.000Z\");
    expect(profile.answers.householdMode).toBe(\"personal\");

    // 4. Persister le profil (chiffré dans le coffre)
    await saveLocalUserProfile(profile);

    // 5. Relire le profil depuis le coffre
    const restored = await getLocalUserProfile();
    expect(restored).toBeDefined();
    expect(restored!.answers.householdMode).toBe(\"personal\");
    expect(restored!.answers.priorities).toEqual([\"save\", \"control-spending\"]);
    expect(restored!.dashboard.visibleCards).toContain(\"goals\");
    expect(restored!.dashboard.visibleCards).toContain(\"spending\");
    expect(restored!.dashboard.visibleCards).toContain(\"alerts\");
  });

  it(\"recommande une offre sans la présenter comme déverrouillée\", async () => {
    const passphrase = \"phrase recommandation 2026\";
    const { key } = await createLocalVault(passphrase);
    activateLocalVault(key);

    const profile = createUserProfile(ANSWERS);
    const rec = recommendForProfile(profile);

    expect(rec.availableFeatures).toContain(\"transactions\");
    expect(rec.availableFeatures).toContain(\"savings-goals\");
    expect(rec.upcomingFeatures).toContain(\"import-excel\");
    expect(rec.offerProjection.tier).toBe(\"plus\");
    expect(rec.offerProjection.availability).toBe(\"not-launched\");
    expect(rec.offerProjection.priceConfigured).toBe(false);
    expect(rec.offerProjection.unlocksFeatures).toBe(false);
  });

  it(\"sauvegarde et restaure la progression intermédiaire du questionnaire\", async () => {
    const passphrase = \"phrase progression 2026\";
    const { key } = await createLocalVault(passphrase);
    activateLocalVault(key);

    const now = new Date(\"2026-10-07T12:00:00.000Z\").toISOString();
    const progress = {
      id: \"primary\" as const,
      schemaVersion: 1,
      status: \"in-progress\" as const,
      currentStep: 2,
      startedAt: now,
      updatedAt: now,
      answers: ANSWERS,
      dashboard: { visibleCards: [\"goals\", \"spending\"], compact: false },
    };

    await saveLocalOnboardingProgress(progress);
    const restored = await getLocalOnboardingProgress();

    expect(restored).toBeDefined();
    expect(restored!.status).toBe(\"in-progress\");
    expect(restored!.currentStep).toBe(2);
    expect(restored!.answers.householdMode).toBe(\"personal\");
    expect(JSON.stringify(restored)).not.toContain(\"variable\"); // chiffré au repos
  });

  it(\"rejette un profil avec un schéma non supporté\", async () => {
    const passphrase = \"phrase rejet 2026\";
    const { key } = await createLocalVault(passphrase);
    activateLocalVault(key);

    await expect(
      saveLocalUserProfile({ id: \"primary\", schemaVersion: 99 } as any)
    ).rejects.toThrow(\"PROFILE_SCHEMA_UNSUPPORTED\");
  });
});