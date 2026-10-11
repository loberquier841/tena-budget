import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/services/backup_service.dart';

const String _backupMarker = 'tenabackup1:';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
      expect(file.exists(), isTrue);
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
