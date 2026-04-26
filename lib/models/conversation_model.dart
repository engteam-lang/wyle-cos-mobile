/// Conversation thread returned by GET /v1/chat/conversations
class ConversationModel {
  final int     id;
  final String? title;
  /// ISO-8601 string — present when the backend includes it (not all versions do)
  final String? createdAt;
  final String? updatedAt;

  const ConversationModel({
    required this.id,
    this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> j) =>
      ConversationModel(
        id:        (j['id'] as num).toInt(),
        title:     j['title']      as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

// ── Single message inside a conversation thread ────────────────────────────────
/// Returned by GET /v1/chat/conversations/{id}/messages
class ConversationMessageModel {
  final int     id;
  final String  role;       // 'user' | 'assistant'
  final String  content;
  final String? createdAt;  // ISO-8601 if backend includes it

  const ConversationMessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  factory ConversationMessageModel.fromJson(Map<String, dynamic> j) =>
      ConversationMessageModel(
        id:        (j['id'] as num).toInt(),
        role:      j['role']       as String? ?? 'user',
        content:   j['content']    as String? ?? '',
        createdAt: j['created_at'] as String?,
      );
}

// ── Suggested action inside a chat response ────────────────────────────────────
class SuggestedAction {
  final String  kind;
  final String  title;
  final String? remindAt;
  final String? startsAt;

  const SuggestedAction({
    required this.kind,
    required this.title,
    this.remindAt,
    this.startsAt,
  });

  factory SuggestedAction.fromJson(Map<String, dynamic> j) => SuggestedAction(
    kind:     j['kind']      as String? ?? 'task',
    title:    j['title']     as String? ?? '',
    remindAt: j['remind_at'] as String?,
    startsAt: j['starts_at'] as String?,
  );
}

// ── Full response from POST /v1/chat/messages ──────────────────────────────────
class ChatApiResponse {
  final int            conversationId;
  final int            userMessageId;
  final int            assistantMessageId;
  final String         assistantContent;
  final List<SuggestedAction> suggestedActions;
  final List<int>      persistedActionItemIds;
  /// IDs of the user's existing action items that the backend wants to mark
  /// as completed (e.g. when the user says "I paid the school fees").
  /// Backend must populate this field; it is empty by default so older
  /// backend versions are fully backward-compatible.
  final List<int>      completedActionItemIds;
  /// Non-empty when the backend detected a scheduling conflict and wants the
  /// user to pick one of the [suggestedActions] alternatives (A, B, C…).
  /// Each element is a raw JSON object from the backend; the UI only needs to
  /// know that this list is non-empty to trigger the interactive picker.
  final List<dynamic>  scheduleConflictAlternatives;
  /// True when the backend cleared all tasks for the user.
  final bool           taskListClearAll;

  const ChatApiResponse({
    required this.conversationId,
    required this.userMessageId,
    required this.assistantMessageId,
    required this.assistantContent,
    required this.suggestedActions,
    required this.persistedActionItemIds,
    this.completedActionItemIds          = const [],
    this.scheduleConflictAlternatives    = const [],
    this.taskListClearAll                = false,
  });

  factory ChatApiResponse.fromJson(Map<String, dynamic> j) => ChatApiResponse(
    conversationId:      (j['conversation_id']       as num).toInt(),
    userMessageId:       (j['user_message_id']        as num).toInt(),
    assistantMessageId:  (j['assistant_message_id']   as num).toInt(),
    assistantContent:     j['assistant_content']       as String? ?? '',
    suggestedActions:    (j['suggested_actions'] as List? ?? [])
        .map((e) => SuggestedAction.fromJson(e as Map<String, dynamic>))
        .toList(),
    persistedActionItemIds: (j['persisted_action_item_ids'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    completedActionItemIds: (j['completed_action_item_ids'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    scheduleConflictAlternatives:
        ((j['ai_meta'] as Map<String, dynamic>?)?['schedule_conflict_alternatives'] as List? ?? []),
    taskListClearAll:
        ((j['ai_meta'] as Map<String, dynamic>?)?['task_list_clear_all'] as bool?) ?? false,
  );
}
