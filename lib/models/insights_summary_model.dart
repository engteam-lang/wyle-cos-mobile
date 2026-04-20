/// Insights summary returned by GET /v1/insights/summary
class InsightsSummaryModel {
  final int    productivityScore;
  final double hoursSavedEstimate;
  final int    tasksDone;
  final int    meetingsCount;
  final int    messagesCount;
  final WeeklyPatternData weeklyPattern;

  const InsightsSummaryModel({
    this.productivityScore   = 0,
    this.hoursSavedEstimate  = 0,
    this.tasksDone           = 0,
    this.meetingsCount       = 0,
    this.messagesCount       = 0,
    required this.weeklyPattern,
  });

  factory InsightsSummaryModel.fromJson(Map<String, dynamic> j) =>
      InsightsSummaryModel(
        productivityScore:   (j['productivity_score']   as num?)?.toInt()    ?? 0,
        hoursSavedEstimate:  (j['hours_saved_estimate'] as num?)?.toDouble() ?? 0,
        tasksDone:           (j['tasks_done']           as num?)?.toInt()    ?? 0,
        meetingsCount:       (j['meetings_count']       as num?)?.toInt()    ?? 0,
        messagesCount:       (j['messages_count']       as num?)?.toInt()    ?? 0,
        weeklyPattern: j['weekly_pattern'] != null
            ? WeeklyPatternData.fromJson(j['weekly_pattern'] as Map<String, dynamic>)
            : const WeeklyPatternData(),
      );

  /// Fallback when the API is unavailable
  static InsightsSummaryModel get empty => InsightsSummaryModel(
    weeklyPattern: const WeeklyPatternData(),
  );
}

class WeeklyPatternData {
  final List<String> bestDays;
  final String       insightText;
  final int          windowDays;

  const WeeklyPatternData({
    this.bestDays   = const [],
    this.insightText = '',
    this.windowDays  = 28,
  });

  factory WeeklyPatternData.fromJson(Map<String, dynamic> j) => WeeklyPatternData(
    bestDays:    List<String>.from(j['best_days'] ?? []),
    insightText: j['insight_text'] as String? ?? '',
    windowDays:  (j['window_days'] as num?)?.toInt() ?? 28,
  );
}
