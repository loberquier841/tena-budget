import 'dart:io';

import 'package:flutter/material.dart';

import '../models/backup_models.dart';
import '../services/app_scope.dart';
import '../services/backup_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

/// Gestion locale des sauvegardes/restaurations (LOT 3/6).
/// 100% offline, aucun serveur. Données réelles uniquement.
class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key});

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  final _dirController = TextEditingController();
  List<File> _files = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  @override
  void dispose() {
    _dirController.dispose();
    super.dispose();
  }

  Future<void> _initDir() async {
    final dir = await BackupService.defaultDirectory;
    _dirController.text = dir;
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = _dirController.text.trim();
      final files = await BackupService.listBackupFiles(
          directory: dir.isEmpty ? null : dir);
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _files = const [];
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    tenaShowSnack(context, msg, error: error);
  }

  Future<void> _createBackup() async {
    final cfg = await showDialog<_BackupCreateConfig>(
      context: context,
      builder: (ctx) => const _CreateBackupDialog(),
    );
    if (cfg == null) return;
    setState(() => _busy = true);
    try {
      final file = await BackupService.createBackupFile(
        encrypt: cfg.encrypt,
        encryptionMode: cfg.mode,
        passphrase: cfg.passphrase,
        directory: _dirController.text.trim().isEmpty
            ? null
            : _dirController.text.trim(),
      );
      _snack('Sauvegarde créée : ${file.path}');
      await _refresh();
    } catch (e) {
      _snack('Échec création : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassphrase({required String title, bool confirm = false}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _PassphraseDialog(title: title, confirm: confirm),
    );
  }

  Future<void> _inspect(File file) async {
    String? pass;
    // first try without passphrase (local/non-encrypted)
    var res = await BackupService.validateBackupFile(file);
    if (!res.isValid && res.reason == 'PASSPHRASE_REQUIRED') {
      pass = await _askPassphrase(title: 'Phrase de passe (sauvegarde portable)');
      if (pass == null) return;
      res = await BackupService.validateBackupFile(file, passphrase: pass);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PreviewDialog(result: res, filePath: file.path),
    );
  }

  Future<void> _restore(File file) async {
    var res = await BackupService.validateBackupFile(file);
    String? pass;
    if (!res.isValid && res.reason == 'PASSPHRASE_REQUIRED') {
      pass = await _askPassphrase(title: 'Phrase de passe requise pour restaurer');
      if (pass == null) return;
      res = await BackupService.validateBackupFile(file, passphrase: pass);
    }
    if (!res.isValid || res.summary == null) {
      _snack('Fichier invalide : ${res.reason}', error: true);
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la restauration'),
        content: Text(
          'Restauration best-effort (aucun écrasement silencieux).\n'
          'Une sauvegarde de secours locale sera créée avant toute écriture.\n\n'
          'Profil: ${res.summary!.hasProfile ? 'oui' : 'non'} • '
          'Transactions: ${res.summary!.transactionCount} • '
          'Budgets: ${res.summary!.budgetCount} • '
          'Objectifs: ${res.summary!.goalCount}\n\n'
          'Périmètre: ${AppScope.activeUserId} (mono-profil sécurisé).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final report = await BackupService.restoreFromFileDetailed(
        file,
        passphrase: pass,
        userId: AppScope.activeUserId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(report.success ? 'Restauration terminée' : 'Restauration partielle/échec'),
          content: SingleChildScrollView(
            child: Text(
              'Succès: ${report.success}\n'
              'Transactions: ${report.transactionsRestored} • '
              'Budgets: ${report.budgetsRestored} • '
              'Objectifs: ${report.goalsRestored} • '
              'Catégories: ${report.categoriesRestored} • '
              'Profil: ${report.profileRestored} • '
              'Préférences: ${report.preferencesRestored}\n'
              'Secours: ${report.preRestoreBackupPath ?? '—'}\n'
              '${report.errorMessage != null ? 'Erreur: ${report.errorMessage}\n' : ''}'
              '${report.warnings.isNotEmpty ? 'Avertissements:\n- ${report.warnings.join('\n- ')}\n' : ''}'
              '${report.skipped.isNotEmpty ? 'Ignorés:\n- ${report.skipped.join('\n- ')}' : ''}',
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
        ),
      );
    } catch (e) {
      _snack('Restauration impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la sauvegarde ?'),
        content: Text('Supprimer le fichier local :\n${file.path}\n\nCette action n’affecte pas les données de l’app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await BackupService.deleteBackupFile(file);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sauvegardes'),
        actions: [
          IconButton(tooltip: 'Actualiser', onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createBackup,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.backup_outlined),
        label: const Text('Créer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(TenaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TenaCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Sauvegarde / restauration locale',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  '100% local/offline. Chiffrement local (keystore) ou export portable par phrase de passe '
                  '(Argon2id/PBKDF2 + AES-GCM). Aucune clé/phrase stockée en clair. '
                  'Validation + empreinte avant restauration, sauvegarde de secours automatique, aucun écrasement silencieux.',
                  style: TextStyle(color: TenaColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _dirController,
                      decoration: const InputDecoration(
                        labelText: 'Dossier (choisi par vous)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(onPressed: _busy ? null : _refresh, child: const Text('Ouvrir')),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: TenaColors.danger)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                      ? const Center(
                          child: Text('Aucune sauvegarde (.tenabackup) dans ce dossier.',
                              style: TextStyle(color: TenaColors.textSecondary)))
                      : ListView.separated(
                          itemCount: _files.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final f = _files[i];
                            final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : f.path;
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.description_outlined, color: TenaColors.gold),
                                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(f.path, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: TenaColors.textTertiary)),
                                trailing: Wrap(spacing: 4, children: [
                                  IconButton(tooltip: 'Aperçu / valider', icon: const Icon(Icons.visibility_outlined), onPressed: _busy ? null : () => _inspect(f)),
                                  IconButton(tooltip: 'Restaurer', icon: const Icon(Icons.restore), onPressed: _busy ? null : () => _restore(f)),
                                  IconButton(tooltip: 'Supprimer fichier', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : () => _delete(f)),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCreateConfig {
  final bool encrypt;
  final String mode;
  final String? passphrase;
  const _BackupCreateConfig(this.encrypt, this.mode, this.passphrase);
}

class _CreateBackupDialog extends StatefulWidget {
  const _CreateBackupDialog();
  @override
  State<_CreateBackupDialog> createState() => _CreateBackupDialogState();
}

class _CreateBackupDialogState extends State<_CreateBackupDialog> {
  bool encrypt = true;
  String mode = BackupEncryptionMode.localKey;
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  String? err;

  @override
  void dispose() { pass.dispose(); pass2.dispose(); super.dispose(); }

  void _submit() {
    if (encrypt && mode == BackupEncryptionMode.portablePassphrase) {
      if (pass.text.isEmpty) { setState(() => err = 'Phrase de passe requise.'); return; }
      if (pass.text != pass2.text) { setState(() => err = 'Les phrases ne correspondent pas.'); return; }
    }
    Navigator.pop(context, _BackupCreateConfig(encrypt, mode,
        mode == BackupEncryptionMode.portablePassphrase ? pass.text : null));
  }

  @override
  Widget build(BuildContext context) {
    final portable = encrypt && mode == BackupEncryptionMode.portablePassphrase;
    return AlertDialog(
      title: const Text('Créer une sauvegarde'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chiffrer'),
          subtitle: const Text('Recommandé (AES-GCM, intégrité).'),
          value: encrypt,
          onChanged: (v) => setState(() { encrypt = v; err = null; }),
        ),
        if (encrypt)
          DropdownButtonFormField<String>(
            initialValue: mode,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: const [
              DropdownMenuItem(value: BackupEncryptionMode.localKey, child: Text('Clé locale (cet appareil)')),
              DropdownMenuItem(value: BackupEncryptionMode.portablePassphrase, child: Text('Portable (phrase de passe)')),
            ],
            onChanged: (v) => setState(() { mode = v ?? mode; err = null; }),
          ),
        if (portable) ...[
          const SizedBox(height: 8),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Phrase de passe')),
          const SizedBox(height: 8),
          TextField(controller: pass2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmer')),
        ],
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: TenaColors.danger))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Créer')),
      ],
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  final String title;
  final bool confirm;
  const _PassphraseDialog({required this.title, this.confirm = false});
  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}
class _PassphraseDialogState extends State<_PassphraseDialog> {
  final a = TextEditingController();
  final b = TextEditingController();
  String? err;
  @override
  void dispose() { a.dispose(); b.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: a, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Phrase de passe')),
        if (widget.confirm) ...[
          const SizedBox(height: 8),
          TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmer')),
        ],
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: TenaColors.danger))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () {
          if (widget.confirm && a.text != b.text) { setState(() => err = 'Non concordant.'); return; }
          Navigator.pop(context, a.text);
        }, child: const Text('Continuer')),
      ],
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  final BackupValidationResult result;
  final String filePath;
  const _PreviewDialog({required this.result, required this.filePath});
  @override
  Widget build(BuildContext context) {
    final s = result.summary;
    return AlertDialog(
      title: Text(result.isValid ? 'Sauvegarde valide' : 'Sauvegarde invalide'),
      content: SingleChildScrollView(child: Text(
        result.isValid && s != null
            ? 'Fichier: $filePath\n'
              'Version format: ${s.formatVersion} • schéma: ${s.schemaVersion} • app: ${s.appVersion}\n'
              'Créée: ${s.createdAt.toIso8601String()}\n'
              'Chiffrée: ${s.encrypted} ${s.encryptionMode != null ? '(${s.encryptionMode})' : ''}\n'
              'Profil: ${s.hasProfile} • Transactions: ${s.transactionCount} • Budgets: ${s.budgetCount} • '
              'Objectifs: ${s.goalCount} • Catégories: ${s.categoryCount} • Préférences: ${s.preferenceCount}\n'
              '${s.warnings.isNotEmpty ? '\nAvertissements:\n- ${s.warnings.join('\n- ')}' : ''}'
            : 'Fichier: $filePath\nRaison: ${result.reason ?? 'inconnue'}',
      )),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
