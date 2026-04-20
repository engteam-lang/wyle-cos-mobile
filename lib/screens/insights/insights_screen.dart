import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/insights_model.dart';
import '../../models/insights_summary_model.dart';
import '../../providers/app_state.dart';
import '../../services/buddy_api_service.dart';
import '../../utils/format_utils.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _salmon    = Color(0xFFFF9F8A);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);
const _crimson   = Color(0xFFFF3B30);

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _loading = false;
  InsightsSummaryModel? _summary; // live data from /v1/insights/summary

  InsightsModel get _insights =>
      ref.watch(appStateProvider).insights ?? InsightsModel.mock;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _loading = true);
    // Fetch live summary from Buddy API (best effort — never blocks UI)
    try {
      final summary = await BuddyApiService.instance.getInsightsSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      // API unavailable — fall through to mock InsightsModel below
    }
    // Keep InsightsModel.mock as the detailed display model if API is down
    if (ref.read(appStateProvider).insights == null) {
      ref.read(appStateProvider.notifier).setInsights(InsightsModel.mock);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ins = _insights;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _verdigris))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildScoreCard(ins),
                    _buildStatsRow(ins),
                    _buildTimeSavedCard(ins),
                    _buildObligationsCard(ins),
                    _buildAutonomyCard(ins),
                    _buildPerformanceCard(ins),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insights', style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: _white)),
          Text('Your life optimization metrics',
              style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
        ],
      ),
    );
  }

  Widget _buildScoreCard(InsightsModel ins) {
    // Prefer live API score when available
    final score = _summary?.productivityScore ?? ins.lifeOptimizationScore.toInt();
    final scoreD = score.toDouble();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_verdigris.withOpacity(0.15), _chartreuse.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _verdigris.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRODUCTIVITY SCORE',
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _textSec, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text('$score',
                        style: GoogleFonts.poppins(
                            fontSize: 52, fontWeight: FontWeight.w700,
                            color: _white, height: 1)),
                    const SizedBox(height: 4),
                    Text('out of 100',
                        style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      value: (scoreD / 100).clamp(0, 1),
                      strokeWidth: 7,
                      backgroundColor: _border,
                      valueColor: const AlwaysStoppedAnimation(_verdigris),
                    ),
                  ),
                  Text('$score%',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _verdigris)),
                ],
              ),
            ],
          ),
          // Weekly pattern from live API
          if (_summary != null && _summary!.weeklyPattern.insightText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _verdigris.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _verdigris.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: _verdigris, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _summary!.weeklyPattern.insightText,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _textSec, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(InsightsModel ins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(child: _statCard(
              'TIME SAVED',
              _summary != null
                  ? '${_summary!.hoursSavedEstimate.toStringAsFixed(1)}h'
                  : ins.timeSaved.displayWeekly,
              'this week', _verdigris)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(
              'TASKS DONE',
              _summary != null
                  ? _summary!.tasksDone.toString()
                  : ins.decisions.total.toString(),
              'this month', _chartreuse)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(
              'RELIABILITY', ins.reliability.display, 'score',
              const Color(0xFFFF9F8A))),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _textTer, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: _textSec)),
        ],
      ),
    );
  }

  Widget _buildTimeSavedCard(InsightsModel ins) {
    return _sectionCard(
      title: 'TIME RECLAIMED',
      children: [
        _metricRow('This Week', ins.timeSaved.displayWeekly, _verdigris),
        _metricRow('Lifetime',  ins.timeSaved.displayLifetime, _chartreuse),
        _metricRow('Per Month (est.)', '18.5h', _textSec),
      ],
    );
  }

  Widget _buildObligationsCard(InsightsModel ins) {
    final obs = ins.obligations;
    return _sectionCard(
      title: 'OBLIGATIONS OVERVIEW',
      children: [
        _metricRow('Total Tracked', obs.total.toString(), _white),
        _metricRow('Active',        obs.active.toString(), _verdigris),
        _metricRow('Completed',     obs.completed.toString(), _chartreuse),
        _metricRow('High Risk',     obs.highRisk.toString(), _crimson),
        _metricRow('Miss Rate',     obs.missRate, _textSec),
      ],
    );
  }

  Widget _buildAutonomyCard(InsightsModel ins) {
    const tiers = ['Observer', 'Suggester', 'Assistant', 'Orchestrator', 'Operator'];
    final tier  = ins.autonomyTier.clamp(0, 4);
    return _sectionCard(
      title: 'AUTONOMY TIER',
      children: [
        Row(
          children: List.generate(5, (i) {
            final active = i <= tier;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _verdigris : _border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(tiers[tier],
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: _verdigris)),
        Text('Level $tier of 4',
            style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
      ],
    );
  }

  Widget _buildPerformanceCard(InsightsModel ins) {
    return _sectionCard(
      title: 'SYSTEM PERFORMANCE',
      children: [
        _metricRow('Reliability',      ins.reliability.display, _chartreuse),
        _metricRow('Money Saved',      ins.moneySaved.display, _verdigris),
        _metricRow('Decisions Handled',ins.decisions.display, _white),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _textTer, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
          Text(value, style: GoogleFonts.inter(
              fontSize: 14, color: valueColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
