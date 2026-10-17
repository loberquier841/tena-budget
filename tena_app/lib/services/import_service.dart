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
                eol: '\\n',
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
      if (descIdx == null && (h.contains('description') || h == 'description' || h == 'libelle' || h == 'memo')) descIdx = i;
    }

    if (dateIdx == null || amountIdx == null || categoryIdx == null) {
      return ImportResult(
        validTransactions: [],
        errors: ['Missing required columns: date, amount, category are required'],
        duplicateRows: [],
      );
    }

    // Fetch existing transactions for duplicate detection and ID collision avoidance
    final existingTransactions = await _getExistingTransactions();
    final existingKeys = <String>{};
    final existingIds = <String>{};
    for (final t in existingTransactions) {
      existingKeys.add(_makeDuplicateKey(t));
      existingIds.add(t.id);
    }

    final valid = <Transaction>[];
    final errors = <String>[];
    final duplicateRows = <int>[];
    final generatedIds = <String>{}; // IDs generated in this batch to avoid collisions

    // Process each data row (line numbers start at 2 because of header)
    for (int rowIndex = 0; rowIndex < dataRows.length; rowIndex++) {
      final lineNumber = rowIndex + 2; // 1-indexed for error reporting, header is line 1
      final row = dataRows[rowIndex];
      if (row.length <= dateIdx ||
          row.length <= amountIdx ||
          row.length <= categoryIdx ||
          (descIdx != null && row.length <= descIdx)) {
        errors.add('Line $lineNumber: insufficient columns');
        continue;
      }

      final dateRaw = row[dateIdx].toString().trim();
      final amountRaw = row[amountIdx].toString().trim();
      final categoryRaw = row[categoryIdx].toString().trim();
      final descriptionRaw = descIdx != null ? row[descIdx].toString().trim() : '';

      // Parse date
      final date = _parseDate(dateRaw);
      if (date == null) {
        errors.add('Line $lineNumber: invalid date format');
        continue;
      }

      // Parse amount
      double? amount;
      try {
        amount = double.parse(amountRaw);
      } catch (_) {
        errors.add('Line $lineNumber: invalid amount');
        continue;
      }
      if (amount <= 0) {
        errors.add('Line $lineNumber: amount must be positive');
        continue;
      }

      // Validate category and description (non-empty after trim)
      if (categoryRaw.isEmpty) {
        errors.add('Line $lineNumber: category cannot be empty');
        continue;
      }
      // Description can be empty, that's fine.

      // Trim category and description
      final category = categoryRaw.trim();
      final description = descriptionRaw.trim();

      // Determine type based on context? Actually, the import should specify income/expense via a column or assume expense?
      // The existing code assumed expense if not specified. We'll keep that: if there's a 'type' column, use it; else default to expense.
      int? typeIdx;
      for (int i = 0; i < header.length; i++) {
        final h = header[i];
        if (h.contains('type') || h == 'type' || h == 'revenu/dépense' || h == 'income/expense') {
          typeIdx = i;
          break;
        }
      }
      TransactionType type = TransactionType.expense; // default
      if (typeIdx != null && row.length > typeIdx) {
        final typeRaw = row[typeIdx].toString().trim().toLowerCase();
        if (typeRaw == 'income' || typeRaw == 'revenu' || typeRaw == 'credit') {
          type = TransactionType.income;
        } else if (typeRaw == 'expense' || typeRaw == 'dépense' || typeRaw == 'debit') {
          type = TransactionType.expense;
        } else {
          // If unrecognized, default to expense and maybe log warning? We'll keep expense.
        }
      }

      // Duplicate detection
      final transaction = Transaction(
        id: '', // placeholder, will set after generating unique ID
        amount: amount,
        category: category,
        description: description,
        date: date,
        type: type,
        notes: '',
        isDeleted: false,
      );
      final dupKey = _makeDuplicateKey(transaction);
      if (existingKeys.contains(dupKey)) {
        duplicateRows.add(lineNumber);
        continue;
      }

      // Generate a unique ID
      String? generatedId;
      final maxAttempts = 10;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final candidateId = _generateId();
        if (!existingIds.contains(candidateId) && !generatedIds.contains(candidateId)) {
          generatedId = candidateId;
          break;
        }
      }
      generatedId ??= '${DateTime.now().microsecondsSinceEpoch}_${_generateId()}';

      // Ensure it's still unique (should be)
      if (existingIds.contains(generatedId) || generatedIds.contains(generatedId)) {
        // Extremely unlikely, but if happens, we'll still use it and hope DB replace is okay? Better to error.
        errors.add('Line $lineNumber: unable to generate unique ID after $maxAttempts attempts');
        continue;
      }
      generatedIds.add(generatedId);
      // Now create the transaction with the generated ID
      final txnWithId = Transaction(
        id: generatedId,
        amount: amount,
        category: category,
        description: description,
        date: date,
        type: type,
        notes: '',
        isDeleted: false,
      );

      valid.add(txnWithId);
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
