/// Brain-dump job returned by POST /v1/brain-dump/jobs and upload/poll
class BrainDumpJobModel {
  final int     id;
  final String  status;           // queued | transcribing | extracting | awaiting_review | done | failed
  final String? transcript;
  final String? extractionJson;   // raw JSON string of extracted items
  final String? errorMessage;

  const BrainDumpJobModel({
    required this.id,
    required this.status,
    this.transcript,
    this.extractionJson,
    this.errorMessage,
  });

  factory BrainDumpJobModel.fromJson(Map<String, dynamic> j) =>
      BrainDumpJobModel(
        id:             (j['id'] as num).toInt(),
        status:          j['status']          as String? ?? 'queued',
        transcript:      j['transcript']      as String?,
        extractionJson:  j['extraction_json'] as String?,
        errorMessage:    j['error_message']   as String?,
      );

  bool get isComplete =>
      status == 'awaiting_review' || status == 'done';
  bool get isFailed => status == 'failed';
  bool get isPending =>
      status == 'queued' || status == 'transcribing' || status == 'extracting';
}

/// Commit response: { "created_ids": [101, 102] }
class BrainDumpCommitResult {
  final List<int> createdIds;
  const BrainDumpCommitResult({required this.createdIds});
  factory BrainDumpCommitResult.fromJson(Map<String, dynamic> j) =>
      BrainDumpCommitResult(
        createdIds: (j['created_ids'] as List? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}
