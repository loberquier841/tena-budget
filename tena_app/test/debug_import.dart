import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:tena_budget/services/import_service.dart';
import 'package:tena_budget/models/transaction.dart';

Future<List<Transaction>> dummyGetExisting() => [];

void main() async {
  const csvContent = '''date,amount,category,description
2026-10-01,abc,Food,Invalid amount
2026-13-01,50,Food,Invalid month
,100,Food,Missing date
2026-10-01,100,,Missing category
''';
  final dir = await Directory.systemTemp.createTemp();
  final file = File('${dir.path}/test_file.csv');
  await file.writeAsString(csvContent);
  final service = ImportService(getExistingTransactions: dummyGetExisting);
  final result = await service.importFile(file.path);
  print('Valid transactions: ${result.validTransactions.length}');
  print('Errors: ${result.errors}');
  print('Duplicate rows: ${result.duplicateRows}');
}
