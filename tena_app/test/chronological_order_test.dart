import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';

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

  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tena_chr_');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'chr.db');
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(_MemoryKeyStore());
  });
  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    if (tempDir.existsSync()) { try { await tempDir.delete(recursive: true); } catch (_) {} }
  });

  group('Ordre chronologique (dates chiffrees)', () {
    test('getTransactions retourne le plus recent en premier', () async {
      final svc = DatabaseService.instance;
      await svc.insertTransaction(Transaction(
        id: 'old', amount: 1, category: 'A', description: '', date: DateTime.utc(2024,1,1), type: TransactionType.expense));
      await svc.insertTransaction(Transaction(
        id: 'mid', amount: 1, category: 'A', description: '', date: DateTime.utc(2025,6,1), type: TransactionType.expense));
      await svc.insertTransaction(Transaction(
        id: 'new', amount: 1, category: 'A', description: '', date: DateTime.utc(2026,1,1), type: TransactionType.expense));
      final txs = await svc.getTransactions();
      expect(txs.map((t)=>t.id).toList(), ['new','mid','old']);
    });

    test('ordre stable avec dates chiffrees au repos', () async {
      final svc = DatabaseService.instance;
      for (var i=0;i<5;i++) {
        await svc.insertTransaction(Transaction(
          id: 't$i', amount: i.toDouble(), category: 'A', description: '',
          date: DateTime.utc(2026, 1, i+1), type: TransactionType.expense));
      }
      final db = await svc.database;
      final raw = await db.query('transactions', limit: 1);
      expect(raw.first['date'].toString(), startsWith('tena1:'));
      final txs = await svc.getTransactions();
      for (var i=0;i<txs.length-1;i++) {
        expect(txs[i].date.isAfter(txs[i+1].date) || txs[i].date.isAtSameMomentAs(txs[i+1].date), isTrue);
      }
    });
  });
}
