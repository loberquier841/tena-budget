import 'dart:convert';

import '../services/crypto_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';

class CategoryService {
  static const String _baseKey = 'tena_budget_categories';

  static String _key(String userId) => '${_baseKey}_$userId';

  static const List<String> defaultCategories = [
    'Alimentation',
    'Transport',
    'Logement',
    'Loisirs',
    'Shopping',
    'Abonnements',
    'Santé',
    'Éducation',
    'Cadeaux',
    'Voyages',
    'Salaire',
    'Autres',
  ];

  static Future<List<String>> getCategories(
      {String userId = AppScope.activeUserId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId);

    final raw = prefs.getString(key);
    // Compat lecture mono-profil historique: clé non scopée -> migrée en mémoire
    // vers le scope actif au premier save explicite (pas d'écrasement silencieux).
    final legacyRaw = userId == AppScope.activeUserId ? prefs.getString(_baseKey) : null;
    final effectiveRaw = (raw == null || raw.isEmpty) ? legacyRaw : raw;

    if (effectiveRaw == null || effectiveRaw.isEmpty) {
      final enc = await CryptoService.encrypt(jsonEncode(defaultCategories));
      await prefs.setString(key, enc);
      if (userId == AppScope.activeUserId) {
        await prefs.setString(_baseKey, enc); // compat legacy key (tests/anciens accès)
      }
      return List<String>.from(defaultCategories);
    }

    try {
      final decrypted = await CryptoService.decrypt(effectiveRaw);
      final categories = jsonDecode(decrypted) as List;
      final result = List<String>.from(categories.cast<String>());
      if (raw == null || raw.isEmpty) {
        // migration douce de la clé legacy vers le scope
        await prefs.setString(key, await CryptoService.encrypt(jsonEncode(result)));
      }
      return result;
    } catch (_) {
      try {
        final categories = prefs.getStringList(key) ?? prefs.getStringList(_baseKey);
        if (categories != null && categories.isNotEmpty) {
          return List<String>.from(categories);
        }
      } catch (_) {}
      return List<String>.from(defaultCategories);
    }
  }

  static Future<void> saveCategories(
    List<String> categories, {
    String userId = AppScope.activeUserId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enc = await CryptoService.encrypt(jsonEncode(categories));
    await prefs.setString(_key(userId), enc);
    if (userId == AppScope.activeUserId) {
      await prefs.setString(_baseKey, enc); // compat legacy key
    }
  }

  static Future<void> addCategory(String category,
      {String userId = AppScope.activeUserId}) async {
    final categories = await getCategories(userId: userId);
    final name = category.trim();
    if (name.isEmpty) return;
    if (categories.any((item) => item.toLowerCase() == name.toLowerCase())) {
      return;
    }
    categories.add(name);
    await saveCategories(categories, userId: userId);
  }

  static Future<void> deleteCategory(String category,
      {String userId = AppScope.activeUserId}) async {
    final categories = await getCategories(userId: userId);
    categories.remove(category);
    await saveCategories(categories, userId: userId);
  }

  static Future<void> renameCategory(
    String oldName,
    String newName, {
    String userId = AppScope.activeUserId,
  }) async {
    final categories = await getCategories(userId: userId);
    final index = categories.indexOf(oldName);
    if (index == -1) return;
    final name = newName.trim();
    if (name.isEmpty) return;
    if (categories.any(
        (item) => item.toLowerCase() == name.toLowerCase() && item != oldName)) {
      return;
    }
    categories[index] = name;
    await saveCategories(categories, userId: userId);
  }
}

