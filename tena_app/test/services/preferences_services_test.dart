import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/budget_service.dart';
import 'package:tena_budget/services/category_service.dart';
import 'package:tena_budget/services/goal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CategoryService', () {
    test('retourne les catégories par défaut au premier lancement', () async {
      final categories = await CategoryService.getCategories();

      expect(categories, CategoryService.defaultCategories);
    });

    test('les valeurs par défaut sont persistées', () async {
      await CategoryService.getCategories();

      final prefs = await SharedPreferences.getInstance();

      expect(
        prefs.getStringList('tena_budget_categories'),
        CategoryService.defaultCategories,
      );
    });

    test('ajoute une catégorie sans doublon, insensible à la casse', () async {
      await CategoryService.addCategory('  Restaurants  ');

      var categories = await CategoryService.getCategories();
      expect(categories.contains('Restaurants'), isTrue);

      await CategoryService.addCategory('restaurants');

      categories = await CategoryService.getCategories();
      expect(
        categories.where((c) => c.toLowerCase() == 'restaurants').length,
        1,
      );
    });

    test('ignore un nom vide', () async {
      await CategoryService.addCategory('   ');

      final categories = await CategoryService.getCategories();

      expect(categories.length, CategoryService.defaultCategories.length);
    });

    test('renomme une catégorie existante', () async {
      await CategoryService.renameCategory('Loisirs', 'Sorties');

      final categories = await CategoryService.getCategories();

      expect(categories.contains('Sorties'), isTrue);
      expect(categories.contains('Loisirs'), isFalse);
    });

    test('ne renomme pas si le nouveau nom est déjà pris', () async {
      await CategoryService.renameCategory('Loisirs', 'Transport');

      final categories = await CategoryService.getCategories();

      expect(categories.contains('Loisirs'), isTrue);
      expect(categories.contains('Transport'), isTrue);
    });

    test('supprime une catégorie', () async {
      await CategoryService.deleteCategory('Voyages');

      final categories = await CategoryService.getCategories();

      expect(categories.contains('Voyages'), isFalse);
    });
  });

  group('BudgetService', () {
    test('budget global à 0 par défaut puis enregistré', () async {
      expect(await BudgetService.getGlobalBudget(), 0);

      await BudgetService.setGlobalBudget(1500);

      expect(await BudgetService.getGlobalBudget(), 1500);
    });

    test('budgets par catégorie indépendants et suppression', () async {
      await BudgetService.setCategoryBudget('Courses', 400);
      await BudgetService.setCategoryBudget('Loisirs', 90);

      expect(await BudgetService.getCategoryBudget('Courses'), 400);
      expect(await BudgetService.getCategoryBudget('Loisirs'), 90);
      expect(await BudgetService.getCategoryBudget('Inconnue'), 0);

      await BudgetService.deleteCategoryBudget('Courses');

      expect(await BudgetService.getCategoryBudget('Courses'), 0);
      expect(await BudgetService.getCategoryBudget('Loisirs'), 90);
    });
  });

  group('GoalService', () {
    test('aucun objectif au départ', () async {
      expect(await GoalService.getGoals(), isEmpty);
    });

    test('ajout, mise à jour et suppression', () async {
      await GoalService.addGoal(name: 'PC', target: 2000, saved: 500);

      var goals = await GoalService.getGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'PC');
      expect(goals.first.target, 2000);
      expect(goals.first.saved, 500);
      expect(goals.first.id, isNotEmpty);

      await GoalService.updateGoal(goals.first.copyWith(saved: 1200));

      goals = await GoalService.getGoals();
      expect(goals.first.saved, 1200);

      await GoalService.deleteGoal(goals.first.id);

      expect(await GoalService.getGoals(), isEmpty);
    });

    test('les objectifs sont réellement persistés', () async {
      await GoalService.addGoal(name: 'Vacances', target: 3000, saved: 250);

      final goals = await GoalService.getGoals();

      expect(goals.length, 1);
      expect(goals.first.name, 'Vacances');
      expect(goals.first.target, 3000);
      expect(goals.first.saved, 250);
    });

    test('copyWith conserve l’identifiant', () {
      const goal = Goal(id: 'g1', name: 'A', target: 10, saved: 5);

      expect(goal.copyWith(saved: 7).id, 'g1');
      expect(goal.copyWith(saved: 7).saved, 7);
      expect(goal.copyWith(saved: 7).target, 10);
    });
  });
}
