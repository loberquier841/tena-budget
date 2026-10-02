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

    final categories = prefs.getStringList(_key);

    if (categories == null || categories.isEmpty) {
      await prefs.setStringList(_key, defaultCategories);
      return List<String>.from(defaultCategories);
    }

    return categories;
  }

  static Future<void> saveCategories(
    List<String> categories,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_key, categories);
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

