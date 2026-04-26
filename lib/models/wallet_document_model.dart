/// Single document entry from GET /v1/document-wallet/documents
class WalletDocumentModel {
  final int     id;
  final String  filename;
  final String  mimeType;
  final int     sizeBytes;
  final String? webViewLink;
  final String? driveFileId;
  final int?    conversationId;
  final int?    sourceUserMessageId;
  final DateTime? createdAt;

  const WalletDocumentModel({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.webViewLink,
    this.driveFileId,
    this.conversationId,
    this.sourceUserMessageId,
    this.createdAt,
  });

  factory WalletDocumentModel.fromJson(Map<String, dynamic> j) =>
      WalletDocumentModel(
        id:                  (j['id']       as num).toInt(),
        filename:             j['filename']  as String? ?? '',
        mimeType:             j['mime_type'] as String? ?? '',
        sizeBytes:           (j['size_bytes'] as num?)?.toInt() ?? 0,
        webViewLink:          j['web_view_link']          as String?,
        driveFileId:          j['drive_file_id']          as String?,
        conversationId:      (j['conversation_id']         as num?)?.toInt(),
        sourceUserMessageId: (j['source_user_message_id'] as num?)?.toInt(),
        createdAt: () {
          final s = j['created_at'] as String?;
          if (s == null) return null;
          try { return DateTime.parse(s); } catch (_) { return null; }
        }(),
      );

  /// Human-readable file size: "1.2 MB", "340 KB", "8 B"
  String get readableSize {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }
}
