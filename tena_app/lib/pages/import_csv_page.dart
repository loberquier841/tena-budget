import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

import 'package:tena_budget/lib/models/transaction.dart';
import 'package:tena_budget/lib/services/import_service.dart';
import 'package:tena_budget/lib/services/database_service.dart';
import 'package:tena_budget/lib/widgets/tena_sidebar.dart';
import 'package:tena_budget/lib/widgets/tena_card.dart';
import 'package:tena_budget/lib/widgets/tena_progress_bar.dart';

class ImportCsvPage extends StatefulWidget {
  const ImportCsvPage({super.key});

  @override
  State<ImportCsvPage> createState() => _ImportCsvPageState();
}

class _ImportCsvPageState extends State<ImportCsvPage> {
  ImportStep _step = ImportStep.selection;
  List<File> _selectedFiles = [];
  List<Transaction> _importedTransactions = [];
  String? _error;
  bool _isLoading = false;
  int _progress = 0;
  CsvToListResult? _csvResult;
  List<Map<String, dynamic>> _columnMappings = {};
  List<Transaction> _previewTransactions = [];
  Set<int> _selectedRows = {};
  bool _hasHeaders = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV'),
        centerTitle: true,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_step) {
      case ImportStep.selection:
        return _buildSelectionScreen(theme);
      case ImportStep.analysis:
        return _buildAnalysisScreen(theme);
      case ImportStep.detection:
        return _buildDetectionScreen(theme);
      case ImportStep.preview:
        return _buildPreviewScreen(theme);
      case ImportStep.validation:
        return _buildValidationScreen(theme);
      case ImportStep.completion:
        return _buildCompletionScreen(theme);
    }
  }

  Widget _buildSelectionScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sélectionner un fichier CSV',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choisissez un fichier CSV contenant vos transactions',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_upload),
            label: const Text('Parcourir fichiers CSV'),
          ),
          const SizedBox(height: 16),
          if (_selectedFiles.isNotEmpty)
            Text(
              '${_selectedFiles.length} fichier(s) sélectionné(s)',
              style: const TextStyle(color: Colors.green),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _selectedFiles.isEmpty ? null : _startImport,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Démarrer l'import'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Analyse du fichier',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const CircularProgressIndicator()
              : _buildAnalysisContent(theme),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading || _csvResult == null ? null : _detectColumns,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent(ThemeData theme) {
    if (_csvResult == null) return const Text('Aucun fichier analysé');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fichier: ${_selectedFiles.first.name}'),
        const SizedBox(height: 8),
        const Text('Lignes détectées: ${_csvResult!.length}'),
        const SizedBox(height: 8),
        const Text('Colonnes détectées:'),
        ..._csvResult!.firstWhere((row) => row.length > 0, orElse: () => []).map((cell) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text('• $cell'),
        )),
      ],
    );
  }

  Widget _buildDetectionScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mappage des colonnes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const CircularProgressIndicator()
              : _buildDetectionContent(theme),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading || _columnMappings.isEmpty ? null : _buildPreview,
            child: const Text('Aperçu'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionContent(ThemeData theme) {
    if (_csvResult == null) return const Text('Aucune donnée');
    
    final firstRow = _csvResult!.firstWhere((row) => row.length > 0, orElse: () => []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(firstRow.length, (i) {
          final header = i < _csvResult!.length ? 'Colonne $i' : '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text('Colonne $i: ${firstRow[i]}'),
                ),
                DropdownButton<String>(
                  value: _columnMappings.containsKey(i) ? _columnMappings[i] : null,
                  items: ['amount', 'date', 'category', 'label', 'person', 'goal', 'unknown']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _columnMappings[i] = value;
                    });
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPreviewScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Aperçu des transactions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const CircularProgressIndicator()
              : _buildPreviewContent(theme),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : _importTransactions,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(ThemeData theme) {
    if (_previewTransactions.isEmpty) return const Text('Aucune transaction à importer');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transactions à importer: ${_previewTransactions.length}'),
        const SizedBox(height: 16),
        ..._previewTransactions.take(10).map((tx) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text('• ${tx.description} - ${tx.amount}€ - ${tx.date.toLocal().toString().split(' ')[0]}'),
        )),
        if (_previewTransactions.length > 10)
          Text('... et ${_previewTransactions.length - 10} autres'),
        const SizedBox(height: 16),
        const Text('Résumé:'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Total', _previewTransactions.length, theme.colorScheme.primary),
          ],
        ),
      ],
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 24, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildValidationScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Validation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const CircularProgressIndicator()
              : _buildValidationContent(theme),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : _completeImport,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.primary,
            ),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transactions validées:'),
        ..._previewTransactions.map((tx) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text('• ${tx.description} - ${tx.amount}€'),
        )),
        const SizedBox(height: 16),
        const Text('Nombre total: ${_previewTransactions.length}'),
      ],
    );
  }

  Widget _buildCompletionScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text(
            'Import terminé',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${_previewTransactions.length} transaction(s) importée(s) avec succès',
            style: const TextStyle(color: Colors.green),
          ),
          const SizedBox(height: 24),
          ElevatedButton.onPressed(
            onPressed: () => Navigator.pop(context, true),
            child: const Retour à l'accueil',
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFiles = [File(result.files.single.path!)];
        _step = ImportStep.analysis;
      });
    }
  }

  Future<void> _startImport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _progress = 0;
    });
    
    try {
      final file = _selectedFiles.first;
      final result = await _parseCsvFile(file);
      setState(() {
        _csvResult = result;
        _step = ImportStep.detection;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _detectColumns() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Analyser les colonnes et proposer des mappages
      _columnMappings = {};
      _step = ImportStep.preview;
      _isLoading = false;
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _buildPreview() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Convertir les lignes CSV en transactions
      _previewTransactions = [];
      
      if (_csvResult != null) {
        final headers = _csvResult!.firstOrNull ?? [];
        
        for (int i = 1; i < _csvResult!.length; i++) {
          final row = _csvResult![i];
          if (row.isEmpty) continue;
          
          // Vérifier si on a les champs nécessaires (label + amount)
          final hasLabel = row.length > 0 && row[0] != null && row[0].toString().isNotEmpty;
          final hasAmount = row.length > 1 && row[1] != null;
          
          if (hasLabel || hasAmount) {
            final tx = _csvToTransaction(row, headers, i);
            _previewTransactions.add(tx);
          }
        }
      }
      
      _step = ImportStep.validation;
      _isLoading = false;
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _importTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Build CSV from preview transactions
      final rows = <List<String>>[];
      rows.add(['id', 'amount', 'category', 'description', 'date', 'type', 'isDeleted', 'notes']);

      for (final tx in _previewTransactions) {
        rows.add([
          tx.id,
          tx.amount.toStringAsFixed(2).replaceAll('.', ','),
          tx.category,
          tx.description,
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}',
          tx.type.name,
          tx.isDeleted ? '1' : '0',
          tx.notes,
        ]);
      }

      final csvData = const CsvConverter().convert(rows);

      // Use DatabaseService import method (handles INSERT OR REPLACE, validation, encryption)
      final imported = await DatabaseService.instance.importTransactionsFromCsv(csvData);

      setState(() {
        _step = ImportStep.completion;
        _isLoading = false;
        _previewTransactions.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$imported transaction(s) importée(s) avec succès'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _completeImport() async {
    Navigator.pop(context, true);
  }
}
