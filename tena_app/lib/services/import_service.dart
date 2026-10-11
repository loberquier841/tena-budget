import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'dart:math';
typedef Future<List<Transaction>> GetExistingTransactionsFn();

class ImportResult {
  final List<Transaction> validTransactions;
  final List<String> errors; // error messages per line (1-indexed for readability)
  final List<int> duplicateRows; // row numbers that are duplicates of existing transactions

  ImportResult({
    required this.validTransactions,
    required this.errors,
    required this.duplicateRows,
  });
}

class ImportService {


  final GetExistingTransactionsFn _getExistingTransactions;

  ImportService({GetExistingTransactionsFn? getExistingTransactions})
      : _getExistingTransactions = getExistingTransactions ?? DatabaseService.instance.getTransactions;
  /// Result of an import attempt.


  /// Import transactions from a CSV or Excel file.
  /// [filePath] absolute or relative path to the file.
  /// Returns a Future[ImportResult] containing parsed transactions,
  /// validation errors, and rows identified as duplicates (based on existing DB).
  Future<ImportResult> importFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult(
        validTransactions: [],
        errors: ['File not found: $filePath'],
        duplicateRows: [],
      );
    }

    final ext = p.extension(filePath).toLowerCase();
    List<List<dynamic>> rows = [];

    try {
      if (ext == '.csv') {
        final csvData = await file.readAsString();
        rows = const CsvToListConverter(
                fieldDelimiter: ',',
                eol: '\n',
                shouldParseNumbers: false)
            .convert(csvData);
      } else if (ext == '.xlsx' || ext == '.xls') {
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables[excel.tables.keys.first];
        if (sheet == null) {
          return ImportResult(
            validTransactions: [],
            errors: ['No worksheet found in the Excel file'],
            duplicateRows: [],
          );
        }
        rows = sheet.rows
            .map((r) => r.map((cell) => cell?.value ?? '').toList())
            .toList();
      } else {
        return ImportResult(
          validTransactions: [],
          errors: ['Unsupported file format'],
          duplicateRows: [],
        );
      }
    } catch (e) {
      return ImportResult(
        validTransactions: [],
        errors: ['Failed to read file: $e'],
        duplicateRows: [],
      );
    }

    if (rows.isEmpty) {
      return ImportResult(
        validTransactions: [],
        errors: ['File contains no data'],
        duplicateRows: [],
      );
    }

    // Assume first row is header
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final dataRows = rows.skip(1).toList();

    // Determine column indices for date, amount, category, description
    int? dateIdx, amountIdx, categoryIdx, descIdx;

    for (int i = 0; i < header.length; i++) {
      final h = header[i];
      if (dateIdx == null && (h.contains('date') || h == 'date')) dateIdx = i;
      if (amountIdx == null && (h.contains('amount') || h == 'amount' || h == 'montant')) amountIdx = i;
      if (categoryIdx == null && (h.contains('category') || h == 'category' || h == 'catégorie')) categoryIdx = i;
      if (descIdx == null && (h.contains('description') || h == 'description' || h == 'desc' || h == 'libelle')) descIdx = i;
    }

    // Fallback to positional order if not found
    dateIdx ??= 0;
    amountIdx ??= 1;
    categoryIdx ??= 2;
    descIdx ??= 3;

    // Load existing transactions for duplicate detection
    final existingTxns = await _getExistingTransactions();
    final existingKeys = <String>{};
    for (final txn in existingTxns) {
      final key = _makeDuplicateKey(txn);
      existingKeys.add(key);
    }

    final valid = <Transaction>[];
    final errors = <String>[];
    final duplicateRows = <int>[];
    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final lineNumber = i + 2; // +2 because header is line 1, data starts at line 2

      // Guard against short rows
      if (row.length <= dateIdx ||
          row.length <= amountIdx ||
          row.length <= categoryIdx ||
          row.length <= descIdx) {
        errors.add('Line $lineNumber: insufficient columns');
        continue;
      }

      final dateRaw = row[dateIdx]?.toString().trim() ?? '';
      final amountRaw = row[amountIdx]?.toString().trim() ?? '';
      final categoryRaw = row[categoryIdx]?.toString().trim() ?? '';
      final descriptionRaw = row[descIdx]?.toString().trim() ?? '';

      // Parse date
      DateTime? date;
      if (dateRaw.isNotEmpty) {
        date = _parseDate(dateRaw);
        if (date == null) {
          errors.add('Line $lineNumber: invalid date format \"$dateRaw\"');
          continue;
        }
      } else {
        errors.add('Line $lineNumber: date is empty');
         print('Date empty error line $lineNumber');
        continue;
      }

      // Parse amount
      double? amount;
      if (amountRaw.isNotEmpty) {
        final cleaned = amountRaw.replaceAll(',', '.');
        final parsed = double.tryParse(cleaned);
        if (parsed != null && parsed > 0) {
          amount = parsed;
        } else {
          errors.add('Line $lineNumber: amount must be a positive number (\"$amountRaw\")');
          continue;
        }
      } else {
        errors.add('Line $lineNumber: amount is empty');
        continue;
      }

      // Category and description not empty
      if (categoryRaw.isEmpty) {
        errors.add('Line $lineNumber: category is empty');
        continue;
      }
      // description can be empty, we allow empty string

      // Build transaction (type inferred from sign? We don't have sign in CSV/Excel.
      // We'll assume all imported transactions are expenses unless prefixed with '+' or '-'?
      // For simplicity, we'll treat as expense. The user can later edit type.
      final type = TransactionType.expense;

      // Create transaction (id will be generated by DatabaseService.insertTransaction? Actually Transaction requires id.
      // We'll generate a temporary UUID; the DB service will ignore? Actually insert expects id.
      // We'll generate a UUID and let DB replace if conflict? Better to let DB generate? But Transaction constructor requires id.
      // We'll use Uuid v1? Not available. We'll use DateTime.now().millisecondsSinceEpoch as pseudo unique.
      // However collisions possible. We'll rely on DatabaseService to handle id generation? It currently expects id.
      // We'll generate a random uuid using math.Random? Not ideal but okay for import.
      // We'll import dart:math and generate.
      final id = _generateId();

      final transaction = Transaction(
        id: id,
        amount: amount!,
        category: categoryRaw,
        description: descriptionRaw,
        date: date!,
        type: type,
        notes: '',
        isDeleted: false,

      );
        print('About to create transaction at line $lineNumber');


      // Duplicate detection
      final dupKey = _makeDuplicateKey(transaction);
      if (existingKeys.contains(dupKey)) {
        duplicateRows.add(lineNumber);
        // Do not add to valid transactions
        continue;
      }

      valid.add(transaction);
    }

    return ImportResult(
      validTransactions: valid,
      errors: errors,
      duplicateRows: duplicateRows,
    );
  }

  DateTime? _parseDate(String input) {
    // Try ISO 8601: yyyy-MM-dd
    if (input.contains('-')) {
      var parts = input.split('-');
      if (parts.length == 3) {
        try {
          var y = int.parse(parts[0]);
          var m = int.parse(parts[1]);
          var d = int.parse(parts[2]);
          var dt = DateTime(y, m, d);
          // Validate that there is no overflow (i.e., the parsed values match)
          if (dt.year == y && dt.month == m && dt.day == d) {
            return dt;
          }
        } catch (_) {}
      }
    }
    // Try dd/MM/yyyy
    if (input.contains('/')) {
      var parts = input.split('/');
      if (parts.length == 3) {
        try {
          var d = int.parse(parts[0]);
          var m = int.parse(parts[1]);
          var y = int.parse(parts[2]);
          var dt = DateTime(y, m, d);
          if (dt.day == d && dt.month == m && dt.year == y) {
            return dt;
          }
        } catch (_) {}
      }
    }
    // Try yyyy/MM/dd
    if (input.contains('/')) {
      var parts = input.split('/');
      if (parts.length == 3) {
        try {
          var y = int.parse(parts[0]);
          var m = int.parse(parts[1]);
          var d = int.parse(parts[2]);
          var dt = DateTime(y, m, d);
          if (dt.day == d && dt.month == m && dt.year == y) {
            return dt;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String _makeDuplicateKey(Transaction t) {
    // Normalize date to yyyy-MM-dd
    final dateStr = '${t.date.year.toString().padLeft(4, '0')}-'
        '${t.date.month.toString().padLeft(2, '0')}-'
        '${t.date.day.toString().padLeft(2, '0')}';
    // Amount as string with 2 decimal places
    final amountStr = t.amount.toStringAsFixed(2);
    // Trim and lower-case category/description for comparison? We'll keep as is.
    final category = t.category.trim();
    final description = t.description.trim();
    return '$dateStr|$amountStr|$category|$description';
  }

  String _generateId() {
    // Simple UUID v4-ish using math.Random
    final rnd = Random();
    const chars = '0123456789abcdef';
    final sb = StringBuffer();
    for (int i = 0; i < 32; i++) {
      sb.write(chars[rnd.nextInt(chars.length)]);
      if ([7, 11, 15, 19].contains(i)) sb.write('-');
    }
    return sb.toString();
  }
}
