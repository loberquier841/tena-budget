import 'package:flutter/material.dart';
import '../models/transaction_document.dart';
import '../services/app_scope.dart';
import '../services/database_service.dart';
import '../services/document_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';
import 'transaction_documents_page.dart';

/// Vue globale des justificatifs (toutes transactions, scope actif). Données réelles.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<TransactionDocument> _docs = const [];
  bool _loading = true;
  String _query = '';
  String _categoryFilter = 'all';
  bool _onlyMissing = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await DatabaseService.instance.getAllDocuments(userId: AppScope.activeUserId, includeDeleted: false);
    if (!mounted) return;
    setState(() { _docs = docs; _loading = false; });
  }

  Future<void> _open(TransactionDocument d) async {
    final txs = await DatabaseService.instance.getTransactions(userId: AppScope.activeUserId);
    final tx = txs.where((t) => t.id == d.transactionId).toList();
    if (!mounted) return;
    if (tx.isEmpty) {
      tenaShowSnack(context, 'Transaction liée introuvable (relation conservée).', error: true);
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDocumentsPage(transaction: tx.first)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final cats = {'all', ..._docs.map((d)=>d.category).whereType<String>().where((c)=>c.isNotEmpty)}.toList();
    final base = _docs.where((d) {
      if (_categoryFilter != 'all' && (d.category ?? '') != _categoryFilter) return false;
      if (q.isEmpty) return true;
      return d.fileName.toLowerCase().contains(q) || (d.note ?? '').toLowerCase().contains(q) || d.transactionId.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Documents / Justificatifs'), actions: [IconButton(tooltip: 'Actualiser', onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: Padding(padding: const EdgeInsets.all(TenaSpacing.lg), child: Column(children: [
        TenaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_docs.length} justificatif(s) (profil actif)', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Stockage local/offline. Chemins relatifs, métadonnées persistantes, sauvegarde/restauration réelles. Aucun envoi réseau.', style: TextStyle(color: TenaColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(onChanged: (v)=>setState(()=>_query=v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher (nom, note, transaction)', isDense: true, border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            DropdownButton<String>(value: cats.contains(_categoryFilter)?_categoryFilter:'all', items: cats.map((c)=>DropdownMenuItem(value: c, child: Text(c=='all'?'Toutes':c))).toList(), onChanged: (v)=>setState(()=>_categoryFilter=v??'all')),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Afficher uniquement les fichiers manquants'), value: _onlyMissing, onChanged: (v)=>setState(()=>_onlyMissing=v)),
        ])),
        const SizedBox(height: 12),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : base.isEmpty ? const Center(child: Text('Aucun justificatif. Ajoutez-en depuis une transaction.', style: TextStyle(color: TenaColors.textSecondary)))
          : ListView.separated(itemCount: base.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (c,i){
            final d = base[i];
            return FutureBuilder<bool>(future: DocumentService.fileExists(d), builder: (c,s){
              final exists = s.data ?? true;
              if (_onlyMissing && exists) return const SizedBox.shrink();
              return Card(child: ListTile(
                leading: Icon(d.mimeType.startsWith('image/')?Icons.image_outlined:Icons.picture_as_pdf_outlined, color: exists?TenaColors.gold:TenaColors.danger),
                title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${d.category ?? 'Sans catégorie'} • tx:${d.transactionId.substring(0, d.transactionId.length.clamp(0,8))} • ${d.createdAt.length>=10?d.createdAt.substring(0,10):''}${exists?'':' • FICHIER MANQUANT'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: ()=>_open(d),
              ));
            });
          })),
      ])),
    );
  }
}
