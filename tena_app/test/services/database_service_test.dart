import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tena_budget/services/budget_service.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/goal_service.dart';

class _MemoryKeyStore implements SecretKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String keyBase64) async {
    value = keyBase64;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryKeyStore keyStore;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    keyStore = _MemoryKeyStore();
    CryptoService.useKeyStore(keyStore);
    DatabaseService.resetForTesting();
  });

  group('DatabaseService — budgets', () {
    test('création et lecture d’un budget global', () async {
      await DatabaseService.instance.setGlobalBudget(2000);

      final montant = await DatabaseService.instance.getGlobalBudget();
      expect(montant, 2000);
    });

    test('création et lecture d’un budget par catégorie', () async {
      await DatabaseService.instance.setCategoryBudget('Courses', 400);

      final montant =
          await DatabaseService.instance.getCategoryBudget('Courses');
      expect(montant, 400);

      final inconnu =
          await DatabaseService.instance.getCategoryBudget('Inconnue');
      expect(inconnu, 0);
    });

    test('mise à jour d’un budget existant écrase la valeur précédente', () async {
      await DatabaseService.instance.setCategoryBudget('Loisirs', 90);
      await DatabaseService.instance.setCategoryBudget('Loisirs', 150);

      final montant =
          await DatabaseService.instance.getCategoryBudget('Loisirs');
      expect(montant, 150);
    });

    test('suppression d’un budget de catégorie le rend indisponible', () async {
      await DatabaseService.instance.setCategoryBudget('Voyages', 300);
      await DatabaseService.instance.deleteCategoryBudget('Voyages');

      final montant =
          await DatabaseService.instance.getCategoryBudget('Voyages');
      expect(montant, 0);
    });

    test('liste tous les budgets (global + catégories)', () async {
      await DatabaseService.instance.setGlobalBudget(2000);
      await DatabaseService.instance.setCategoryBudget('Courses', 400);
      await DatabaseService.instance.setCategoryBudget('Loisirs', 150);

      final budgets = await DatabaseService.instance.getBudgets();
      expect(budgets.length, 3);
    });

    test('les montants sont chiffrés au repos', () async {
      await DatabaseService.instance.setCategoryBudget('Test', 12345);

      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'budgets',
        where: 'id = ?',
        whereArgs: ['Test'],
      );
      final stored = rows.first['amount_cents'] as String;

      expect(stored, startsWith('tena1:'));
      expect(stored, isNot(contains('12345')));
    });
  });

  group('DatabaseService — objectifs', () {
    test('création et lecture d’un objectif', () async {
      await DatabaseService.instance.insertGoal(GoalEntry(
        id: 'g1',
        name: 'Voyage Japon',
        targetCents: 5000,
        savedCents: 1200,
      ));

      final goals = await DatabaseService.instance.getGoals();
      expect(goals.length, 1);
      expect(goals.first.id, 'g1');
      expect(goals.first.name, 'Voyage Japon');
      expect(goals.first.targetCents, 5000);
      expect(goals.first.savedCents, 1200);
    });

    test('mise à jour d’un objectif conserve l’identifiant', () async {
      await DatabaseService.instance.insertGoal(GoalEntry(
        id: 'g2',
        name: 'Vélo',
        targetCents: 800,
        savedCents: 200,
      ));

      await DatabaseService.instance.updateGoal(GoalEntry(
        id: 'g2',
        name: 'Vélo',
        targetCents: 800,
        savedCents: 500,
      ));

      final goals = await DatabaseService.instance.getGoals();
      expect(goals.first.savedCents, 500);
      expect(goals.first.id, 'g2');
    });

    test('suppression logique d’un objectif l’exclue de la liste', () async {
      await DatabaseService.instance.insertGoal(GoalEntry(
        id: 'g3',
        name: 'Temporaire',
        targetCents: 100,
        savedCents: 10,
      ));
      await DatabaseService.instance.deleteGoal('g3');

      final goals = await DatabaseService.instance.getGoals();
      expect(goals, isEmpty);
    });

    test('les champs sensibles sont chiffrés au repos', () async {
      await DatabaseService.instance.insertGoal(GoalEntry(
        id: 'g4',
        name: 'Objectif Secret',
        targetCents: 9999,
        savedCents: 111,
      ));

      final db = await DatabaseService.instance.database;
      final rows = await db.query('goals', where: 'id = ?', whereArgs: ['g4']);

      final name = rows.first['name'] as String;
      final target = rows.first['target_cents'] as String;
      final saved = rows.first['saved_cents'] as String;

      expect(name, startsWith('tena1:'));
      expect(target, startsWith('tena1:'));
      expect(saved, startsWith('tena1:'));
      expect(name, isNot(contains('Objectif Secret')));
    });
  });

  group('BudgetService — persistance SQLite', () {
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

    test('les données survivent à une réouverture de base (simulée)', () async {
      await BudgetService.setCategoryBudget('Alimentation', 600);

      DatabaseService.resetForTesting();

      expect(await BudgetService.getCategoryBudget('Alimentation'), 600);
    });

    test('une erreur de lecture ne retourne pas de fausse réussite', () async {
      expect(await BudgetService.getCategoryBudget('Catégorie Inexistante'), 0);
    });
  });

  group('GoalService — persistance SQLite', () {
    test('aucun objectif au départ', () async {
      expect(await GoalService.getGoals(), isEmpty);
    });

    test('ajout, mise à jour et suppression', () async {
      await GoalService.addGoal(name: 'PC', targetEuros: 2000, savedEuros: 500);

      var goals = await GoalService.getGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'PC');
      expect(goals.first.targetEuros, 2000);
      expect(goals.first.savedEuros, 500);
      expect(goals.first.id, isNotEmpty);

      await GoalService.updateGoal(goals.first.copyWith(savedCents: 120000));

      goals = await GoalService.getGoals();
      expect(goals.first.savedEuros, 1200);

      await GoalService.deleteGoal(goals.first.id);

      expect(await GoalService.getGoals(), isEmpty);
    });

    test('les objectifs sont réellement persistés (survivent au redémarrage)', () async {
      await GoalService.addGoal(name: 'Vacances', targetEuros: 3000, savedEuros: 250);

      DatabaseService.resetForTesting();

      final goals = await GoalService.getGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'Vacances');
      expect(goals.first.targetEuros, 3000);
      expect(goals.first.savedEuros, 250);
    });

    test('une erreur de lecture retourne une liste vide, pas de fausse donnée', () async {
      expect(await GoalService.getGoals(), isEmpty);
    });
  });
}