class InsightsModel {
  final double lifeOptimizationScore;
  final TimeSaved timeSaved;
  final DecisionsData decisions;
  final MoneySaved moneySaved;
  final ObligationsStats obligations;
  final ReliabilityData reliability;
  final int autonomyTier;

  const InsightsModel({
    this.lifeOptimizationScore = 0,
    required this.timeSaved,
    required this.decisions,
    required this.moneySaved,
    required this.obligations,
    required this.reliability,
    this.autonomyTier = 1,
  });

  factory InsightsModel.fromJson(Map<String, dynamic> json) {
    return InsightsModel(
      lifeOptimizationScore: (json['lifeOptimizationScore'] as num?)?.toDouble() ?? 0,
      timeSaved:   TimeSaved.fromJson(json['timeSaved'] ?? {}),
      decisions:   DecisionsData.fromJson(json['decisions'] ?? {}),
      moneySaved:  MoneySaved.fromJson(json['moneySaved'] ?? {}),
      obligations: ObligationsStats.fromJson(json['obligations'] ?? {}),
      reliability: ReliabilityData.fromJson(json['reliability'] ?? {}),
      autonomyTier: json['autonomyTier'] ?? 1,
    );
  }

  /// Mock data for demo
  static InsightsModel get mock => InsightsModel(
    lifeOptimizationScore: 87,
    timeSaved:   const TimeSaved(totalMinutes: 270, displayWeekly: '4.5h', displayLifetime: '18h'),
    decisions:   const DecisionsData(total: 12, display: '12 this week'),
    moneySaved:  const MoneySaved(totalAED: 3200, display: 'AED 3,200'),
    obligations: const ObligationsStats(
      total: 6, active: 5, completed: 1, overdue: 0, highRisk: 3, missRate: '0%',
    ),
    reliability: const ReliabilityData(percentage: 99, display: '99%'),
    autonomyTier: 2,
  );
}

class TimeSaved {
  final int totalMinutes;
  final String displayWeekly;
  final String displayLifetime;
  const TimeSaved({required this.totalMinutes, required this.displayWeekly, required this.displayLifetime});
  factory TimeSaved.fromJson(Map<String, dynamic> json) => TimeSaved(
    totalMinutes:    json['totalMinutes'] ?? 0,
    displayWeekly:   json['displayWeekly'] ?? '0h',
    displayLifetime: json['displayLifetime'] ?? '0h',
  );
}

class DecisionsData {
  final int total;
  final String display;
  const DecisionsData({required this.total, required this.display});
  factory DecisionsData.fromJson(Map<String, dynamic> json) => DecisionsData(
    total:   json['total'] ?? 0,
    display: json['display'] ?? '0',
  );
}

class MoneySaved {
  final double totalAED;
  final String display;
  const MoneySaved({required this.totalAED, required this.display});
  factory MoneySaved.fromJson(Map<String, dynamic> json) => MoneySaved(
    totalAED: (json['totalAED'] as num?)?.toDouble() ?? 0,
    display:  json['display'] ?? 'AED 0',
  );
}

class ObligationsStats {
  final int total;
  final int active;
  final int completed;
  final int overdue;
  final int highRisk;
  final String missRate;
  const ObligationsStats({
    required this.total, required this.active, required this.completed,
    required this.overdue, required this.highRisk, required this.missRate,
  });
  factory ObligationsStats.fromJson(Map<String, dynamic> json) => ObligationsStats(
    total:     json['total'] ?? 0,
    active:    json['active'] ?? 0,
    completed: json['completed'] ?? 0,
    overdue:   json['overdue'] ?? 0,
    highRisk:  json['highRisk'] ?? 0,
    missRate:  json['missRate'] ?? '0%',
  );
}

class ReliabilityData {
  final double percentage;
  final String display;
  const ReliabilityData({required this.percentage, required this.display});
  factory ReliabilityData.fromJson(Map<String, dynamic> json) => ReliabilityData(
    percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    display:    json['display'] ?? '0%',
  );
}
