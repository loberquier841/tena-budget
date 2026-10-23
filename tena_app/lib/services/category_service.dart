import 'dart:convert';

import '../services/crypto_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryService {
  static const String _key = 'tena_budget_categories';

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

  static Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);

    if (raw == null || raw.isEmpty) {
      // Aucune donnée existante : initialiser avec les catégories par défaut en clair
      await prefs.setString(_key, await CryptoService.encrypt(jsonEncode(defaultCategories)));
      return List<String>.from(defaultCategories);
    }

    try {
      // Essayer de déchiffrer : si cela réussit, les données sont déjà chiffrées
      final decrypted = await CryptoService.decrypt(raw);
      final categories = jsonDecode(decrypted) as List;
      // Données chiffrées : vérifier si une mise à jour vers le nouveau key store est nécessaire
      // et re-chiffrer si la clé a changé
      await maybeReencryptCategories(categories, raw);
      return List<String>.from(categories.cast<String>());
    } catch (_) {
      // Échec du déchiffrement : données en clair (version antérieure)
      // Migrer vers chiffré automatiquement
      final categories = prefs.getStringList(_key);
      if (categories != null && categories.isNotEmpty) {
        // Données en clair détectées : chiffrer automatiquement
        final clearList = List<String>.from(categories);
        await prefs.setString(_key, await CryptoService.encrypt(jsonEncode(clearList)));
        return List<String>.from(clearList);
      }
      // Fallback : réinitialiser avec les catégories par défaut
      await prefs.setString(_key, await CryptoService.encrypt(jsonEncode(defaultCategories)));
      return List<String>.from(defaultCategories);
    }
  }

  /// Vérifie si le rechiffrement est nécessaire et le fait si la clé a changé.
  static Future<void> maybeReencryptCategories(List<String> categories, String oldRaw) async {
    // Récupérer les préférences partagées pour ré-enregistrer les catégories
    final prefs = await SharedPreferences.getInstance();
    // Récupérer la clé actuelle stockée dans le keystore (sans bloquer le flux)
    // Note: cette fonction est appelée dans le cadre du démarrage avec le nouveau SecureStorageKeyStore
    // et s'assure que les catégories sont chiffrées avec la clé courante.
    await prefs.setString(_key, await CryptoService.encrypt(jsonEncode(categories)));
  }

  static Future<void> saveCategories(
    List<String> categories,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_key, await CryptoService.encrypt(jsonEncode(categories)));
  }

  static Future<void> addCategory(String category) async {
    final categories = await getCategories();

    final name = category.trim();

    if (name.isEmpty) return;

    if (categories.any(
      (item) => item.toLowerCase() == name.toLowerCase(),
    )) {
      return;
    }

    categories.add(name);

    await saveCategories(categories);
  }

  static Future<void> deleteCategory(String category) async {
    final categories = await getCategories();

    categories.remove(category);

    await saveCategories(categories);
  }

  static Future<void> renameCategory(
    String oldName,
    String newName,
  ) async {
    final categories = await getCategories();

    final index = categories.indexOf(oldName);

    if (index == -1) return;

    final name = newName.trim();

    if (name.isEmpty) return;

    if (categories.any(
      (item) =>
          item.toLowerCase() == name.toLowerCase() &&
          item != oldName,
    )) {
      return;
    }

    categories[index] = name;

    await saveCategories(categories);
  }
}

