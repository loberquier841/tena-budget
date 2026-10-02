import 'package:shared_preferences/shared_preferences.dart';

class BudgetService {
  static const String _globalKey = 'tena_budget_global';
  static const String _categoryPrefix = 'tena_budget_category_';

  static Future<double> getGlobalBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_globalKey) ?? 0;
  }

  static Future<void> setGlobalBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_globalKey, amount);
  }

  static Future<double> getCategoryBudget(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_categoryPrefix$category') ?? 0;
  }

  static Future<void> setCategoryBudget(String category, double amount) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('$_categoryPrefix$category', amount);
  }

  static Future<void> deleteCategoryBudget(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_categoryPrefix$category');
  }
}
