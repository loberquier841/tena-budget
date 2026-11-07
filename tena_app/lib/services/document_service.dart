import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/transaction_document.dart';
import 'app_scope.dart';
import 'database_service.dart';

/// Stockage local des justificatifs (images/PDF). Hors ligne, aucun serveur.
/// Fichiers copiés sous `documents_root/tena_attachments/<userId>/...`
/// La base ne stocke que des chemins RELATIFS à cette racine + métadonnées.
class DocumentService {
  DocumentService._();

  @visibleForTesting
  static String? testDocumentsRoot;

  static Future<String> documentsRoot() async {
    if (testDocumentsRoot != null) return testDocumentsRoot!;
    final dir = await getApplicationDocumentsDirectory();
    final root = p.join(dir.path, 'tena_attachments');
    await Directory(root).create(recursive: true);
    return root;
  }

  static String _safeSegment(String input) =>
      input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static Future<File> _resolveRelative(String relativePath) async {
    final root = await documentsRoot();
    final full = p.normalize(p.join(root, relativePath));
    final normRoot = p.normalize(root);
    if (!full.startsWith(normRoot)) {
      throw StateError('PATH_TRAVERSAL_BLOCKED');
    }
    return File(full);
  }

  static String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  static Future<TransactionDocument> importFile({
    required String transactionId,
    required File source,
    String? displayName,
    String? category,
    String? note,
    String userId = AppScope.activeUserId,
  }) async {
    if (!await source.exists()) {
      throw StateError('SOURCE_FILE_MISSING');
    }
    final bytes = await source.readAsBytes();
    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'doc_${DateTime.now().microsecondsSinceEpoch}_${bytes.length}';
    final rawName = displayName ?? p.basename(source.path);
    final safeName = _safeSegment(rawName);
    final rel = p.join(userId, transactionId, '${id}_$safeName');
    final target = await _resolveRelative(rel);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    final sha = crypto_hash.sha256.convert(bytes).toString();
    final doc = TransactionDocument(
      id: id,
      transactionId: transactionId,
      fileName: rawName,
      relativePath: rel.replaceAll('\\', '/'),
      mimeType: _mimeFromName(rawName),
      sizeBytes: bytes.length,
      category: category,
      createdAt: now,
      updatedAt: now,
      note: note,
      sha256: sha,
    );
    await DatabaseService.instance.insertDocument(doc, userId: userId);
    return doc;
  }

  static Future<List<TransactionDocument>> listForTransaction(
      String transactionId,
      {String userId = AppScope.activeUserId,
      bool includeDeleted = false}) {
    return DatabaseService.instance.getDocumentsForTransaction(transactionId,
        userId: userId, includeDeleted: includeDeleted);
  }

  static Future<File?> resolveFile(TransactionDocument doc) async {
    try {
      final f = await _resolveRelative(doc.relativePath);
      if (await f.exists()) return f;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> fileExists(TransactionDocument doc) async =>
      (await resolveFile(doc)) != null;

  static Future<void> updateMetadata(TransactionDocument doc,
      {String userId = AppScope.activeUserId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await DatabaseService.instance.updateDocument(doc.copyWith(updatedAt: now),
        userId: userId);
  }

  /// Suppression contrôlée: soft-delete en base; fichier conservé sauf [deleteFile].
  static Future<void> deleteDocument(String id,
      {String userId = AppScope.activeUserId, bool deleteFile = false}) async {
    if (deleteFile) {
      final doc = await DatabaseService.instance.getDocumentById(id, userId: userId);
      if (doc != null) {
        final f = await resolveFile(doc);
        if (f != null && await f.exists()) {
          try { await f.delete(); } catch (_) {}
        }
      }
    }
    await DatabaseService.instance.deleteDocument(id, userId: userId);
  }

  static Future<void> restoreDocument(String id,
      {String userId = AppScope.activeUserId}) =>
      DatabaseService.instance.restoreDocument(id, userId: userId);

  /// Pour backup: métadonnées + contenu base64 (si fichier présent).
  static Future<List<Map<String, dynamic>>> exportForBackup(
      {String userId = AppScope.activeUserId}) async {
    final docs = await DatabaseService.instance.getAllDocuments(userId: userId);
    final out = <Map<String, dynamic>>[];
    for (final d in docs) {
      final json = d.toJson();
      final f = await resolveFile(d);
      if (f != null && await f.exists()) {
        try {
          json['contentBase64'] = base64Encode(await f.readAsBytes());
        } catch (_) {
          json['contentMissing'] = true;
        }
      } else {
        json['contentMissing'] = true;
      }
      out.add(json);
    }
    return out;
  }

  static Future<int> importFromBackup(List<dynamic> items,
      {String userId = AppScope.activeUserId}) async {
    var n = 0;
    for (final raw in items) {
      if (raw is! Map) continue;
      try {
        final m = Map<String, dynamic>.from(raw);
        final b64 = m['contentBase64'] as String?;
        final doc = TransactionDocument.fromJson(m);
        await DatabaseService.instance.upsertDocument(doc, userId: userId);
        if (b64 != null && b64.isNotEmpty) {
          final target = await _resolveRelative(doc.relativePath);
          await target.parent.create(recursive: true);
          await target.writeAsBytes(base64Decode(b64), flush: true);
        }
        n++;
      } catch (_) {
        // élément ignoré, pas de perte silencieuse globale (rapport backup)
      }
    }
    return n;
  }
}
