import 'dart:convert';

/// Justificatif/pièce jointe lié à une transaction (stockage local).
/// Le chemin est RELATIF à la racine des documents Tena (jamais absolu en base).
class TransactionDocument {
  final String id;
  final String transactionId;
  final String fileName;
  final String relativePath;
  final String mimeType;
  final int sizeBytes;
  final String? category;
  final String createdAt; // ISO-8601 UTC
  final String updatedAt; // ISO-8601 UTC
  final String? note;
  final String? sha256; // optionnel, intégrité locale
  final bool isDeleted;

  const TransactionDocument({
    required this.id,
    required this.transactionId,
    required this.fileName,
    required this.relativePath,
    required this.mimeType,
    required this.sizeBytes,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.sha256,
    this.isDeleted = false,
  });

  TransactionDocument copyWith({
    String? fileName,
    String? category,
    String? note,
    String? updatedAt,
    bool? isDeleted,
  }) => TransactionDocument(
        id: id,
        transactionId: transactionId,
        fileName: fileName ?? this.fileName,
        relativePath: relativePath,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        category: category ?? this.category,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        note: note ?? this.note,
        sha256: sha256,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'fileName': fileName,
        'relativePath': relativePath,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'category': category,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'note': note,
        'sha256': sha256,
        'isDeleted': isDeleted,
      };

  factory TransactionDocument.fromJson(Map<String, dynamic> json) =>
      TransactionDocument(
        id: json['id'] as String,
        transactionId: json['transactionId'] as String,
        fileName: (json['fileName'] as String?) ?? 'document',
        relativePath: json['relativePath'] as String,
        mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        category: json['category'] as String?,
        createdAt: (json['createdAt'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
        updatedAt: (json['updatedAt'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
        note: json['note'] as String?,
        sha256: json['sha256'] as String?,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
}
