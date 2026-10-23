import { describe, expect, it } from 'vitest';
import { cardsForPriorities, createUserProfile, getProfileDashboardCards, recommendForProfile, updateUserProfile, validateOnboardingAnswers, type OnboardingAnswers } from './profile';

const answers: OnboardingAnswers = {
  householdMode: 'personal', incomePattern: 'variable', budgetExperience: 'some-habits',
  priorities: ['save', 'control-spending'], wantedFeatures: ['transactions', 'savings-goals', 'import-excel', 'bank-sync'],
  notificationPreference: 'balanced',
};

describe('questionnaire profile and product recommendations', () => {
  it('creates a versioned profile and places cards from priorities first', () => {
    const profile = createUserProfile(answers, new Date('2026-10-07T12:00:00.000Z'));
    expect(profile.schemaVersion).toBe(1);
    expect(profile.dashboard.visibleCards.slice(0, 3)).toEqual(['goals', 'spending', 'alerts']);
    expect(profile.answers.incomePattern).toBe('variable');
  });

  it('shows only cards supported by the selected priorities', () => {
    expect(cardsForPriorities(['understand-money'])).toEqual(['spending', 'recent-transactions']);
    expect(cardsForPriorities(['save'])).toEqual(['goals']);
    expect(cardsForPriorities(['prepare-expenses'])).toEqual(['spending']);
  });

  it('personalizes legacy profiles that were previously saved with every card', () => {
    const oldProfile = createUserProfile(answers);
    const legacyProfile = { ...oldProfile, dashboard: { ...oldProfile.dashboard, visibleCards: ['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'] as typeof oldProfile.dashboard.visibleCards } };
    expect(getProfileDashboardCards(legacyProfile)).toEqual(['goals', 'spending', 'alerts']);
  });

  it('separates available/partial needs from mock or planned features and never claims a paid unlock', () => {
    const recommendation = recommendForProfile(createUserProfile(answers));
    expect(recommendation.availableFeatures).toContain('import-excel');
    expect(recommendation.upcomingFeatures).toContain('bank-sync');
    expect(recommendation.offerProjection.tier).toBe('premium');
    expect(recommendation.offerProjection.availability).toBe('not-launched');
    expect(recommendation.offerProjection.priceConfigured).toBe(false);
    expect(recommendation.offerProjection.unlocksFeatures).toBe(false);
  });

  it('projects each planned family and future enterprise needs without presenting them as launched', () => {
    expect(recommendForProfile(createUserProfile({ ...answers, householdMode: 'family' })).offerProjection.tier).toBe('family');
    expect(recommendForProfile(createUserProfile({ ...answers, householdMode: 'business-later' })).offerProjection.availability).toBe('not-launched');
  });

  it('updates dashboard visibility while preserving the rest of the profile', () => {
    const profile = createUserProfile(answers);
    const updated = updateUserProfile(profile, { visibleCards: ['goals', 'recent-transactions'], compact: true });
    expect(updated.dashboard).toEqual({ visibleCards: ['goals', 'recent-transactions'], compact: true });
    expect(updated.answers).toEqual(profile.answers);
  });

  it('requires at least one goal/prioritization answer and rejects unknown features', () => {
    expect(() => validateOnboardingAnswers({ ...answers, priorities: [] })).toThrow('PROFILE_PRIORITY_REQUIRED');
    expect(() => validateOnboardingAnswers({ ...answers, wantedFeatures: ['fake-feature' as any] })).toThrow('PROFILE_FEATURE_INVALID');
  });
});
