/// Schéma JSON versionné compatible avec `packages/core/src/product/profile.ts`.
/// Les montants réels ne font pas partie du questionnaire.
class UserProfile {
  final String id;
  final int schemaVersion;
  final String createdAt;
  final String updatedAt;
  final String completedAt;
  final Map<String, dynamic> answers;
  final Map<String, dynamic> dashboard;

  const UserProfile({
    this.id = 'primary',
    this.schemaVersion = 1,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.answers,
    required this.dashboard,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'completedAt': completedAt,
    'answers': answers,
    'dashboard': dashboard,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    if (json['id'] != 'primary' || json['schemaVersion'] != 1) {
      throw const FormatException('PROFILE_SCHEMA_UNSUPPORTED');
    }
    final answers = Map<String, dynamic>.from(json['answers'] as Map);
    final dashboard = Map<String, dynamic>.from(json['dashboard'] as Map);
    if ((answers['priorities'] as List?)?.isEmpty ?? true) {
      throw const FormatException('PROFILE_PRIORITY_REQUIRED');
    }
    return UserProfile(
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      completedAt: json['completedAt'] as String,
      answers: answers,
      dashboard: dashboard,
    );
  }
}
