/// Conversation thread returned by GET /v1/chat/conversations
class ConversationModel {
  final int     id;
  final String? title;

  const ConversationModel({required this.id, this.title});

  factory ConversationModel.fromJson(Map<String, dynamic> j) =>
      ConversationModel(
        id:    (j['id'] as num).toInt(),
        title: j['title'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

// ── Single message inside a conversation thread ────────────────────────────────
/// Returned by GET /v1/chat/conversations/{id}/messages
class ConversationMessageModel {
  final int    id;
  final String role;    // 'user' | 'assistant'
  final String content;

  const ConversationMessageModel({
    required this.id,
    required this.role,
    required this.content,
  });

  factory ConversationMessageModel.fromJson(Map<String, dynamic> j) =>
      ConversationMessageModel(
        id:      (j['id'] as num).toInt(),
        role:    j['role']    as String? ?? 'user',
        content: j['content'] as String? ?? '',
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

  const ChatApiResponse({
    required this.conversationId,
    required this.userMessageId,
    required this.assistantMessageId,
    required this.assistantContent,
    required this.suggestedActions,
    required this.persistedActionItemIds,
    this.completedActionItemIds = const [],
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
  );
}
