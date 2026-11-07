import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/backup_service.dart';
import 'package:tena_budget/services/budget_service.dart';
import 'package:tena_budget/services/category_service.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/finance_service.dart';
import 'package:tena_budget/services/goal_service.dart';
import 'package:tena_budget/services/notification_service.dart';
import 'package:tena_budget/services/forecast_service.dart';
import 'package:tena_budget/services/user_profile_service.dart';
import 'package:tena_budget/models/user_profile.dart';

class _MemoryKeyStore implements SecretKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String keyBase64) async { value = keyBase64; }
  @override
  Future<void> delete() async { value = null; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tena_l7_');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'l7.db');
    BackupService.testBackupDirectory = tempDir.path;
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(_MemoryKeyStore());
  });
  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    BackupService.testBackupDirectory = null;
    if (tempDir.existsSync()) { try { await tempDir.delete(recursive: true); } catch (_) {} }
  });

  test('deux profils: aucune lecture/modification/suppression croisee (CRUD+budgets+objectifs)', () async {
    final db = DatabaseService.instance;
    await db.insertTransaction(Transaction(id:'t1', amount:10, category:'A', description:'', date:DateTime.utc(2026,1,1), type:TransactionType.expense), userId:'alice');
    await db.insertTransaction(Transaction(id:'t2', amount:20, category:'B', description:'', date:DateTime.utc(2026,1,1), type:TransactionType.income), userId:'bob');
    expect((await db.getTransactions(userId:'alice')).single.id, 't1');
    expect((await db.getTransactions(userId:'bob')).single.id, 't2');
    await db.updateTransaction(Transaction(id:'t2', amount:99, category:'B', description:'hack', date:DateTime.utc(2026,1,1), type:TransactionType.income), userId:'alice');
    expect((await db.getTransactions(userId:'bob')).single.amount, 20);
    await db.deleteTransaction('t2', userId:'alice');
    expect((await db.getTransactions(userId:'bob')).length, 1);
    await BudgetService.setGlobalBudget(100, userId:'alice');
    await BudgetService.setGlobalBudget(500, userId:'bob');
    expect(await BudgetService.getGlobalBudget(userId:'alice'), 100);
    expect(await BudgetService.getGlobalBudget(userId:'bob'), 500);
    await GoalService.addGoal(name:'GA', targetEuros:10, userId:'alice');
    await GoalService.addGoal(name:'GB', targetEuros:20, userId:'bob');
    final ga = await GoalService.getGoals(userId:'alice');
    final gb = await GoalService.getGoals(userId:'bob');
    expect(ga.map((g)=>g.name), ['GA']);
    expect(gb.map((g)=>g.name), ['GB']);
    await GoalService.deleteGoal(gb.first.id, userId:'alice');
    expect((await GoalService.getGoals(userId:'bob')).length, 1);
  });

  test('categories et notifications isolees par profil', () async {
    await CategoryService.saveCategories(['X'], userId:'alice');
    await CategoryService.saveCategories(['Y'], userId:'bob');
    expect(await CategoryService.getCategories(userId:'alice'), ['X']);
    expect(await CategoryService.getCategories(userId:'bob'), ['Y']);
    await NotificationService.pushNew([BudgetNotification(id:'n1', title:'A', message:'', severity:NotificationSeverity.info, createdAt:DateTime.utc(2026), pageIndex:0)], userId:'alice');
    expect((await NotificationService.getNotifications(userId:'alice')).length, 1);
    expect((await NotificationService.getNotifications(userId:'bob')), isEmpty);
  });

  test('import CSV scope au bon profil', () async {
    final csv = 'date,amount,description\n2026-01-02,12.50,Test\n';
    final n = await DatabaseService.instance.importTransactionsFromCsv(csv, userId:'alice');
    expect(n, 1);
    expect((await DatabaseService.instance.getTransactions(userId:'alice')).length, 1);
    expect((await DatabaseService.instance.getTransactions(userId:'bob')), isEmpty);
  });

  test('restauration scopee au bon profil (aucune fuite)', () async {
    final db = DatabaseService.instance;
    await db.insertTransaction(Transaction(id:'b1', amount:5, category:'C', description:'', date:DateTime.utc(2026,1,1), type:TransactionType.expense), userId:'bob');
    await db.insertTransaction(Transaction(id:'a1', amount:7, category:'C', description:'', date:DateTime.utc(2026,1,2), type:TransactionType.expense), userId:'alice');
    final file = await BackupService.createBackupFile(directory: tempDir.path, userId: 'alice');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'l7b.db');
    final res = await BackupService.restoreFromFileDetailed(file, userId:'alice');
    expect(res.success || res.errorCode == 'RESTORE_PARTIAL', isTrue);
    expect((await DatabaseService.instance.getTransactions(userId:'bob')).length, 0);
    expect((await DatabaseService.instance.getTransactions(userId:'alice')).length, 1);
  });

  test('previsions scopees: FinanceService/Forecast sur donnees du profil', () async {
    final db = DatabaseService.instance;
    await db.insertTransaction(Transaction(id:'fa', amount:100, category:'C', description:'', date:DateTime.utc(2026,5,1), type:TransactionType.income), userId:'alice');
    await db.insertTransaction(Transaction(id:'fb', amount:999, category:'C', description:'', date:DateTime.utc(2026,5,1), type:TransactionType.income), userId:'bob');
    final sa = await FinanceService.getSummary(userId:'alice');
    final sb = await FinanceService.getSummary(userId:'bob');
    expect(sa.income, 100);
    expect(sb.income, 999);
    final fa = ForecastService.calculate(await db.getTransactions(userId:'alice'));
    expect(fa.averageMonthlyIncome, closeTo(100, 0.001));
  });

  test('profil utilisateur scope par userId (DB)', () async {
    final now = DateTime.utc(2026).toIso8601String();
    await UserProfileService.saveProfile(UserProfile(createdAt: now, updatedAt: now, completedAt: now, answers: {'householdMode':'personal', 'priorities': const ['p']}, dashboard: const {}), userId:'alice');
    await UserProfileService.saveProfile(UserProfile(createdAt: now, updatedAt: now, completedAt: now, answers: {'householdMode':'family', 'priorities': const ['p']}, dashboard: const {}), userId:'bob');
    final pa = await UserProfileService.getProfile(userId:'alice');
    final pb = await UserProfileService.getProfile(userId:'bob');
    expect(pa?.answers['householdMode'], 'personal');
    expect(pb?.answers['householdMode'], 'family');
  });
}
