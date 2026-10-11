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
  ImportService.ImportResult? _importResult;
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
            label: const Text('Sélectionner un fichier CSV ou Excel'),
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
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
          SnackBar(content: Text('Erreur lors de l\'analyse du fichier: $e')),
        );
      }
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
                const Text(
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
            ),
          ),
      ],
    );
  }
