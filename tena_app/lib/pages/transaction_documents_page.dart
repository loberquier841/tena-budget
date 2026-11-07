import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/transaction_document.dart';
import '../services/app_scope.dart';
import '../services/document_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

/// Gestion locale des justificatifs d'une transaction (LOT 8).
/// Import natif (file_selector, Flutter team, 0€) avec repli chemin manuel.
class TransactionDocumentsPage extends StatefulWidget {
  final Transaction transaction;
  const TransactionDocumentsPage({super.key, required this.transaction});
  @override
  State<TransactionDocumentsPage> createState() => _TransactionDocumentsPageState();
}

class _TransactionDocumentsPageState extends State<TransactionDocumentsPage> {
  List<TransactionDocument> _docs = const [];
  bool _loading = true;
  String _query = '';
  String _categoryFilter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await DocumentService.listForTransaction(widget.transaction.id,
        userId: AppScope.activeUserId, includeDeleted: false);
    if (!mounted) return;
    setState(() { _docs = docs; _loading = false; });
  }

  List<TransactionDocument> get _filtered {
    final q = _query.trim().toLowerCase();
    return _docs.where((d) {
      if (_categoryFilter != 'all' && (d.category ?? '') != _categoryFilter) return false;
      if (q.isEmpty) return true;
      return d.fileName.toLowerCase().contains(q) || (d.note ?? '').toLowerCase().contains(q) || (d.category ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addFile() async {
    try {
      const typeGroup = XTypeGroup(label: 'Justificatifs', extensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic']);
      final files = await openFiles(acceptedTypeGroups: const [typeGroup]);
      if (files.isEmpty) return;
      for (final xf in files) {
        await DocumentService.importFile(transactionId: widget.transaction.id, source: File(xf.path), displayName: xf.name, userId: AppScope.activeUserId);
      }
      await _load();
      if (mounted) tenaShowSnack(context, '${files.length} justificatif(s) ajouté(s) localement.');
      return;
    } catch (_) {
      // repli chemin manuel (plateformes sans implémentation de sélecteur)
    }
    if (!mounted) return;
    final pathCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
      title: const Text('Ajouter un justificatif (chemin local)'),
      content: TextField(controller: pathCtrl, decoration: const InputDecoration(labelText: 'Chemin du fichier (PDF/image)', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Annuler')), FilledButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Importer'))],
    ));
    if (ok != true) return;
    final path = pathCtrl.text.trim();
    if (path.isEmpty) return;
    try {
      await DocumentService.importFile(transactionId: widget.transaction.id, source: File(path), userId: AppScope.activeUserId);
      await _load();
      if (mounted) tenaShowSnack(context, 'Justificatif ajouté localement.');
    } catch (e) {
      if (mounted) tenaShowSnack(context, 'Import impossible : $e', error: true);
    }
  }

  Future<void> _preview(TransactionDocument d) async {
    final f = await DocumentService.resolveFile(d);
    if (!mounted) return;
    if (f == null) {
      await showDialog<void>(context: context, builder: (c)=>AlertDialog(title: const Text('Fichier manquant'), content: Text('Le fichier local est introuvable/corrompu.\nRelatif: ${d.relativePath}'), actions: [FilledButton(onPressed: ()=>Navigator.pop(c), child: const Text('Fermer'))]));
      return;
    }
    final isImage = d.mimeType.startsWith('image/');
    final isPdf = d.mimeType == 'application/pdf';
    await showDialog<void>(context: context, builder: (c)=>AlertDialog(
      title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(width: 520, child: isImage ? Image.file(f, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Text('Aperçu image impossible (fichier invalide).'))
        : Text(isPdf ? 'PDF stocké localement (conservé/restaurable).\nRelatif: ${d.relativePath}\nTaille: ${d.sizeBytes} o\nSHA-256: ${d.sha256 ?? '—'}' : 'Type: ${d.mimeType}\nTaille: ${d.sizeBytes} o\nRelatif: ${d.relativePath}')),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Fermer'))],
    ));
  }

  Future<void> _edit(TransactionDocument d) async {
    final name = TextEditingController(text: d.fileName);
    final cat = TextEditingController(text: d.category ?? '');
    final note = TextEditingController(text: d.note ?? '');
    final ok = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
      title: const Text('Métadonnées'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
        const SizedBox(height: 8),
        TextField(controller: cat, decoration: const InputDecoration(labelText: 'Catégorie')),
        const SizedBox(height: 8),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Annuler')), FilledButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Enregistrer'))],
    ));
    if (ok != true) return;
    await DocumentService.updateMetadata(d.copyWith(fileName: name.text.trim().isEmpty? d.fileName:name.text.trim(), category: cat.text.trim().isEmpty? null:cat.text.trim(), note: note.text.trim().isEmpty? null:note.text.trim()));
    await _load();
  }

  Future<void> _delete(TransactionDocument d) async {
    bool delFile = false;
    final ok = await showDialog<bool>(context: context, builder: (c)=>StatefulBuilder(builder: (c,setS)=>AlertDialog(
      title: const Text('Suppression contrôlée'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Retrait du justificatif (suppression logique). Aucune perte silencieuse.'),
        CheckboxListTile(value: delFile, onChanged: (v)=>setS(()=>delFile=v??false), title: const Text('Supprimer aussi le fichier local copié'), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
      ]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Annuler')), FilledButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Supprimer'))],
    )));
    if (ok != true) return;
    await DocumentService.deleteDocument(d.id, userId: AppScope.activeUserId, deleteFile: delFile);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cats = {'all', ..._docs.map((d)=>d.category).whereType<String>().where((c)=>c.isNotEmpty)}.toList();
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Justificatifs')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addFile, icon: const Icon(Icons.attach_file), label: const Text('Ajouter')),
      body: Padding(padding: const EdgeInsets.all(TenaSpacing.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TenaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Transaction: ${widget.transaction.description.isEmpty ? widget.transaction.category : widget.transaction.description}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Local/offline. Chemins relatifs en base, fichiers copiés sous l’espace app. Sauvegarde/restauration réelles.', style: TextStyle(color: TenaColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(onChanged: (v)=>setState(()=>_query=v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher / filtrer (nom, note, catégorie)', isDense: true, border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            DropdownButton<String>(value: cats.contains(_categoryFilter)?_categoryFilter:'all', items: cats.map((c)=>DropdownMenuItem(value: c, child: Text(c=='all'?'Toutes catégories':c))).toList(), onChanged: (v)=>setState(()=>_categoryFilter=v??'all')),
          ]),
        ])),
        const SizedBox(height: 12),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : items.isEmpty ? const Center(child: Text('Aucun justificatif. Ajoutez un PDF ou une image.', style: TextStyle(color: TenaColors.textSecondary)))
          : ListView.separated(itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (c,i){
            final d = items[i];
            return FutureBuilder<bool>(future: DocumentService.fileExists(d), builder: (c,s){
              final exists = s.data ?? true;
              return Card(child: ListTile(
                leading: Icon(d.mimeType.startsWith('image/')?Icons.image_outlined:Icons.picture_as_pdf_outlined, color: exists?TenaColors.gold:TenaColors.danger),
                title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${d.category ?? 'Sans catégorie'} • ${d.createdAt.length>=10?d.createdAt.substring(0,10):''} • ${d.sizeBytes} o${exists ? '' : ' • FICHIER MANQUANT'}${d.note!=null && d.note!.isNotEmpty ? ' • ${d.note}' : ''}', maxLines: 2),
                onTap: ()=>_preview(d),
                trailing: Wrap(spacing: 0, children: [
                  IconButton(tooltip: 'Modifier métadonnées', icon: const Icon(Icons.edit_outlined), onPressed: ()=>_edit(d)),
                  IconButton(tooltip: 'Supprimer (contrôlé)', icon: const Icon(Icons.delete_outline), onPressed: ()=>_delete(d)),
                ]),
              ));
            });
          })),
      ])),
    );
  }
}
