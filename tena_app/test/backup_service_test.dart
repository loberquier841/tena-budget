import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tena_budget/services/backup_service.dart';

const String _backupMarker = 'tenabackup1:';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Set up shared preferences mock for all tests
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Set up path_provider mock for getApplicationDocumentsDirectory
  setUp(() {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        // Return a path to a temporary directory
        return '/tmp';
      }
      return null;
    });
  });

  group('BackupService', () {
    late String testPassword;
    late String wrongPassword;

    setUp(() {
      testPassword = 'validPassword123';
      wrongPassword = 'wrongPassword';
    });

    test('exportBackup throws ArgumentError for empty password', () {
      expect(() => BackupService().exportBackup(''),
          throwsArgumentError);
    });

    test('exportBackup creates non-empty file', () async {
      final service = BackupService();
      final file = await service.exportBackup(testPassword);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
      // Clean up
      await file.delete();
    });

    test('BackupFileExistsException can be instantiated', () {
      expect(
          BackupFileExistsException('test'), isInstanceOf<BackupFileExistsException>());
    });
  });
}
