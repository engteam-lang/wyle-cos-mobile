import 'conversation_model.dart';

/// Brain-dump job returned by POST /v1/brain-dump/jobs and upload/poll
class BrainDumpJobModel {
  final int     id;
  final String  status;           // queued | transcribing | extracting | awaiting_review | done | failed
  final String? transcript;
  final String? extractionJson;   // raw JSON string of extracted items
  final String? errorMessage;

  /// Buddy's natural-language reply — mirrors `assistant_content` in the
  /// chat message API.  Populated once the job reaches awaiting_review/done.
  final String? assistantContent;

  /// Zero or more action-item proposals extracted from the voice note.
  /// Same schema as `suggested_actions` in POST /v1/chat/messages.
  final List<SuggestedAction> suggestedActions;

  /// The conversation thread this brain-dump was threaded into (if any).
  final int? conversationId;

  const BrainDumpJobModel({
    required this.id,
    required this.status,
    this.transcript,
    this.extractionJson,
    this.errorMessage,
    this.assistantContent,
    this.suggestedActions = const [],
    this.conversationId,
  });

  factory BrainDumpJobModel.fromJson(Map<String, dynamic> j) =>
      BrainDumpJobModel(
        id:             (j['id'] as num).toInt(),
        status:          j['status']          as String? ?? 'queued',
        transcript:      j['transcript']      as String?,
        extractionJson:  j['extraction_json'] as String?,
        errorMessage:    j['error_message']   as String?,
        assistantContent: j['assistant_content'] as String?,
        suggestedActions: (j['suggested_actions'] as List? ?? [])
            .map((e) => SuggestedAction.fromJson(e as Map<String, dynamic>))
            .toList(),
        conversationId:  (j['conversation_id'] as num?)?.toInt(),
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
