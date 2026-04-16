import '../models/obligation_model.dart';
import '../models/morning_brief_model.dart';
import 'ai_service.dart';

class BriefService {
  BriefService._();
  static final BriefService instance = BriefService._();

  Future<MorningBriefModel> generateBrief(
    List<ObligationModel> obligations,
    int reliabilityScore, {
    Map<String, dynamic>? dayProgress,
  }) async {
    final active = obligations.where((o) => o.status == 'active').toList();
    final isEvening = dayProgress != null;

    final prompt = isEvening
        ? _buildEveningPrompt(active, reliabilityScore, dayProgress!)
        : _buildMorningPrompt(active, reliabilityScore);

    try {
      final response = await AiService.instance.complete(
        systemPrompt: '''You are Wyle, an AI digital chief of staff for UAE professionals.
Generate ${isEvening ? 'an evening recap' : 'a morning brief'} as a JSON object with this exact structure:
{
  "greeting": "string (short, personalized)",
  "headline": "string (one punchy line about their day)",
  "lifeOptimizationScore": number (0-100),
  "topPriorities": [{"id":"string","title":"string","type":"string","riskLevel":"high|medium|low","emoji":"string","daysUntil":number,"executionPath":"string","action":"string"}],
  "stats": {"obligationsTracked":number,"timeSavedThisWeek":"string","decisionsHandled":number},
  "tip": "string (one actionable productivity tip)"
  ${isEvening ? ',"completedItems":[{"id":"string","title":"string","emoji":"string","completedNote":"string"}],"tomorrowPreview":"string"' : ''}
}
Return only valid JSON, no markdown.''',
        userMessage: prompt,
        maxTokens: 1200,
      );

      final json = AiService.parseJsonResponse(response);
      if (json != null) return MorningBriefModel.fromJson(json);
    } catch (_) {}

    // Fallback brief
    return _fallbackBrief(active, isEvening);
  }

  String _buildMorningPrompt(List<ObligationModel> active, int reliability) {
    final topObs = active.take(5).map((o) =>
      '- ${o.emoji} ${o.title} (${o.risk} risk, ${o.daysUntil} days, path: ${o.executionPath})'
    ).join('\n');
    return 'Morning brief request.\nReliability score: $reliability%\nTop obligations:\n$topObs\nTotal active: ${active.length}';
  }

  String _buildEveningPrompt(
    List<ObligationModel> active,
    int reliability,
    Map<String, dynamic> dayProgress,
  ) {
    final completed = dayProgress['completed'] as int? ?? 0;
    final total     = dayProgress['total'] as int? ?? 0;
    return 'Evening recap request.\nCompleted today: $completed/$total\nReliability: $reliability%\nRemaining: ${active.length} active obligations';
  }

  MorningBriefModel _fallbackBrief(List<ObligationModel> active, bool isEvening) {
    final high = active.where((o) => o.risk == 'high').toList();
    return MorningBriefModel(
      greeting: isEvening ? 'Good evening!' : 'Good morning!',
      headline: active.isEmpty
          ? 'Your stack is clear — great day ahead'
          : '${high.length} urgent item${high.length == 1 ? '' : 's'} need your attention',
      lifeOptimizationScore: 85,
      topPriorities: active.take(3).map((o) => BriefPriority(
        id:            o.id,
        title:         o.title,
        type:          o.type,
        riskLevel:     o.risk,
        emoji:         o.emoji,
        daysUntil:     o.daysUntil,
        executionPath: o.executionPath,
        action:        o.executionPath,
      )).toList(),
      stats: BriefStats(
        obligationsTracked: active.length,
        timeSavedThisWeek:  '4.5h',
        decisionsHandled:   12,
      ),
      tip: 'Handle your highest-risk items before noon for maximum peace of mind.',
    );
  }
}
