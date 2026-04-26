/// Models for GET /v1/briefs and PATCH /v1/briefs/schedule

// ── Single brief entry ─────────────────────────────────────────────────────────
class BriefEntry {
  final String       localDate;   // "2026-04-26"
  final String       slot;        // "morning" | "evening"
  final String       title;
  final String       body;
  final List<String> highlights;
  final String?      modelUsed;
  final DateTime?    createdAt;

  const BriefEntry({
    required this.localDate,
    required this.slot,
    required this.title,
    required this.body,
    required this.highlights,
    this.modelUsed,
    this.createdAt,
  });

  factory BriefEntry.fromJson(Map<String, dynamic> j) => BriefEntry(
    localDate:  j['local_date']  as String? ?? '',
    slot:       j['slot']        as String? ?? 'morning',
    title:      j['title']       as String? ?? '',
    body:       j['body']        as String? ?? '',
    highlights: (j['highlights'] as List? ?? []).map((e) => '$e').toList(),
    modelUsed:  j['model_used']  as String?,
    createdAt: () {
      final s = j['created_at'] as String?;
      if (s == null) return null;
      try { return DateTime.parse(s); } catch (_) { return null; }
    }(),
  );

  bool get isMorning => slot == 'morning';
}

// ── Full response from GET /v1/briefs ──────────────────────────────────────────
class BriefListResponse {
  final String       timezone;
  final String?      morningBriefLocal;   // "07:00"
  final String?      eveningBriefLocal;   // "19:30"
  final bool         briefsEnabled;
  final List<BriefEntry> briefs;

  const BriefListResponse({
    required this.timezone,
    this.morningBriefLocal,
    this.eveningBriefLocal,
    required this.briefsEnabled,
    required this.briefs,
  });

  factory BriefListResponse.fromJson(Map<String, dynamic> j) => BriefListResponse(
    timezone:          j['timezone']            as String? ?? '',
    morningBriefLocal: j['morning_brief_local'] as String?,
    eveningBriefLocal: j['evening_brief_local'] as String?,
    briefsEnabled:     j['briefs_enabled']      as bool?   ?? true,
    briefs: (j['briefs'] as List? ?? [])
        .map((e) => BriefEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── Response from PATCH /v1/briefs/schedule ────────────────────────────────────
class BriefScheduleResponse {
  final String  timezone;
  final String? morningBriefLocal;
  final String? eveningBriefLocal;
  final bool    briefsEnabled;

  const BriefScheduleResponse({
    required this.timezone,
    this.morningBriefLocal,
    this.eveningBriefLocal,
    required this.briefsEnabled,
  });

  factory BriefScheduleResponse.fromJson(Map<String, dynamic> j) =>
      BriefScheduleResponse(
        timezone:          j['timezone']            as String? ?? '',
        morningBriefLocal: j['morning_brief_local'] as String?,
        eveningBriefLocal: j['evening_brief_local'] as String?,
        briefsEnabled:     j['briefs_enabled']      as bool?   ?? true,
      );
}
