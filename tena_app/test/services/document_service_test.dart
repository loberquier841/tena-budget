import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:tena_budget/models/transaction.dart';
import 'package:tena_budget/services/backup_service.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/database_service.dart';
import 'package:tena_budget/services/document_service.dart';

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
    tempDir = await Directory.systemTemp.createTemp('tena_doc_');
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'doc.db');
    DocumentService.testDocumentsRoot = p.join(tempDir.path, 'attachments');
    BackupService.testBackupDirectory = tempDir.path;
    CryptoService.debugSetKey(null);
    CryptoService.useKeyStore(_MemoryKeyStore());
  });

  tearDown(() async {
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = null;
    DocumentService.testDocumentsRoot = null;
    BackupService.testBackupDirectory = null;
    if (tempDir.existsSync()) { try { await tempDir.delete(recursive: true); } catch (_) {} }
  });

  Future<void> seedTx(String id, {String userId = 'primary'}) =>
      DatabaseService.instance.insertTransaction(Transaction(
          id: id, amount: 10, category: 'C', description: 'd',
          date: DateTime.utc(2026,1,1), type: TransactionType.expense), userId: userId);

  test('stockage local + lecture + association transaction', () async {
    await seedTx('tx1');
    final src = File(p.join(tempDir.path, 'facture.pdf'))..writeAsBytesSync([1,2,3,4,5]);
    final doc = await DocumentService.importFile(transactionId: 'tx1', source: src, displayName: 'Facture.pdf', category: 'Logement', note: 'janvier');
    expect(doc.relativePath, isNot(contains(tempDir.path))); // chemin relatif en modèle
    expect(doc.relativePath.startsWith('primary/tx1/'), isTrue);
    final list = await DocumentService.listForTransaction('tx1');
    expect(list.length, 1);
    expect(list.first.fileName, 'Facture.pdf');
    expect(list.first.category, 'Logement');
    final f = await DocumentService.resolveFile(list.first);
    expect(f, isNotNull);
    expect(await f!.readAsBytes(), [1,2,3,4,5]);
  });

  test('modification métadonnées + plusieurs justificatifs', () async {
    await seedTx('tx1');
    final a = File(p.join(tempDir.path, 'a.png'))..writeAsBytesSync([9,8]);
    final b = File(p.join(tempDir.path, 'b.jpg'))..writeAsBytesSync([7,6]);
    final d1 = await DocumentService.importFile(transactionId: 'tx1', source: a);
    await DocumentService.importFile(transactionId: 'tx1', source: b);
    expect((await DocumentService.listForTransaction('tx1')).length, 2);
    final updated = d1.copyWith(fileName: 'Renomme.png', category: 'Impots', note: 'ok');
    await DocumentService.updateMetadata(updated);
    final re = await DatabaseService.instance.getDocumentById(d1.id);
    expect(re?.fileName, 'Renomme.png');
    expect(re?.category, 'Impots');
  });

  test('suppression contrôlée (soft delete) et fichier manquant détecté', () async {
    await seedTx('tx1');
    final src = File(p.join(tempDir.path, 'x.pdf'))..writeAsBytesSync([1]);
    final doc = await DocumentService.importFile(transactionId: 'tx1', source: src);
    final file = await DocumentService.resolveFile(doc);
    expect(file, isNotNull);
    await file!.delete(); // simule fichier manquant
    expect(await DocumentService.fileExists(doc), isFalse);
    final listed = await DocumentService.listForTransaction('tx1');
    expect(listed.length, 1); // métadonnées conservées, pas de perte silencieuse
    await DocumentService.deleteDocument(doc.id);
    expect((await DocumentService.listForTransaction('tx1')), isEmpty);
    expect((await DocumentService.listForTransaction('tx1', includeDeleted: true)).length, 1);
  });

  test('isolation des profils: aucun accès/lecture croisée', () async {
    await seedTx('t1', userId: 'alice');
    await seedTx('t2', userId: 'bob');
    final src = File(p.join(tempDir.path, 'a.pdf'))..writeAsBytesSync([1,2,3]);
    await DocumentService.importFile(transactionId: 't1', source: src, userId: 'alice');
    await DocumentService.importFile(transactionId: 't2', source: src, userId: 'bob');
    expect((await DocumentService.listForTransaction('t1', userId: 'alice')).length, 1);
    expect((await DocumentService.listForTransaction('t2', userId: 'alice')), isEmpty);
    expect((await DocumentService.listForTransaction('t2', userId: 'bob')).length, 1);
  });

  test('backup/restauration préserve documents + relations + détection contenu manquant', () async {
    await seedTx('tx1', userId: 'alice');
    final src = File(p.join(tempDir.path, 'r.pdf'))..writeAsBytesSync([4,5,6,7]);
    await DocumentService.importFile(transactionId: 'tx1', source: src, userId: 'alice', displayName: 'Recu.pdf');
    final backup = await BackupService.createBackupFile(directory: tempDir.path, userId: 'alice');
    // reset
    await DatabaseService.resetAndDeleteTestDatabase();
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'doc2.db');
    DocumentService.testDocumentsRoot = p.join(tempDir.path, 'attachments2');
    final res = await BackupService.restoreFromFileDetailed(backup, userId: 'alice');
    expect(res.success || res.errorCode == 'RESTORE_PARTIAL', isTrue);
    expect(res.documentsRestored, 1);
    final docs = await DocumentService.listForTransaction('tx1', userId: 'alice');
    expect(docs.length, 1);
    final f = await DocumentService.resolveFile(docs.first);
    expect(f, isNotNull);
    expect(await f!.readAsBytes(), [4,5,6,7]);
  });

  test('export backup marque contentMissing si fichier absent (pas de faux succès)', () async {
    await seedTx('tx1');
    final src = File(p.join(tempDir.path, 'm.pdf'))..writeAsBytesSync([1]);
    final doc = await DocumentService.importFile(transactionId: 'tx1', source: src);
    final file = await DocumentService.resolveFile(doc);
    await file!.delete();
    final exported = await DocumentService.exportForBackup();
    expect(exported.length, 1);
    expect(exported.first['contentBase64'], isNull);
    expect(exported.first['contentMissing'], isTrue);
  });
}
