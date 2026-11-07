import 'dart:convert';

import '../models/user_profile.dart';
import 'app_scope.dart';
import 'database_service.dart';

/// Accès local au profil. SQLite ne contient que le JSON chiffré AES-GCM.
class UserProfileService {
  static Future<UserProfile?> getProfile(
      {String userId = AppScope.activeUserId}) async {
    final payload = await DatabaseService.instance
        .getUserProfilePayload(userId: userId);
    if (payload == null) return null;
    try {
      return UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(payload) as Map),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('PROFILE_DATA_INVALID');
    }
  }

  static Future<void> saveProfile(UserProfile profile,
      {String userId = AppScope.activeUserId}) {
    return DatabaseService.instance.saveUserProfilePayload(
      jsonEncode(profile.toJson()),
      userId: userId,
    );
  }
}
