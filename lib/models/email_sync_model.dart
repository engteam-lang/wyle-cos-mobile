/// Email sync job returned by POST /v1/integrations/email/sync
class EmailSyncJobModel {
  final int     id;
  final String  provider;      // 'gmail' | 'microsoft'
  final String  status;        // 'queued' | 'running' | 'done' | 'dead'
  final int     attempts;
  final int     maxRetries;
  final String? errorMessage;

  const EmailSyncJobModel({
    required this.id,
    required this.provider,
    required this.status,
    required this.attempts,
    required this.maxRetries,
    this.errorMessage,
  });

  factory EmailSyncJobModel.fromJson(Map<String, dynamic> j) =>
      EmailSyncJobModel(
        id:           (j['id']          as num).toInt(),
        provider:      j['provider']    as String? ?? 'gmail',
        status:        j['status']      as String? ?? 'queued',
        attempts:     (j['attempts']    as num?)?.toInt() ?? 0,
        maxRetries:   (j['max_retries'] as num?)?.toInt() ?? 5,
        errorMessage:  j['error_message'] as String?,
      );

  bool get isDone  => status == 'done';
  bool get isDead  => status == 'dead';
  bool get isPending => !isDone && !isDead;
}

/// Sync stub response (demo): { "ingested": 2, "ids": [201, 202] }
class EmailSyncStubResult {
  final int       ingested;
  final List<int> ids;
  const EmailSyncStubResult({required this.ingested, required this.ids});
  factory EmailSyncStubResult.fromJson(Map<String, dynamic> j) =>
      EmailSyncStubResult(
        ingested: (j['ingested'] as num?)?.toInt() ?? 0,
        ids: (j['ids'] as List? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}
