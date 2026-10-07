import 'dart:convert';

import '../models/user_profile.dart';
import 'database_service.dart';

/// Accès local au profil. SQLite ne contient que le JSON chiffré AES-GCM.
class UserProfileService {
  static Future<UserProfile?> getProfile() async {
    final payload = await DatabaseService.instance.getUserProfilePayload();
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

  static Future<void> saveProfile(UserProfile profile) {
    return DatabaseService.instance.saveUserProfilePayload(
      jsonEncode(profile.toJson()),
    );
  }
}
