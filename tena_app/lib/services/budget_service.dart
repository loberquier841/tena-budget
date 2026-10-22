import 'database_service.dart';

class BudgetService {
  static final DatabaseService _db = DatabaseService.instance;

  static Future<double> getGlobalBudget() async {
    return _db.getGlobalBudget();
  }

  static Future<void> setGlobalBudget(double amount) async {
    await _db.setGlobalBudget(amount);
  }

  static Future<double> getCategoryBudget(String category) async {
    return _db.getCategoryBudget(category);
  }

  static Future<void> setCategoryBudget(String category, double amount) async {
    await _db.setCategoryBudget(category, amount);
  }

  static Future<void> deleteCategoryBudget(String category) async {
    await _db.deleteCategoryBudget(category);
  }
}
