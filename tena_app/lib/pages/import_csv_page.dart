import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/database_service.dart';
import '../services/import_service.dart';
import '../services/transaction_rule_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

class ImportCsvPage extends StatefulWidget {
  const ImportCsvPage({super.key});

  @override
  State<ImportCsvPage> createState() => _ImportCsvPageState();
}

class _ImportCsvPageState extends State<ImportCsvPage> {
  final TextEditingController _csvTextController = TextEditingController();
  bool _isLoading = false;
  bool _isCommitting = false;
  String? _statusMessage;
  String? _errorMessage;
  ImportAnalysis? _analysis;
  bool _includeProbableDuplicates = false;

  static const _fieldLabels = <String, String>{
    'date': 'Date',
    'label': 'Libellé / Description',
    'amount': 'Montant (signé)',
    'debit': 'Débit',
    'credit': 'Crédit',
    'category': 'Catégorie',
    'id': 'ID (canonique)',
    'type': 'Type (canonique)',
    'isdeleted': 'Supprimé (canonique)',
    'notes': 'Notes',
  };

  @override
  void dispose() {
    _csvTextController.dispose();
    super.dispose();
  }

  Future<void> _analyzeCsv() async {
    final text = _csvTextController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _statusMessage = null;
        _errorMessage = 'Veuillez coller le contenu de votre fichier CSV.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final ctx = await DatabaseService.instance
          .getImportContext(userId: AppScope.activeUserId);
      final analysis = ImportService.analyzeCsv(
        text,
        existingFingerprints: ctx.fingerprints,
        existingIds: ctx.existingIds,
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _isLoading = false;
        _includeProbableDuplicates = false;
        _statusMessage =
            'Séparateur détecté: "${_sepLabel(analysis.separator)}" — ${analysis.report.totalRows} ligne(s) analysée(s).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _analysis = null;
        _errorMessage = 'Erreur lors de l\'analyse CSV : $e';
      });
    }
  }

  String _sepLabel(String s) {
    if (s == '\t') return 'tabulation';
    if (s == ';') return 'point-virgule';
    if (s == ',') return 'virgule';
    return s;
  }

  void _updateMapping(String field, int? index) {
    final a = _analysis;
    if (a == null) return;
    final i = index ?? -1;
    var m = a.mapping;
    switch (field) {
      case 'date':
        m = m.copyWith(dateIndex: i);
        break;
      case 'label':
        m = m.copyWith(labelIndex: i);
        break;
      case 'amount':
        m = m.copyWith(amountIndex: i);
        break;
      case 'debit':
        m = m.copyWith(debitIndex: i);
        break;
      case 'credit':
        m = m.copyWith(creditIndex: i);
        break;
      case 'category':
        m = m.copyWith(categoryIndex: i);
        break;
      case 'id':
        m = m.copyWith(idIndex: i);
        break;
      case 'type':
        m = m.copyWith(typeIndex: i);
        break;
      case 'isdeleted':
        m = m.copyWith(isDeletedIndex: i);
        break;
      case 'notes':
        m = m.copyWith(notesIndex: i);
        break;
    }
    setState(() {
      _analysis = ImportService.analyzeCsv(
        _csvTextController.text,
        mappingOverride: m,
      );
    });
  }

  int _mappingIndexFor(String field) {
    final m = _analysis?.mapping;
    if (m == null) return -1;
    switch (field) {
      case 'date':
        return m.dateIndex;
      case 'label':
        return m.labelIndex;
      case 'amount':
        return m.amountIndex;
      case 'debit':
        return m.debitIndex;
      case 'credit':
        return m.creditIndex;
      case 'category':
        return m.categoryIndex;
      case 'id':
        return m.idIndex;
      case 'type':
        return m.typeIndex;
      case 'isdeleted':
        return m.isDeletedIndex;
      case 'notes':
        return m.notesIndex;
      default:
        return -1;
    }
  }

  Future<void> _executeImport() async {
    final analysis = _analysis;
    if (analysis == null) return;
    final prepared = analysis.preparedTransactions(
      includeProbableDuplicates: _includeProbableDuplicates,
    );
    if (prepared.isEmpty) {
      setState(
        () => _errorMessage = 'Aucune ligne importable. Vérifiez le mapping, les erreurs ou les doublons.',
      );
      return;
    }

    // Application du moteur de catégorisation automatique (sans écraser les catégories manuelles)
    final categorized = prepared.map((p) {
      final tx = p.toTransaction();
      final updated = TransactionRuleService().apply(tx);
      return PreparedTransaction(
        id: p.id,
        amountCentsSigned: p.amountCentsSigned,
        category: updated.category,
        description: p.description,
        date: p.date,
        type: p.type,
        notes: p.notes,
        isDeleted: p.isDeleted,
        canonicalIdUpdate: p.canonicalIdUpdate,
        preserveSignedAmount: p.preserveSignedAmount,
        fingerprint: p.fingerprint,
      );
    }).toList();

    setState(() {
      _isCommitting = true;
      _errorMessage = null;
    });
    try {
      final res = await DatabaseService.instance.commitImportPlan(
        categorized,
        userId: AppScope.activeUserId,
      );
      if (!mounted) return;
      setState(() {
        _isCommitting = false;
        _statusMessage =
            '${res.imported} transaction(s) traitée(s) et chiffrée(s) (dont ${res.updated} mise(s) à jour par ID).'
            '${res.skipped > 0 ? ' ${res.skipped} ignorée(s) pour protection.' : ''}';
      });
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCommitting = false;
        _errorMessage = 'Erreur d\'importation : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TenaColors.background,
      appBar: AppBar(
        title: const Text('Importer un fichier CSV'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TenaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputCard(),
            if (_analysis != null) ...[
              const SizedBox(height: TenaSpacing.lg),
              _buildMappingCard(_analysis!),
              const SizedBox(height: TenaSpacing.lg),
              _buildReportCard(_analysis!),
              const SizedBox(height: TenaSpacing.lg),
              _buildPreviewCard(_analysis!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TenaColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.file_upload_outlined,
                  color: TenaColors.gold,
                ),
              ),
              const SizedBox(width: TenaSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importation CSV (pipeline unique, chiffré)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TenaColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Collez un export TENΛ ou un relevé bancaire (FR/international).',
                      style: TextStyle(
                        fontSize: 12,
                        color: TenaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TenaSpacing.md),
          TextField(
            controller: _csvTextController,
            maxLines: 8,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: TenaColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'date;libellé;montant;catégorie\n15/01/2026;Courses;-45,50;Alimentation\n01/02/2026;Salaire;3200,00;Revenus',
              hintStyle: const TextStyle(color: TenaColors.textTertiary),
              filled: true,
              fillColor: TenaColors.surface,
              border: OutlineInputBorder(
                borderRadius: TenaRadius.md,
                borderSide: const BorderSide(color: TenaColors.border),
              ),
            ),
          ),
          const SizedBox(height: TenaSpacing.md),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: (_isLoading || _isCommitting) ? null : _analyzeCsv,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Analyser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TenaColors.surfaceRaised,
                  foregroundColor: TenaColors.textPrimary,
                ),
              ),
              const SizedBox(width: TenaSpacing.sm),
              ElevatedButton.icon(
                onPressed: (_isCommitting || _analysis == null)
                    ? null
                    : _executeImport,
                icon: _isCommitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isCommitting ? 'Importation…' : 'Valider l\'importation',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TenaColors.gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: TenaColors.surfaceRaised,
                ),
              ),
            ],
          ),
          if (_statusMessage != null) _msg(_statusMessage!, TenaColors.gold),
          if (_errorMessage != null) _msg(_errorMessage!, TenaColors.danger),
        ],
      ),
    );
  }

  Widget _msg(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: TenaSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(TenaSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: TenaRadius.sm,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 13)),
      ),
    );
  }

  Widget _buildMappingCard(ImportAnalysis a) {
    final maxCols = [
      a.headers.length,
      ...a.rows.take(5).map((r) => r.rawRow.length),
    ].fold<int>(0, (p, c) => c > p ? c : p);
    final colLabels = List<String>.generate(maxCols, (i) {
      if (i < a.headers.length && a.headers[i].trim().isNotEmpty) {
        return '${i + 1}. ${a.headers[i]}';
      }
      return 'Colonne ${i + 1}';
    });

    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mapping des colonnes (vérifier/corriger)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TenaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Si débit/crédit sont mappés et tous deux non nuls sur une ligne, la ligne est signalée en erreur (aucun calcul net automatique).',
            style: TextStyle(fontSize: 11, color: TenaColors.textSecondary),
          ),
          const SizedBox(height: TenaSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  'date',
                  'label',
                  'amount',
                  'debit',
                  'credit',
                  'category',
                  'id',
                  'type',
                  'isdeleted',
                  'notes',
                ].map((field) {
                  final cur = _mappingIndexFor(field);
                  return SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int>(
                      initialValue: cur >= 0 && cur < maxCols ? cur : -1,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _fieldLabels[field],
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: -1,
                          child: Text('(non mappé)'),
                        ),
                        for (var i = 0; i < maxCols; i++)
                          DropdownMenuItem(value: i, child: Text(colLabels[i])),
                      ],
                      onChanged: (v) => _updateMapping(field, v),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ImportAnalysis a) {
    final r = a.report;
    final committable = a.preparedTransactions(
      includeProbableDuplicates: _includeProbableDuplicates,
    );
    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bilan avant validation',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TenaColors.textPrimary,
            ),
          ),
          const SizedBox(height: TenaSpacing.sm),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _chip('Prêtes / traitables', '${r.ready}', TenaColors.success),
              _chip('Erreurs', '${r.errors}', TenaColors.danger),
              _chip(
                'Doublons probables',
                '${r.duplicateProbable}',
                TenaColors.gold,
              ),
              _chip(
                'Mises à jour par ID',
                '${r.updatesById}',
                TenaColors.textSecondary,
              ),
              _chip(
                'Seront commitées',
                '${committable.length}',
                TenaColors.textPrimary,
              ),
            ],
          ),
          if (r.duplicateProbable > 0) ...[
            const SizedBox(height: TenaSpacing.sm),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _includeProbableDuplicates,
              onChanged: (v) =>
                  setState(() => _includeProbableDuplicates = v ?? false),
              title: const Text(
                'Inclure les doublons probables (IDs uniques, aucun écrasement)',
                style: TextStyle(fontSize: 13, color: TenaColors.textPrimary),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Text(
              'Une empreinte identique n\'est pas une preuve certaine d\'identité. Les doublons restent exclus par défaut.',
              style: TextStyle(fontSize: 11, color: TenaColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ImportAnalysis a) {
    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aperçu fidèle (données réellement préparées)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TenaColors.textPrimary,
            ),
          ),
          const SizedBox(height: TenaSpacing.sm),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: a.rows.length > 80 ? 80 : a.rows.length,
            itemBuilder: (context, index) {
              final r = a.rows[index];
              final p = r.prepared;
              final isDup = r.status == ImportRowStatus.duplicateProbable;
              final isErr = r.status == ImportRowStatus.error;
              final isUpd = r.status == ImportRowStatus.updateById;
              final color = isErr
                  ? TenaColors.danger
                  : isDup
                  ? TenaColors.gold
                  : isUpd
                  ? TenaColors.textSecondary
                  : TenaColors.success;
              final status = isErr
                  ? 'Erreur'
                  : isDup
                  ? 'Doublon probable'
                  : isUpd
                  ? 'MAJ par ID'
                  : 'Prête';
              return Card(
                color: TenaColors.surface,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isErr
                        ? Icons.error_outline
                        : isDup
                        ? Icons.content_copy
                        : Icons.check_circle_outline,
                    color: color,
                    size: 18,
                  ),
                  title: Text(
                    p?.description ?? '(ligne invalide)',
                    style: const TextStyle(color: TenaColors.textPrimary),
                  ),
                  subtitle: Text(
                    'L${r.rowIndex} • $status${p != null ? ' • ${p.category} • ${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}/${p.date.year}' : ''}'
                    '${r.errors.isNotEmpty ? '\n${r.errors.join(' ; ')}' : ''}',
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                  trailing: p == null
                      ? null
                      : Text(
                          '${p.amountCentsSigned >= 0 ? '+' : '-'}${p.amountAbsEuros.toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: p.type.name == 'income'
                                ? TenaColors.success
                                : TenaColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              );
            },
          ),
          if (a.rows.length > 80)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '… ${a.rows.length - 80} ligne(s) supplémentaires non affichées.',
                style: const TextStyle(
                  color: TenaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
