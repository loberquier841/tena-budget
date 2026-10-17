import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import '../services/import_service.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class ImportTransactionsPage extends StatefulWidget {
  const ImportTransactionsPage({Key? key}) : super(key: key);

  @override
  State<ImportTransactionsPage> createState() => _ImportTransactionsPageState();
}

class _ImportTransactionsPageState extends State<ImportTransactionsPage> {
  bool _isLoading = false;
  String? _selectedFilePath;
  ImportResult? _importResult;
  int? _dateColIdx;
  int? _amountColIdx;
  int? _categoryColIdx;
  int? _descriptionColIdx;
  List<String> _headers = [];
  List<List<dynamic>> _rawRows = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer des transactions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedFilePath == null
              ? _buildFilePicker()
              : _buildImportPreview(),
    );
  }

  Widget _buildFilePicker() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Sélectionner un fichier CSV ou Excel', style: TextStyle()),
          ),
          const SizedBox(height: 24),
          if (_selectedFilePath != null)
            Text(
              'Fichier sélectionné: ${p.basename(_selectedFilePath!)}',
              style: const TextStyle(fontSize: 16),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );
      if (result != null && result.path != null) {
        setState(() {
          _selectedFilePath = result.path;
          _importResult = null;
          _dateColIdx = null;
          _amountColIdx = null;
          _categoryColIdx = null;
          _descriptionColIdx = null;
          _headers = [];
          _rawRows = [];
        });
        _analyzeFile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection du fichier: $e')),
        );
      }
    }
  }

  Future<void> _analyzeFile() async {
    if (_selectedFilePath == null) return;
    setState(() => _isLoading = true);
    try {
      final service = ImportService();
      final result = await service.importFile(_selectedFilePath!);
      // We'll store the raw rows for mapping later
      final file = File(_selectedFilePath!);
      final ext = p.extension(_selectedFilePath!).toLowerCase();
      List<List<dynamic>> rows = [];
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
          throw Exception('No worksheet found');
        }
        rows = sheet.rows
            .map((r) => r.map((cell) => cell?.value ?? '').toList())
            .toList();
      }
      if (rows.isEmpty) {
        throw Exception('File contains no data');
      }
      final header = rows.first.map((e) => e.toString().trim()).toList();
      setState(() {
        _isLoading = false;
        _headers = header;
        // Initialize column indices to first four columns if available
        _dateColIdx = 0;
        _amountColIdx = 1;
        _categoryColIdx = 2;
        _descriptionColIdx = 3;
        _rawRows = rows;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'analyse du fichier: $e")),
        );
      }
    }
  }

  Widget _buildImportPreview() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Aperçu du fichier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DataTable(
                columns: _headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: _rawRows
                    .skip(1)
                    .take(5)
                    .map((row) => DataRow(
                        cells: row
                            .take(_headers.length)
                            .map((cell) => DataCell(Text(cell.toString())))
                            .toList()))
                    .toList(),
              ),
              if (_rawRows.length > 6)
                Text(
                  '... et ${_rawRows.length - 6} autres lignes',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              const SizedBox(height: 24),
              const Text(
                'Mapping des colonnes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildMappingDropdown('Date', _headers, _dateColIdx, (idx) =>
                  setState(() => _dateColIdx = idx)),
              const SizedBox(height: 12),
              _buildMappingDropdown('Montant', _headers, _amountColIdx, (idx) =>
                  setState(() => _amountColIdx = idx)),
              const SizedBox(height: 12),
              _buildMappingDropdown('Catégorie', _headers, _categoryColIdx, (idx) =>
                  setState(() => _categoryColIdx = idx)),
              const SizedBox(height: 12),
              _buildMappingDropdown('Description', _headers, _descriptionColIdx,
                  (idx) => setState(() => _descriptionColIdx = idx)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _processImport,
                icon: const Icon(Icons.preview),
                label: const Text('Prévisualiser l\'import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              if (_importResult != null) _buildImportResult(),
            ],
          ),
        ),
        if (_importResult != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _confirmImport,
              icon: const Icon(Icons.cloud_done),
              label: const Text('Importer les transactions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMappingDropdown(String label, List<String> items, int? selectedIndex, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: selectedIndex,
      items: items.asMap().entries.map((entry) {
        return DropdownMenuItem<int?>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null) {
          return 'Sélectionnez une colonne';
        }
        return null;
      },
    );
  }

  Future<File> _createMappedCsv() async {
    final tempDir = await Directory.systemTemp.createTemp();
    final tempFile = File('${tempDir.path}/mapped_import.csv');
    final buffer = StringBuffer();
    // Write header
    buffer.writeln('date,amount,category,description');
    // Write data rows
    for (final row in _rawRows.skip(1)) {
      final date = _dateColIdx != null && _dateColIdx! < row.length ? row[_dateColIdx!] : '';
      final amount = _amountColIdx != null && _amountColIdx! < row.length ? row[_amountColIdx!] : '';
      final category = _categoryColIdx != null && _categoryColIdx! < row.length ? row[_categoryColIdx!] : '';
      final description = _descriptionColIdx != null && _descriptionColIdx! < row.length ? row[_descriptionColIdx!] : '';
      buffer.writeln('$date,$amount,$category,$description');
    }
    await tempFile.writeAsString(buffer.toString());
    return tempFile;
  }

  Future<void> _processImport() async {
    if (_dateColIdx == null ||
        _amountColIdx == null ||
        _categoryColIdx == null ||
        _descriptionColIdx == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez mapper toutes les colonnes')),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final tempCsv = await _createMappedCsv();
      final service = ImportService();
      final result = await service.importFile(tempCsv.path);
      setState(() {
        _isLoading = false;
        _importResult = result;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du traitement: $e')),
        );
      }
    }
  }

  Widget _buildImportResult() {
    if (_importResult == null) return const SizedBox.shrink();
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'R\u00e9sultat de l\u00e0analyse',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Text(
                'Transactions valides: ${_importResult!.validTransactions.length}',
                style: const TextStyle(color: Colors.amber)),
            Text('Erreurs: ${_importResult!.errors.length}', style: const TextStyle(color: Colors.amber)),
            Text('Lignes en doublon: ${_importResult!.duplicateRows.length}', style: const TextStyle(color: Colors.amber)),
            if (_importResult!.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Erreurs:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
              ..._importResult!.errors
                  .take(5)
                  .map((e) => Text('• $e', style: const TextStyle(color: Colors.amber)))
                  .toList(),
              if (_importResult!.errors.length > 5)
                Text(
                    '... et ${_importResult!.errors.length - 5} autres',
                    style: TextStyle(color: Colors.amber)),
            ],
            if (_importResult!.duplicateRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Lignes en doublon:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
              ..._importResult!.duplicateRows
                  .take(5)
                  .map((r) => Text('• Ligne $r', style: const TextStyle(color: Colors.amber)))
                  .toList(),
              if (_importResult!.duplicateRows.length > 5)
                Text(
                    '... et ${_importResult!.duplicateRows.length - 5} autres',
                    style: TextStyle(color: Colors.amber)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmImport() async {
    if (_importResult == null ||
        (_importResult!.validTransactions.isEmpty &&
            _importResult!.errors.isEmpty &&
            _importResult!.duplicateRows.isEmpty)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'import'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                  'Vous allez importer ${_importResult!.validTransactions.length} transaction(s).'),
              if (_importResult!.errors.isNotEmpty)
                Text(
                    '${_importResult!.errors.length} ligne(s) contient des erreurs et sera ignorée(s).'),
              if (_importResult!.duplicateRows.isNotEmpty)
                Text(
                    '${_importResult!.duplicateRows.length} ligne(s) sont des doublons et sera(ont) ignorée(s).'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
            style: TextButton.styleFrom(foregroundColor: Colors.amber),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Importer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _performImport();
    }
  }

  Future<void> _performImport() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseService.instance;
      for (final txn in _importResult!.validTransactions) {
        await db.insertTransaction(txn);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${_importResult!.validTransactions.length} transaction(s) importée(s) avec succès'),
              backgroundColor: Colors.amber),
        );
      }
      // Clear the state to allow a new import
      if (mounted) {
        setState(() {
          _selectedFilePath = null;
          _importResult = null;
          _dateColIdx = null;
          _amountColIdx = null;
          _categoryColIdx = null;
          _descriptionColIdx = null;
          _headers = [];
          _rawRows = [];
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'import: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

}
