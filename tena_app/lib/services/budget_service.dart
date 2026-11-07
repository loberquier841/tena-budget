import 'database_service.dart';

class BudgetService {
  static final DatabaseService _db = DatabaseService.instance;

  static Future<double> getGlobalBudget({String userId = 'primary'}) async {
    return _db.getGlobalBudget(userId: userId);
  }

  static Future<void> setGlobalBudget(double amount, {String userId = 'primary'}) async {
    await _db.setGlobalBudget(amount, userId: userId);
  }

  static Future<double> getCategoryBudget(String category, {String userId = 'primary'}) async {
    return _db.getCategoryBudget(category, userId: userId);
  }

  static Future<void> setCategoryBudget(String category, double amount, {String userId = 'primary'}) async {
    await _db.setCategoryBudget(category, amount, userId: userId);
  }

  static Future<void> deleteCategoryBudget(String category, {String userId = 'primary'}) async {
    await _db.deleteCategoryBudget(category, userId: userId);
  }
}
