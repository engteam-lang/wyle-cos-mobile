import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state.dart';
import '../../services/brief_service.dart';
import '../../models/morning_brief_model.dart';
import '../../utils/format_utils.dart';
import '../../theme/app_colors.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _salmon    = Color(0xFFFF9F8A);
const _crimson   = Color(0xFFFF3B30);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);

class MorningBriefScreen extends ConsumerStatefulWidget {
  const MorningBriefScreen({super.key});

  @override
  ConsumerState<MorningBriefScreen> createState() => _MorningBriefScreenState();
}

class _MorningBriefScreenState extends ConsumerState<MorningBriefScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generateIfNeeded();
  }

  Future<void> _generateIfNeeded() async {
    final state = ref.read(appStateProvider);
    if (state.morningBrief != null && !DateUtils2.isBriefStale(state.lastBriefKey)) return;

    setState(() => _loading = true);
    try {
      final brief = await BriefService.instance.generateBrief(
        state.obligations.where((o) => o.status != 'completed').toList(),
        99,
      );
      ref.read(appStateProvider.notifier).setMorningBrief(brief);
      ref.read(appStateProvider.notifier).setLastBriefKey(DateUtils2.briefKey());
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brief = ref.watch(appStateProvider).morningBrief;
    final isEvening = DateUtils2.briefTimeOfDay() == 'evening';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isEvening),
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator(color: _verdigris))
                : brief == null
                    ? _buildEmpty()
                    : _buildBriefContent(brief, isEvening)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isEvening) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
              child: const Icon(Icons.close, color: _white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEvening ? 'Evening Recap' : 'Morning Brief',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
              Text(DateUtils2.shortDate(DateTime.now()),
                  style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
            ],
          )),
          GestureDetector(
            onTap: () { ref.read(appStateProvider.notifier).setLastBriefKey(''); _generateIfNeeded(); },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
              child: const Icon(Icons.refresh_rounded, color: _textSec, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wb_sunny_outlined, color: _verdigris, size: 48),
        const SizedBox(height: 14),
        Text('Generating your brief…',
            style: GoogleFonts.poppins(fontSize: 16, color: _white)),
        const SizedBox(height: 8),
        const CircularProgressIndicator(color: _verdigris),
      ]),
    );
  }

  Widget _buildBriefContent(MorningBriefModel brief, bool isEvening) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + score
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_verdigris.withOpacity(0.12), Colors.transparent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _verdigris.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(isEvening ? '🌙' : '☀️',
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brief.greeting, style: GoogleFonts.inter(
                          fontSize: 14, color: _textSec)),
                      Text(brief.headline, style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700, color: _white,
                          height: 1.3)),
                    ],
                  )),
                  Column(children: [
                    Text('${brief.lifeOptimizationScore.toInt()}',
                        style: GoogleFonts.poppins(
                            fontSize: 28, fontWeight: FontWeight.w700, color: _chartreuse)),
                    Text('score', style: GoogleFonts.inter(fontSize: 11, color: _textSec)),
                  ]),
                ]),
                const SizedBox(height: 16),
                // Stats row
                Row(children: [
                  _briefStat('${brief.stats.obligationsTracked}', 'TRACKED'),
                  _vSep(),
                  _briefStat(brief.stats.timeSavedThisWeek, 'SAVED'),
                  _vSep(),
                  _briefStat('${brief.stats.decisionsHandled}', 'HANDLED'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Top priorities
          if (brief.topPriorities.isNotEmpty) ...[
            _sectionLabel('TOP PRIORITIES'),
            const SizedBox(height: 10),
            ...brief.topPriorities.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPriorityCard(p),
            )),
          ],

          // Completed items (evening)
          if (brief.completedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionLabel('COMPLETED TODAY'),
            const SizedBox(height: 10),
            ...brief.completedItems.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompletedCard(c),
            )),
          ],

          // Tomorrow preview (evening)
          if (brief.tomorrowPreview != null) ...[
            const SizedBox(height: 8),
            _sectionLabel('TOMORROW'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Text(brief.tomorrowPreview!,
                  style: GoogleFonts.inter(fontSize: 14, color: _textSec, height: 1.5)),
            ),
          ],

          // Tip
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _chartreuse.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _chartreuse.withOpacity(0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(brief.tip,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _chartreuse, height: 1.5))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _briefStat(String val, String label) => Expanded(
    child: Column(children: [
      Text(val, style: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
      Text(label, style: GoogleFonts.inter(
          fontSize: 9, color: _textTer, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _vSep() => Container(width: 1, height: 30, color: _border);

  Widget _sectionLabel(String label) => Text(label, style: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: _textTer, letterSpacing: 1.5));

  Widget _buildPriorityCard(BriefPriority p) {
    final riskColor = p.riskLevel == 'high'   ? _crimson
                    : p.riskLevel == 'medium' ? _chartreuse
                    : _verdigris;
    return Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, decoration: BoxDecoration(
            color: riskColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          )),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(p.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.title, style: GoogleFonts.inter(
                      fontSize: 15, color: _white, fontWeight: FontWeight.w600))),
                  if (p.daysUntil != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(p.daysUntil == 0 ? 'TODAY' : '${p.daysUntil}d',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: riskColor, fontWeight: FontWeight.w700)),
                    ),
                ]),
                if (p.executionPath != null) ...[
                  const SizedBox(height: 6),
                  Text(p.executionPath!, style: GoogleFonts.inter(
                      fontSize: 12, color: _textSec)),
                ],
                const SizedBox(height: 8),
                Text(p.action, style: GoogleFonts.inter(
                    fontSize: 12, color: _verdigris, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BriefCompletedItem c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _verdigris.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdigris.withOpacity(0.2)),
      ),
      child: Row(children: [
        Text(c.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.title, style: GoogleFonts.inter(
                fontSize: 13, color: _white, fontWeight: FontWeight.w500)),
            if (c.completedNote != null)
              Text(c.completedNote!, style: GoogleFonts.inter(
                  fontSize: 11, color: _verdigris)),
          ],
        )),
        const Icon(Icons.check_circle_outline, color: _verdigris, size: 18),
      ]),
    );
  }
}

// Local alias to avoid clash with Flutter's DateUtils
class DateUtils2 {
  static String briefTimeOfDay() {
    return DateTime.now().hour >= 17 ? 'evening' : 'morning';
  }
  static String briefKey() {
    final tod  = briefTimeOfDay();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return '${tod}_$date';
  }
  static bool isBriefStale(String? key) => key == null || key != briefKey();
  static String shortDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
  }
}
