import 'package:tena_budget/services/backup_service.dart';

Future<void> main() async {
  final service = BackupService();
  try {
    final file = await service.exportBackup('testPassword');
    print('Success: ${file.path}');
    final bytes = await file.readAsBytes();
    print('Length: ${bytes.length}');
    await file.delete();
  } catch (e, s) {
    print('Error: $e');
    print('Stack: $s');
  }
}