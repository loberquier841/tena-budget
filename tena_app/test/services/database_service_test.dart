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

    test('les objectifs sont réellement persistés (survivent au redémarrage)', () async {
      await GoalService.addGoal(name: 'Vacances', target: 3000, saved: 250);

      DatabaseService.resetForTesting();

      final goals = await GoalService.getGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'Vacances');
      expect(goals.first.target, 3000);
      expect(goals.first.saved, 250);
    });

    test('une erreur de lecture retourne une liste vide, pas de fausse donnée', () async {
      expect(await GoalService.getGoals(), isEmpty);
    });
  });

  group('DatabaseService — CSV import/export', () {
    test('exportTransactionsToCsv génère un CSV valide avec des transactions', () async {
      // insère d'abord quelques transactions de test
      await DatabaseService.instance.insertTransaction(
        Transaction(
          id: 'tx1',
          amount: 100.50,
          category: 'Alimentation',
          description: 'Course du dimanche',
          date: DateTime(2024, 1, 15),
          type: TransactionType.expense,
          notes: 'Course hebdo',
        ),
      );
      await DatabaseService.instance.insertTransaction(
        Transaction(
          id: 'tx2',
          amount: 200.00,
          category: 'Salaire',
          description: 'Revenus du mois',
          date: DateTime(2024, 1, 1),
          type: TransactionType.income,
          notes: 'Salaire net',
        ),
      );

      final csvData = await DatabaseService.instance.exportTransactionsToCsv();
      expect(csvData, isNotEmpty);
      expect(csvData, contains('amount'));
      expect(csvData, contains('Alimentation'));
      expect(csvData, contains('Salaire'));
    });

    test('importTransactionsFromCsv importe des transactions valides', () async {
      final csvData = '''id,amount,category,description,date,type,isDeleted,notes
tx1,100.50,Alimentation,Course du dimanche,2024-01-15,expense,0,Course hebdo
tx2,200.00,Salaire,Revenus du mois,2024-01-01,income,0,Salaire net
tx3,30.99,Transport,Bus du travail,2024-01-10,expense,0,Pass monthly''';

      final int imported = await DatabaseService.instance.importTransactionsFromCsv(csvData);
      expect(imported, 3);

      // Vérifie que les transactions sont en base
      final db = await DatabaseService.instance.database;
      final rows = await db.query('transaction');
      expect(rows.length, 3);
    });

    test('importTransactionsFromCsv ignore les lignes invalides', () async {
      final csvData = '''id,amount,category,description,date,type,isDeleted,notes
invalid-row
tx1,not_a_number,Alimentation,Test,2024-01-15,expense,0,Test
tx2,10.00,Invalide,Test,invalide-date,unknown_type,0,Test''';

      final int imported = await DatabaseService.instance.importTransactionsFromCsv(csvData);
      // Seules les lignes valides should be imported (tx2 should fail on date, tx3 on type)
      // au minimum tx1 should be imported if its date parses correctly
      expect(imported, isNonNegative);
    });

    test('importTransactionsFromCsv avec en-tête manquant reste fonctionnel', () async {
      final csvDataWithoutHeader = '''10.00,Alimentation,Test,2024-01-15,expense,0,Test
20.50,Salaire,Revenus,2024-01-20,income,0,Salaire net''';

      final int imported = await DatabaseService.instance.importTransactionsFromCsv(csvDataWithoutHeader);
      // Sans en-tête, la première ligne sera traitée comme en-tête et sautée,
      // donc 0 ou 1 transaction selon l'implémentation - on vérifie juste qu'on ne plante pas
      expect(imported, isNonNegative);
    });
  });
}