import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/models/backup_models.dart';
import 'package:tena_budget/services/backup_service.dart';
import 'package:tena_budget/services/category_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('category preferences remain encrypted and are represented in backups',
      () async {
    await CategoryService.saveCategories(['Alimentation', 'Soins animaux']);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('tena_budget_categories');

    expect(stored, startsWith('tena1:'));
    final categories = await CategoryService.getCategories();
    expect(categories, ['Alimentation', 'Soins animaux']);

    const data = BackupData(
      transactions: [],
      budgets: {},
      goals: [],
      categories: ['Alimentation', 'Soins animaux'],
    );
    expect(data.toJson()['categories'], ['Alimentation', 'Soins animaux']);
    expect(data.itemCount, 2);
  });

  test('accepts legacy v1 backup without categories', () async {
    final data = <String, dynamic>{
      'profile': null,
      'transactions': <dynamic>[],
      'budgets': <String, dynamic>{},
      'goals': <dynamic>[],
    };
    final checksum = sha256.convert(utf8.encode(jsonEncode(data))).toString();
    final backup = <String, dynamic>{
      'format': 'tena_budget_backup',
      'version': 1,
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'appVersion': '1.0.0+1',
      'schemaVersion': 5,
      'encrypted': false,
      'checksum': checksum,
      'data': data,
    };

    final result = await BackupService.validateBackupJson(jsonEncode(backup));

    expect(result.isValid, isTrue);
    expect(result.summary!.data.categories, isEmpty);
    expect(result.summary!.categoryCount, 0);
  });

  test('rejects empty category names before restoration', () async {
    final data = <String, dynamic>{
      'profile': null,
      'transactions': <dynamic>[],
      'budgets': <String, dynamic>{},
      'goals': <dynamic>[],
      'categories': ['  '],
    };
    final checksum = sha256.convert(utf8.encode(jsonEncode(data))).toString();
    final backup = <String, dynamic>{
      'format': 'tena_budget_backup',
      'version': backupFormatVersion,
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'appVersion': '1.0.0+1',
      'schemaVersion': 5,
      'encrypted': false,
      'checksum': checksum,
      'data': data,
    };

    final result = await BackupService.validateBackupJson(jsonEncode(backup));

    expect(result.isValid, isFalse);
    expect(result.reason, 'BACKUP_DATA_STRUCTURE_INVALID');
  });
}
