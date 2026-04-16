class MorningBriefModel {
  final String greeting;
  final String headline;
  final double lifeOptimizationScore;
  final List<BriefPriority> topPriorities;
  final List<BriefCompletedItem> completedItems;
  final String? tomorrowPreview;
  final BriefStats stats;
  final String tip;

  const MorningBriefModel({
    required this.greeting,
    required this.headline,
    required this.lifeOptimizationScore,
    required this.topPriorities,
    this.completedItems = const [],
    this.tomorrowPreview,
    required this.stats,
    required this.tip,
  });

  factory MorningBriefModel.fromJson(Map<String, dynamic> json) {
    return MorningBriefModel(
      greeting:               json['greeting'] ?? '',
      headline:               json['headline'] ?? '',
      lifeOptimizationScore:  (json['lifeOptimizationScore'] as num?)?.toDouble() ?? 0,
      topPriorities: (json['topPriorities'] as List<dynamic>? ?? [])
          .map((e) => BriefPriority.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedItems: (json['completedItems'] as List<dynamic>? ?? [])
          .map((e) => BriefCompletedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      tomorrowPreview: json['tomorrowPreview'],
      stats: BriefStats.fromJson(json['stats'] ?? {}),
      tip:   json['tip'] ?? '',
    );
  }
}

class BriefPriority {
  final String id;
  final String title;
  final String type;
  final String riskLevel;
  final String emoji;
  final int? daysUntil;
  final String? executionPath;
  final String action;

  const BriefPriority({
    required this.id,
    required this.title,
    required this.type,
    required this.riskLevel,
    required this.emoji,
    this.daysUntil,
    this.executionPath,
    required this.action,
  });

  factory BriefPriority.fromJson(Map<String, dynamic> json) => BriefPriority(
    id:            json['id'] ?? '',
    title:         json['title'] ?? '',
    type:          json['type'] ?? 'custom',
    riskLevel:     json['riskLevel'] ?? 'low',
    emoji:         json['emoji'] ?? '📦',
    daysUntil:     json['daysUntil'],
    executionPath: json['executionPath'],
    action:        json['action'] ?? '',
  );
}

class BriefCompletedItem {
  final String id;
  final String title;
  final String emoji;
  final String? completedNote;

  const BriefCompletedItem({
    required this.id,
    required this.title,
    required this.emoji,
    this.completedNote,
  });

  factory BriefCompletedItem.fromJson(Map<String, dynamic> json) => BriefCompletedItem(
    id:            json['id'] ?? '',
    title:         json['title'] ?? '',
    emoji:         json['emoji'] ?? '✓',
    completedNote: json['completedNote'],
  );
}

class BriefStats {
  final int obligationsTracked;
  final String timeSavedThisWeek;
  final int decisionsHandled;

  const BriefStats({
    required this.obligationsTracked,
    required this.timeSavedThisWeek,
    required this.decisionsHandled,
  });

  factory BriefStats.fromJson(Map<String, dynamic> json) => BriefStats(
    obligationsTracked: json['obligationsTracked'] ?? 0,
    timeSavedThisWeek:  json['timeSavedThisWeek'] ?? '0h',
    decisionsHandled:   json['decisionsHandled'] ?? 0,
  );
}
