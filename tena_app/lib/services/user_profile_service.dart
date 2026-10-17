import 'dart:convert';

import '../models/user_profile.dart';
import 'database_service.dart';

/// Accès local au profil. SQLite ne contient que le JSON chiffré AES-GCM.
class UserProfileService {
  static UserProfileService _instance = UserProfileService._internal();

  UserProfileService._internal();

  Future<UserProfile?> _getProfile() async {
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

  Future<void> saveProfile(UserProfile profile) async {
    return DatabaseService.instance.saveUserProfilePayload(
      jsonEncode(profile.toJson()),
    );
  }

  static Future<UserProfile?> getProfile() async => _instance._getProfile();
  static Future<void> saveProfile(UserProfile profile) async =>
      _instance.saveProfile(profile);

  /// For testing: set a custom instance.
  static void setInstance(UserProfileService instance) {
    _instance = instance;
  }

  /// For testing: reset to the default instance.
  static void reset() {
    _instance = UserProfileService._internal();
  }
}
