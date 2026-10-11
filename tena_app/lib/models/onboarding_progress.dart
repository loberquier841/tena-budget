/// Progression du questionnaire d'onboarding, miroir de `packages/core/src/product/profile.ts`.
/// Stocké chiffré dans le localVault (SQLite) pour reprise après fermeture.
import '../models/user_profile.dart';

class OnboardingProgress {
  final String id;
  final int schemaVersion;
  final String status; // 'in-progress'
  final int currentStep;
  final String startedAt;
  final String updatedAt;
  final Map<String, dynamic> answers;
  final Map<String, dynamic> dashboard;

  const OnboardingProgress({
    this.id = 'primary',
    this.schemaVersion = 1,
    required this.status,
    required this.currentStep,
    required this.startedAt,
    required this.updatedAt,
    required this.answers,
    required this.dashboard,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schemaVersion': schemaVersion,
    'status': status,
    'currentStep': currentStep,
    'startedAt': startedAt,
    'updatedAt': updatedAt,
    'answers': answers,
    'dashboard': dashboard,
  };

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    if (json['id'] != 'primary' || json['schemaVersion'] != 1) {
      throw const FormatException('PROGRESS_SCHEMA_UNSUPPORTED');
    }
    if (json['status'] != 'in-progress') {
      throw const FormatException('PROGRESS_STATUS_INVALID');
    }
    final answers = Map<String, dynamic>.from(json['answers'] as Map);
    final dashboard = Map<String, dynamic>.from(json['dashboard'] as Map);
    return OnboardingProgress(
      status: json['status'] as String,
      currentStep: json['currentStep'] as int,
      startedAt: json['startedAt'] as String,
      updatedAt: json['updatedAt'] as String,
      answers: answers,
      dashboard: dashboard,
    );
  }

  /// Crée une progression initiale avec les valeurs par défaut.
  factory OnboardingProgress.initial() {
    final now = DateTime.now().toIso8601String();
    return OnboardingProgress(
      status: 'in-progress',
      currentStep: 1,
      startedAt: now,
      updatedAt: now,
      answers: {
        'householdMode': 'personal',
        'incomePattern': 'regular',
        'budgetExperience': 'starting',
        'priorities': ['understand-money'],
        'wantedFeatures': ['transactions', 'budgets', 'savings-goals'],
        'notificationPreference': 'balanced',
      },
      dashboard: {
        'visibleCards': ['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'],
        'compact': false,
      },
    );
  }

  /// Met à jour la progression avec de nouvelles réponses.
  OnboardingProgress copyWith({
    int? currentStep,
    Map<String, dynamic>? answers,
    Map<String, dynamic>? dashboard,
  }) {
    final now = DateTime.now().toIso8601String();
    return OnboardingProgress(
      id: id,
      schemaVersion: schemaVersion,
      status: status,
      currentStep: currentStep ?? this.currentStep,
      startedAt: startedAt,
      updatedAt: now,
      answers: answers ?? this.answers,
      dashboard: dashboard ?? this.dashboard,
    );
  }

  /// Convertit la progression en profil final complété.
  UserProfile toUserProfile() {
    final now = DateTime.now().toIso8601String();
    return UserProfile(
      createdAt: startedAt,
      updatedAt: now,
      completedAt: now,
      answers: Map<String, dynamic>.from(answers),
      dashboard: Map<String, dynamic>.from(dashboard),
    );
  }
}