import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/models/obligation_model.dart';
import 'package:wyle_cos/providers/app_state.dart';
import 'package:wyle_cos/services/ai_service.dart';
import 'package:wyle_cos/services/voice_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour constants
// ─────────────────────────────────────────────────────────────────────────────
const Color _bgDark      = Color(0xFF0D0D0D);
const Color _surfaceDark = Color(0xFF161616);
const Color _surfaceEl   = Color(0xFF1E1E1E);
const Color _surfaceHi   = Color(0xFF252525);
const Color _verdigris   = Color(0xFF1B998B);
const Color _chartreuse  = Color(0xFFD5FF3F);
const Color _chartreuseB = Color(0xFFA8CC00);
const Color _salmon      = Color(0xFFFF6B6B);
const Color _crimson     = Color(0xFFFF3B30);
const Color _orange      = Color(0xFFFF9500);
const Color _white       = Color(0xFFFFFFFF);
const Color _textSec     = Color(0xFF9A9A9A);
const Color _textTer     = Color(0xFF555555);
const Color _border      = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
// Obligation types
// ─────────────────────────────────────────────────────────────────────────────
const _kObligationTypes = [
  'visa', 'emirates_id', 'car_registration', 'insurance', 'school_fee',
  'mortgage_emi', 'subscription', 'medical', 'document', 'bill', 'custom',
];

const _kTypeLabels = {
  'visa':             'Visa',
  'emirates_id':      'Emirates ID',
  'car_registration': 'Car Registration',
  'insurance':        'Insurance',
  'school_fee':       'School Fee',
  'mortgage_emi':     'Mortgage / EMI',
  'subscription':     'Subscription',
  'medical':          'Medical',
  'document':         'Document',
  'bill':             'Bill',
  'custom':           'Custom',
};

// ─────────────────────────────────────────────────────────────────────────────
// Duplicate detection helpers (ported from ObligationsScreen.tsx)
// ─────────────────────────────────────────────────────────────────────────────
String _normalizeTitle(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();

bool _isSimilarTitle(String a, String b) {
  final na = _normalizeTitle(a);
  final nb = _normalizeTitle(b);
  if (na == nb) return true;
  if (na.contains(nb) || nb.contains(na)) return true;
  final wa = na.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
  final wb = nb.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
  final shared = wa.where((w) => wb.contains(w)).length;
  return wa.isNotEmpty && shared / max(wa.length, wb.length) > 0.4;
}

ObligationModel? _findDuplicate(ObligationModel item, List<ObligationModel> existing) {
  for (final e in existing) {
    if (e.status == 'active' && e.type == item.type && _isSimilarTitle(e.title, item.title)) {
      return e;
    }
  }
  return null;
}

// Completion intent detection
bool _hasCompletionIntent(String text) {
  final lower = text.toLowerCase();
  const patterns = [
    'i paid', 'i have paid', 'i completed', 'i have completed', 'i finished',
    'already paid', 'already done', 'already completed', 'mark as completed',
    'mark as done', 'mark it as completed', 'can you remove', 'remove the task',
    'remove it from', 'mark it completed',
  ];
  return patterns.any((p) => lower.contains(p));
}

ObligationModel? _findObligationInText(String text, List<ObligationModel> obligations) {
  final lower = _normalizeTitle(text);
  for (final ob in obligations) {
    final words = _normalizeTitle(ob.title).split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    if (words.isEmpty) continue;
    final matched = words.where((w) => lower.contains(w)).length;
    if (matched / words.length >= 0.5) return ob;
  }
  return null;
}

// Brain Dump AI system prompt
String _buildBrainDumpSystem() {
  final now  = DateTime.now();
  final yyyy = now.year;
  final mm   = now.month.toString().padLeft(2, '0');
  final dd   = now.day.toString().padLeft(2, '0');
  final days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  final todayISO   = '$yyyy-$mm-$dd';
  final todayHuman = '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, $yyyy';

  final upcoming = List.generate(14, (i) {
    final d   = now.add(Duration(days: i));
    final y   = d.year; final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final lbl = i == 0 ? 'TODAY' : i == 1 ? 'TOMORROW' : days[d.weekday % 7];
    return '  $lbl = $y-$m-$day (${days[d.weekday % 7]}, ${months[d.month - 1]} ${d.day})';
  }).join('\n');

  return '''You are Buddy inside Wyle — a life management app for busy professionals in Dubai, UAE.

=== DATE CONTEXT ===
TODAY: $todayHuman
TODAY ISO: $todayISO
UPCOMING DATES (use to resolve "Saturday", "next Monday", etc.):
$upcoming
=== END DATE CONTEXT ===

Detect whether the user is CREATING tasks OR intends something else.

Return ONLY valid JSON, no markdown, no explanation:
{"intent":"tasks","items":[...]}

Each item must have:
  emoji, title, type (visa/emirates_id/car_registration/insurance/bill/school_fee/medical/document/payment/task/other),
  daysUntil (integer, from $todayISO), risk (high if <7d, medium if 7-30d, low if >30d),
  amount (number in AED or null), status:"active", executionPath (string), notes (string or null)

If nothing actionable: {"intent":"tasks","items":[]}''';
}

// ─────────────────────────────────────────────────────────────────────────────
// ObligationsScreen
// ─────────────────────────────────────────────────────────────────────────────
class ObligationsScreen extends ConsumerStatefulWidget {
  const ObligationsScreen({super.key});

  @override
  ConsumerState<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends ConsumerState<ObligationsScreen> {
  String _filterRisk = 'all';

  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':   return _crimson;
      case 'medium': return _orange;
      default:       return _verdigris;
    }
  }

  String _daysLabel(int days) {
    if (days < 0) return 'Overdue ${days.abs()}d';
    if (days == 0) return 'TODAY';
    return '${days}d';
  }

  // ── modals ──────────────────────────────────────────────────────────────────
  void _showDetailModal(ObligationModel ob) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailModal(
        obligation: ob,
        onMarkDone: () {
          ref.read(appStateProvider.notifier).updateObligation(
                ob.id, (o) => o.copyWith(status: 'completed'));
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddModal(
        onAdd: (ob) {
          ref.read(appStateProvider.notifier).addObligation(ob);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showBrainDump() {
    final allObs = ref.read(appStateProvider).obligations;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BrainDumpModal(
        existingObligations: allObs,
        onSave: (items) {
          for (final ob in items) {
            ref.read(appStateProvider.notifier).addObligation(ob);
          }
        },
        onResolve: (id) {
          final ob = ref.read(appStateProvider).obligations
              .firstWhere((o) => o.id == id, orElse: () => throw Exception());
          ref.read(appStateProvider.notifier).updateObligation(
              id, (o) => o.copyWith(status: 'completed'));
        },
      ),
    );
  }

  void _resolveCard(ObligationModel ob) {
    ref.read(appStateProvider.notifier).updateObligation(
        ob.id, (o) => o.copyWith(status: 'completed'));
  }

  // ── build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state        = ref.watch(appStateProvider);
    final allObs       = state.obligations;
    final activeCount  = allObs.where((o) => o.status != 'completed').length;

    // Split: active (filtered by risk), completed (always shown at bottom)
    var active = allObs.where((o) => o.status != 'completed').toList();
    if (_filterRisk != 'all') {
      active = active.where((o) => o.risk == _filterRisk).toList();
    }
    final completed = allObs.where((o) => o.status == 'completed').toList();

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Automations',
                            style: GoogleFonts.inter(
                              fontSize: 26, fontWeight: FontWeight.w800, color: _white)),
                        const SizedBox(height: 4),
                        Text(
                          '$activeCount active obligation${activeCount != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(fontSize: 13, color: _textSec),
                        ),
                      ],
                    ),
                  ),
                  // Mic (Brain Dump) button
                  GestureDetector(
                    onTap: _showBrainDump,
                    child: Container(
                      width: 40, height: 40,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _salmon.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _salmon.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.mic_none_rounded,
                          color: _salmon, size: 20),
                    ),
                  ),
                  // Add (+) button
                  GestureDetector(
                    onTap: _showAddModal,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _verdigris,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: _white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter pills ──────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['all', 'high', 'medium', 'low'].map((f) {
                  final isActive = _filterRisk == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filterRisk = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _verdigris.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isActive ? _verdigris : _border),
                      ),
                      child: Text(
                        f.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive ? _verdigris : _textSec,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // ── List (active + completed section) ─────────────────────────────
            Expanded(
              child: active.isEmpty && completed.isEmpty
                  ? _buildEmpty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        // Active cards
                        if (active.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: Text(
                                _filterRisk == 'all'
                                    ? 'No active obligations'
                                    : 'No $_filterRisk risk items',
                                style: GoogleFonts.inter(
                                    fontSize: 14, color: _textSec),
                              ),
                            ),
                          )
                        else
                          ...active.map((ob) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildCard(ob, done: false),
                              )),

                        // Completed section — always visible at bottom
                        if (completed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Text(
                                  'COMPLETED (${completed.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _textTer,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                      height: 1, color: _textTer.withOpacity(0.3)),
                                ),
                              ],
                            ),
                          ),
                          ...completed.map((ob) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildCard(ob, done: true),
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            _filterRisk == 'all' ? 'No obligations yet' : 'No $_filterRisk risk items',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: _white),
          ),
          const SizedBox(height: 6),
          Text('Tap + to add one or use the mic',
              style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
        ],
      ),
    );
  }

  Widget _buildCard(ObligationModel ob, {required bool done}) {
    final rc = done ? _textSec : _riskColor(ob.risk);

    return Opacity(
      opacity: done ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: () => _showDetailModal(ob),
        child: Container(
          decoration: BoxDecoration(
            color: done
                ? _surfaceDark.withOpacity(0.5)
                : _surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: done ? _border.withOpacity(0.5) : _border),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left colour strip
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: rc,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ob.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ob.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: done ? _textSec : _white,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationColor: _textSec,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                ob.executionPath,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _textTer),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (ob.amount != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'AED ${ob.amount!.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: done ? _textTer : _chartreuse,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // ── Tick-to-complete button ──
                        if (!done)
                          GestureDetector(
                            onTap: () => _resolveCard(ob),
                            child: Container(
                              width: 32, height: 32,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: _verdigris.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _verdigris.withOpacity(0.4)),
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: _verdigris, size: 16),
                            ),
                          ),
                        // ── Risk + days badges ──
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: rc.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                done ? 'DONE' : _daysLabel(ob.daysUntil),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: done ? _textTer : rc,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: rc.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ob.risk.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: rc,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brain Dump Modal — voice → AI parse → duplicate review → save
// ─────────────────────────────────────────────────────────────────────────────
enum _VoiceState { idle, recording, parsing, done, error }

class _BrainDumpModal extends ConsumerStatefulWidget {
  final List<ObligationModel> existingObligations;
  final void Function(List<ObligationModel>) onSave;
  final void Function(String id) onResolve;

  const _BrainDumpModal({
    required this.existingObligations,
    required this.onSave,
    required this.onResolve,
  });

  @override
  ConsumerState<_BrainDumpModal> createState() => _BrainDumpModalState();
}

class _BrainDumpModalState extends ConsumerState<_BrainDumpModal>
    with SingleTickerProviderStateMixin {
  _VoiceState _voiceState = _VoiceState.idle;
  String      _transcript = '';
  List<ObligationModel> _parsed = [];

  // Duplicate review step
  bool                  _showReview = false;
  List<ObligationModel> _freshItems = [];
  List<({ObligationModel incoming, ObligationModel existing})> _dupeItems = [];

  // Completion intent
  ObligationModel? _completionTarget;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    VoiceService.instance.init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  // ── Voice ──────────────────────────────────────────────────────────────────
  Future<void> _handleMicPress() async {
    if (_voiceState == _VoiceState.recording) {
      await VoiceService.instance.stopListening();
      return;
    }
    if (_voiceState != _VoiceState.idle) return;

    setState(() {
      _parsed = []; _transcript = ''; _completionTarget = null;
      _showReview = false; _freshItems = []; _dupeItems = [];
      _voiceState = _VoiceState.recording;
    });

    await VoiceService.instance.startListening(
      (text) {
        if (!mounted) return;
        setState(() => _transcript = text);
        // Check completion intent first
        if (_hasCompletionIntent(text)) {
          final match = _findObligationInText(text, widget.existingObligations);
          if (match != null) {
            setState(() { _completionTarget = match; _voiceState = _VoiceState.done; });
            return;
          }
        }
        _parseWithAI(text);
      },
      (state) {
        if ((state == 'idle' || state == 'error') && mounted &&
            _voiceState == _VoiceState.recording) {
          // Auto-stopped by silence — will trigger onResult callback
        }
      },
      silenceTimeout: const Duration(seconds: 3),
    );
  }

  Future<void> _parseWithAI(String text) async {
    if (!mounted) return;
    setState(() => _voiceState = _VoiceState.parsing);
    try {
      final raw = await AiService.instance.complete(
        systemPrompt: _buildBrainDumpSystem(),
        userMessage:  text,
        maxTokens:    1200,
      );
      final clean   = raw.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      final items   = (decoded['items'] as List? ?? []);
      final parsed  = items.map((m) {
        final map = m as Map<String, dynamic>;
        return ObligationModel(
          id:            'dump_${DateTime.now().millisecondsSinceEpoch}_${items.indexOf(m)}',
          emoji:         emojiForType(map['type'] as String? ?? 'custom'),
          title:         map['title'] as String? ?? '',
          type:          map['type']  as String? ?? 'custom',
          daysUntil:     (map['daysUntil'] as num?)?.toInt() ?? 7,
          risk:          map['risk']  as String? ?? 'medium',
          amount:        (map['amount'] as num?)?.toDouble(),
          status:        'active',
          executionPath: map['executionPath'] as String? ?? 'Handle manually',
          notes:         map['notes'] as String?,
          source:        'voice',
        );
      }).where((o) => o.title.isNotEmpty).toList();

      if (mounted) setState(() { _parsed = parsed; _voiceState = _VoiceState.done; });
    } catch (_) {
      if (mounted) setState(() => _voiceState = _VoiceState.error);
    }
  }

  // ── Save with duplicate check ──────────────────────────────────────────────
  void _handleSaveAll() {
    final fresh = <ObligationModel>[];
    final dupes = <({ObligationModel incoming, ObligationModel existing})>[];
    for (final item in _parsed) {
      final match = _findDuplicate(item, widget.existingObligations);
      if (match != null) dupes.add((incoming: item, existing: match));
      else fresh.add(item);
    }
    if (dupes.isNotEmpty) {
      setState(() { _freshItems = fresh; _dupeItems = dupes; _showReview = true; });
      return;
    }
    widget.onSave(_parsed);
    Navigator.of(context).pop();
  }

  void _handleSkipDupes() {
    if (_freshItems.isNotEmpty) widget.onSave(_freshItems);
    Navigator.of(context).pop();
  }

  void _handleAddAll() {
    widget.onSave([..._freshItems, ..._dupeItems.map((d) => d.incoming)]);
    Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _textTer,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Voice Brain Dump',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w800, color: _white)),
                      Text('Speak freely — Buddy structures your tasks',
                          style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded, color: _textSec, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Transcript
            if (_transcript.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _surfaceEl,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOU SAID',
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _textTer, letterSpacing: 1.1)),
                    const SizedBox(height: 4),
                    Text('"$_transcript"',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _white,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],

            // Completion target
            if (_completionTarget != null) ...[
              _buildCompletionView(),
            ]
            // Duplicate review
            else if (_showReview) ...[
              _buildDuplicateReview(),
            ]
            // Parsed tasks
            else if (_parsed.isNotEmpty) ...[
              _buildParsedList(),
            ]
            // Idle hint
            else if (_voiceState == _VoiceState.idle) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceEl,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '💡 Try: "Hospital bill AED 800 next week, car service overdue, '
                  'school fees 12,000 end of month…"',
                  style: GoogleFonts.inter(fontSize: 12, color: _textSec, height: 1.5),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Status text
            Center(
              child: Text(
                _statusText(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _voiceState == _VoiceState.recording ? _salmon
                      : _voiceState == _VoiceState.done       ? _chartreuse
                      : _voiceState == _VoiceState.error      ? _crimson
                      : _textSec,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Mic button
            if (_voiceState != _VoiceState.done &&
                _voiceState != _VoiceState.parsing &&
                !_showReview) ...[
              Center(
                child: GestureDetector(
                  onTap: _handleMicPress,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      final scale = _voiceState == _VoiceState.recording
                          ? 1.0 + _pulseCtrl.value * 0.12
                          : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _voiceState == _VoiceState.recording
                                ? _salmon.withOpacity(0.28)
                                : _salmon.withOpacity(0.14),
                            border: Border.all(
                              color: _voiceState == _VoiceState.recording
                                  ? _salmon
                                  : _salmon.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _voiceState == _VoiceState.recording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: _salmon,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Parsing indicator
            if (_voiceState == _VoiceState.parsing) ...[
              const Center(child: CircularProgressIndicator(color: _verdigris)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParsedList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUDDY FOUND ${_parsed.length} ${_parsed.length == 1 ? 'TASK' : 'TASKS'}',
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _textTer, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _parsed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final ob = _parsed[i];
              final rc = ob.risk == 'high' ? _crimson : ob.risk == 'medium' ? _orange : _verdigris;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceEl,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: rc, width: 3)),
                ),
                child: Row(
                  children: [
                    Text(ob.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ob.title,
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: _white)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(ob.risk.toUpperCase(),
                                  style: GoogleFonts.inter(
                                      fontSize: 10, color: rc, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Text('${ob.daysUntil}d',
                                  style: GoogleFonts.inter(fontSize: 10, color: _textSec)),
                              if (ob.amount != null) ...[
                                const SizedBox(width: 8),
                                Text('AED ${ob.amount!.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 10, color: _chartreuse)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _verdigris.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('NEW',
                          style: GoogleFonts.inter(
                              fontSize: 8, fontWeight: FontWeight.w800, color: _verdigris)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _handleSaveAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_verdigris, _chartreuseB]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text('Save ${_parsed.length} ${_parsed.length == 1 ? 'Task' : 'Tasks'}',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _orange.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_dupeItems.length} duplicate${_dupeItems.length > 1 ? 's' : ''} detected',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _orange)),
                    const SizedBox(height: 2),
                    ..._dupeItems.map((d) => Text(
                          '"${d.incoming.title}" already exists',
                          style: GoogleFonts.inter(fontSize: 11, color: _textSec),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _handleSkipDupes,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _surfaceEl,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _border),
                  ),
                  child: Center(
                    child: Text(
                      'Skip Duplicates${_freshItems.isNotEmpty ? ' (+${_freshItems.length} new)' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _textSec),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _handleAddAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _orange.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text('Add All Anyway',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600, color: _orange)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletionView() {
    final ob = _completionTarget!;
    final rc = ob.risk == 'high' ? _crimson : ob.risk == 'medium' ? _orange : _verdigris;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MARK AS COMPLETED?',
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _textTer, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceEl,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: rc, width: 3)),
          ),
          child: Row(
            children: [
              Text(ob.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ob.title,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            widget.onResolve(ob.id);
            Navigator.of(context).pop();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_verdigris, _chartreuseB]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text('✓ Yes, mark as completed',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _white)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() => _completionTarget = null);
            _parseWithAI(_transcript);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _surfaceEl,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text('Add as new task instead',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textSec)),
            ),
          ),
        ),
      ],
    );
  }

  String _statusText() {
    switch (_voiceState) {
      case _VoiceState.idle:      return 'Tap the mic and speak your tasks';
      case _VoiceState.recording: return '🔴 Listening… tap to stop';
      case _VoiceState.parsing:   return '🤖 Buddy is structuring tasks…';
      case _VoiceState.done:
        if (_completionTarget != null) return '✓ Found matching task — confirm below';
        return '✓ ${_parsed.length} tasks found — save them below';
      case _VoiceState.error:     return 'Could not process. Try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail modal
// ─────────────────────────────────────────────────────────────────────────────
class _DetailModal extends StatelessWidget {
  final ObligationModel obligation;
  final VoidCallback onMarkDone;

  const _DetailModal({required this.obligation, required this.onMarkDone});

  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':   return _crimson;
      case 'medium': return _orange;
      default:       return _verdigris;
    }
  }

  String _daysLabel(int days) {
    if (days < 0) return 'Overdue ${days.abs()} days';
    if (days == 0) return 'Due today';
    return 'Due in $days day${days != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final ob = obligation;
    final rc = _riskColor(ob.risk);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          20 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _textTer,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ob.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ob.title,
                        style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.w800, color: _white)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _badge(ob.risk.toUpperCase(), rc),
                      const SizedBox(width: 8),
                      _badge(_daysLabel(ob.daysUntil), _textSec),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow('Execution', ob.executionPath),
          if (ob.notes != null) ...[
            const SizedBox(height: 10),
            _detailRow('Notes', ob.notes!),
          ],
          if (ob.amount != null) ...[
            const SizedBox(height: 10),
            _detailRow('Amount', 'AED ${ob.amount!.toStringAsFixed(0)}'),
          ],
          if (ob.source != null) ...[
            const SizedBox(height: 10),
            _detailRow('Source', ob.source!),
          ],
          const SizedBox(height: 24),
          if (ob.status != 'completed') ...[
            GestureDetector(
              onTap: onMarkDone,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_verdigris, Color(0xFF157A6E)]),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text('✓  Mark as Done',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _white)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text('Close',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _textSec)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _detailRow(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _textTer, letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(fontSize: 14, color: _white)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Obligation modal
// ─────────────────────────────────────────────────────────────────────────────
class _AddModal extends StatefulWidget {
  final void Function(ObligationModel) onAdd;
  const _AddModal({required this.onAdd});

  @override
  State<_AddModal> createState() => _AddModalState();
}

class _AddModalState extends State<_AddModal> {
  final _titleCtrl     = TextEditingController();
  final _daysCtrl      = TextEditingController(text: '7');
  final _amountCtrl    = TextEditingController();
  final _executionCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  String _type = 'custom';
  String _risk = 'medium';

  @override
  void dispose() {
    _titleCtrl.dispose(); _daysCtrl.dispose(); _amountCtrl.dispose();
    _executionCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) return;
    widget.onAdd(ObligationModel(
      id:            DateTime.now().millisecondsSinceEpoch.toString(),
      emoji:         emojiForType(_type),
      title:         _titleCtrl.text.trim(),
      type:          _type,
      daysUntil:     int.tryParse(_daysCtrl.text) ?? 7,
      risk:          _risk,
      amount:        double.tryParse(_amountCtrl.text),
      status:        'active',
      executionPath: _executionCtrl.text.trim().isNotEmpty
          ? _executionCtrl.text.trim()
          : 'Handle manually',
      notes:         _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      source:        'manual',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: _textTer,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Add Obligation',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w800, color: _white)),
              const SizedBox(height: 20),
              _label('TITLE'),
              _field(_titleCtrl, 'e.g. Emirates ID Renewal'),
              const SizedBox(height: 14),
              _label('TYPE'),
              _dropdownField(),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('DAYS UNTIL'),
                  _field(_daysCtrl, '7', keyboardType: TextInputType.number),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('RISK'),
                  _riskPicker(),
                ])),
              ]),
              const SizedBox(height: 14),
              _label('AMOUNT (AED, optional)'),
              _field(_amountCtrl, '0', keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              _label('EXECUTION PATH'),
              _field(_executionCtrl, 'How to handle this?'),
              const SizedBox(height: 14),
              _label('NOTES (optional)'),
              _field(_notesCtrl, 'Any extra details...', maxLines: 2),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_verdigris, Color(0xFF157A6E)]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text('Add Obligation',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _textTer, letterSpacing: 1.1)),
      );

  Widget _field(TextEditingController ctrl, String hint,
          {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14, color: _white),
        cursorColor: _verdigris,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _textTer),
          filled: true, fillColor: _surfaceEl,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _verdigris)),
        ),
      );

  Widget _dropdownField() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: _surfaceEl,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _type, isExpanded: true,
            dropdownColor: _surfaceEl,
            style: GoogleFonts.inter(fontSize: 14, color: _white),
            items: _kObligationTypes.map((t) => DropdownMenuItem(
                  value: t, child: Text(_kTypeLabels[t] ?? t))).toList(),
            onChanged: (v) { if (v != null) setState(() => _type = v); },
          ),
        ),
      );

  Widget _riskPicker() {
    return Row(
      children: ['high', 'medium', 'low'].map((r) {
        final selected = _risk == r;
        final color = r == 'high' ? _crimson : r == 'medium' ? _orange : _verdigris;
        return GestureDetector(
          onTap: () => setState(() => _risk = r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.2) : _surfaceEl,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? color : _border),
            ),
            child: Text(r[0].toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: selected ? color : _textTer)),
          ),
        );
      }).toList(),
    );
  }
}
