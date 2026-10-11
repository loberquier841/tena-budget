import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import '../../lib/services/import_service.dart';
import '../../lib/models/transaction.dart';

void main() {
  // Helper to create a temporary file with given content and extension
  Future<String> _createTempFile(String content, String extension) async {
    final dir = await Directory.systemTemp.createTemp();
    final file = File('${dir.path}/test_file$extension');
    await file.writeAsString(content);
    return file.path;
  }

  // Helper to create a temporary Excel file with given rows (list of List<String>)
  Future<String> _createTempExcel(List<List<String>> rows) async {
    final dir = await Directory.systemTemp.createTemp();
    final file = File('${dir.path}/test_file.xlsx');
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (int i = 0; i < rows.length; i++) {
      for (int j = 0; j < rows[i].length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i))
            .value = rows[i][j];
      }
    }
    final bytes = excel.encode();
    await file.writeAsBytes(bytes!);
    return file.path;
  };

  group('ImportService', () {
    test('parses CSV with valid rows and no duplicates', () async {
      const csvContent = '''date,amount,category,description
2026-10-01,100.50,Food,Grocery store
2026-10-02,200,Salary,Monthly income
''';
      final filePath = await _createTempFile(csvContent, '.csv');

      final service = ImportService(
        getExistingTransactions: () async => [], // no existing transactions
      );

      final result = await service.importFile(filePath);

      expect(result.validTransactions, hasLength(2));
      expect(result.errors, isEmpty);
      expect(result.duplicateRows, isEmpty);

      // Check first transaction
      final t1 = result.validTransactions[0];
      expect(t1.date.year, 2026);
      expect(t1.date.month, 10);
      expect(t1.date.day, 1);
      expect(t1.amount, 100.5);
      expect(t1.category, 'Food');
      expect(t1.description, 'Grocery store');
      expect(t1.type, TransactionType.expense); // default

      // Check second transaction
      final t2 = result.validTransactions[1];
      expect(t2.date.year, 2026);
      expect(t2.date.month, 10);
      expect(t2.date.day, 2);
      expect(t2.amount, 200);
      expect(t2.category, 'Salary');
      expect(t2.description, 'Monthly income');
      expect(t2.type, TransactionType.expense);
    });

    test('detects invalid rows and reports errors', () async {
      const csvContent = '''date,amount,category,description
2026-10-01,abc,Food,Invalid amount
2026-13-01,50,Food,Invalid month
,100,Food,Missing date
2026-10-01,100,,Missing category
''';
      final filePath = await _createTempFile(csvContent, '.csv');

      final service = ImportService(
        getExistingTransactions: () async => [],
      );

      final result = await service.importFile(filePath);

      // Expect no valid transactions
      expect(result.validTransactions, isEmpty);
      // Expect 4 error messages (one per invalid line)
      expect(result.errors, hasLength(4));
      // Duplicate rows should be empty
      expect(result.duplicateRows, isEmpty);
    });

    test('detects duplicates based on existing transactions', () async {
      const csvContent = '''date,amount,category,description
2026-10-01,100,Food,Lunch
2026-10-02,200,Salary,Income
''';
      final filePath = await _createTempFile(csvContent, '.csv');

      // Existing transaction matching first row
      final existingTxn = Transaction(
        id: 'existing',
        amount: 100,
        category: 'Food',
        description: 'Lunch',
        date: DateTime(2026, 10, 1),
        type: TransactionType.expense,
      );

      final service = ImportService(
        getExistingTransactions: () async => [existingTxn],
      );

      final result = await service.importFile(filePath);

      // Only the second transaction should be valid
      expect(result.validTransactions, hasLength(1));
      expect(result.validTransactions[0].amount, 200);
      // One duplicate row (line 2)
      expect(result.duplicateRows, equals([2]));
      // No errors
      expect(result.errors, isEmpty);
    });

    test('parses Excel file with valid rows', () async {
      final rows = [
        ['date', 'amount', 'category', 'description'],
        ['2026-10-01', '150.75', 'Transport', 'Taxi'],
        ['2026-10-03', '500', 'Freelance', 'Project payment'],
      ];
      final filePath = await _createTempExcel(rows);

      final service = ImportService(
        getExistingTransactions: () async => [],
      );

      final result = await service.importFile(filePath);

      expect(result.validTransactions, hasLength(2));
      expect(result.errors, isEmpty);
      expect(result.duplicateRows, isEmpty);

      final t1 = result.validTransactions[0];
      expect(t1.amount, 150.75);
      expect(t1.category, 'Transport');
      expect(t1.description, 'Taxi');

      final t2 = result.validTransactions[1];
      expect(t2.amount, 500);
      expect(t2.category, 'Freelance');
      expect(t2.description, 'Project payment');
    });

    test('returns error for unsupported file extension', () async {
      final dir = await Directory.systemTemp.createTemp();
      final file = File('${dir.path}/test_file.txt');
      await file.writeAsString('some content');

      final service = ImportService(
        getExistingTransactions: () async => [],
      );

      final result = await service.importFile(file.path);

      expect(result.validTransactions, isEmpty);
      expect(result.errors, contains('Unsupported file format'));
      expect(result.duplicateRows, isEmpty);
    });
  });
}
