/// Action item (inbox / task / reminder) returned by /v1/action-items
class ActionItemModel {
  final int    id;
  final String kind;        // 'reminder' | 'task' | 'meeting' | 'event'
  final String source;      // 'chat' | 'email' | 'brain_dump' | 'manual'
  final String title;
  final String status;      // 'active' | 'done'
  final String? remindAt;   // ISO-8601
  final String? startsAt;
  final String? endsAt;
  final bool   needsReview;

  const ActionItemModel({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.status,
    this.remindAt,
    this.startsAt,
    this.endsAt,
    this.needsReview = false,
  });

  factory ActionItemModel.fromJson(Map<String, dynamic> j) => ActionItemModel(
    id:          (j['id'] as num).toInt(),
    kind:        j['kind']   as String? ?? 'task',
    source:      j['source'] as String? ?? 'chat',
    title:       j['title']  as String? ?? '',
    status:      j['status'] as String? ?? 'active',
    remindAt:    j['remind_at'] as String?,
    startsAt:    j['starts_at'] as String?,
    endsAt:      j['ends_at']   as String?,
    needsReview: j['needs_review'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'kind':         kind,
    'source':       source,
    'title':        title,
    'status':       status,
    'remind_at':    remindAt,
    'starts_at':    startsAt,
    'ends_at':      endsAt,
    'needs_review': needsReview,
  };

  ActionItemModel copyWith({
    int? id, String? kind, String? source, String? title,
    String? status, String? remindAt, String? startsAt,
    String? endsAt, bool? needsReview,
  }) => ActionItemModel(
    id:          id          ?? this.id,
    kind:        kind        ?? this.kind,
    source:      source      ?? this.source,
    title:       title       ?? this.title,
    status:      status      ?? this.status,
    remindAt:    remindAt    ?? this.remindAt,
    startsAt:    startsAt    ?? this.startsAt,
    endsAt:      endsAt      ?? this.endsAt,
    needsReview: needsReview ?? this.needsReview,
  );
}
