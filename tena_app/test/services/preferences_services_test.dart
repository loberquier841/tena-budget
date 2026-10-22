import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/category_service.dart';

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
}
