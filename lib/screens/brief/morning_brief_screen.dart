import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/brief_api_model.dart';
import '../../services/buddy_api_service.dart';

// ── Palette (matches app theme) ───────────────────────────────────────────────
const _bgTop      = Color(0xFF002F3A);
const _bgBot      = Color(0xFF000D12);
const _surface    = Color(0xFF0A2A38);
const _surfaceEl  = Color(0xFF1A3A4A);
const _border     = Color(0xFF1C4A56);
const _verdigris  = Color(0xFF1B998B);
const _chartreuse = Color(0xFFD5FF3F);
const _crimson    = Color(0xFFFF3B30);
const _white      = Color(0xFFFFFFFF);
const _textSec    = Color(0xFF9A9A9A);
const _textTer    = Color(0xFF4A4A4A);

// ─────────────────────────────────────────────────────────────────────────────
class MorningBriefScreen extends ConsumerStatefulWidget {
  const MorningBriefScreen({super.key});

  @override
  ConsumerState<MorningBriefScreen> createState() => _MorningBriefScreenState();
}

class _MorningBriefScreenState extends ConsumerState<MorningBriefScreen>
    with SingleTickerProviderStateMixin {

  BriefListResponse? _data;
  bool  _loading  = true;
  String? _error;

  // Tab controller: 0 = Morning, 1 = Evening
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchBriefs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBriefs({int days = 7}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await BuddyApiService.instance.getBriefs(days: days);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Settings sheet ─────────────────────────────────────────────────────────
  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BriefSettingsSheet(
        initialMorning:  _data?.morningBriefLocal ?? '07:00',
        initialEvening:  _data?.eveningBriefLocal  ?? '19:00',
        initialEnabled:  _data?.briefsEnabled      ?? true,
        onSaved: (morning, evening, enabled) async {
          try {
            final resp = await BuddyApiService.instance.patchBriefSchedule(
              morningBriefLocal: morning,
              eveningBriefLocal: evening,
              briefsEnabled:     enabled,
            );
            if (mounted) {
              setState(() {
                _data = _data == null
                    ? null
                    : BriefListResponse(
                        timezone:          resp.timezone,
                        morningBriefLocal: resp.morningBriefLocal,
                        eveningBriefLocal: resp.eveningBriefLocal,
                        briefsEnabled:     resp.briefsEnabled,
                        briefs:            _data!.briefs,
                      );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0F3D35),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  content: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: _verdigris, size: 16),
                    const SizedBox(width: 8),
                    Text('Brief schedule saved',
                        style: GoogleFonts.inter(
                            color: _white, fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              );
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _crimson.withOpacity(0.85),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  content: Text('Failed to save — please try again',
                      style: GoogleFonts.inter(color: _white, fontSize: 13)),
                ),
              );
            }
          }
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, Color(0xFF001E29), _bgBot],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildScheduleBar(),
              _buildTabBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Briefs',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: _white)),
                Text(_todayLabel(),
                    style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
              ],
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: () => _fetchBriefs(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _textSec, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Settings
          GestureDetector(
            onTap: _openSettings,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.tune_rounded,
                  color: _verdigris, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Schedule info bar ──────────────────────────────────────────────────────
  Widget _buildScheduleBar() {
    if (_data == null) return const SizedBox.shrink();
    final d = _data!;
    final enabledColor = d.briefsEnabled ? _verdigris : _textTer;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            d.briefsEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: enabledColor, size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            d.briefsEnabled ? 'Briefs enabled' : 'Briefs disabled',
            style: GoogleFonts.inter(
                fontSize: 12, color: enabledColor,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (d.briefsEnabled && d.morningBriefLocal != null) ...[
            const Text('☀️', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(_fmt24(d.morningBriefLocal!),
                style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
            const SizedBox(width: 12),
          ],
          if (d.briefsEnabled && d.eveningBriefLocal != null) ...[
            const Text('🌙', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(_fmt24(d.eveningBriefLocal!),
                style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openSettings,
            child: Text('Edit',
                style: GoogleFonts.inter(
                    fontSize: 12, color: _verdigris,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: _verdigris.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _verdigris.withOpacity(0.5)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: _white,
        unselectedLabelColor: _textSec,
        labelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
        tabs: const [
          Tab(text: '☀️  Morning'),
          Tab(text: '🌙  Evening'),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _verdigris, strokeWidth: 2));
    }
    if (_error != null) {
      return _buildError();
    }
    if (_data == null) return const SizedBox.shrink();

    final morningBriefs = _data!.briefs
        .where((b) => b.slot == 'morning')
        .toList();
    final eveningBriefs = _data!.briefs
        .where((b) => b.slot == 'evening')
        .toList();

    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildBriefList(morningBriefs, 'morning'),
        _buildBriefList(eveningBriefs, 'evening'),
      ],
    );
  }

  Widget _buildBriefList(List<BriefEntry> briefs, String slot) {
    if (briefs.isEmpty) {
      return _buildEmpty(slot);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: briefs.length,
      itemBuilder: (_, i) => _BriefCard(brief: briefs[i]),
    );
  }

  Widget _buildEmpty(String slot) {
    final isEvening = slot == 'evening';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isEvening ? '🌙' : '☀️',
              style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            isEvening
                ? 'No evening briefs yet'
                : 'No morning briefs yet',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: _white),
          ),
          const SizedBox(height: 8),
          Text(
            _data?.briefsEnabled == false
                ? 'Enable briefs in settings to start receiving them.'
                : 'Your ${slot} brief will appear here once the '
                  'scheduled time passes.',
            style: GoogleFonts.inter(
                fontSize: 13, color: _textSec, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _openSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _verdigris.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _verdigris.withOpacity(0.5)),
              ),
              child: Text('Brief settings',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _verdigris,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: _textSec, size: 48),
          const SizedBox(height: 16),
          Text('Could not load briefs',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: _white)),
          const SizedBox(height: 8),
          Text('Check your connection and try again.',
              style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _fetchBriefs(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _verdigris,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Retry',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _todayLabel() {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  /// Converts "07:00" → "7:00 AM", "19:30" → "7:30 PM"
  String _fmt24(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final ap = h < 12 ? 'AM' : 'PM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:${m.toString().padLeft(2, '0')} $ap';
    } catch (_) {
      return hhmm;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brief Card
// ─────────────────────────────────────────────────────────────────────────────
class _BriefCard extends StatefulWidget {
  final BriefEntry brief;
  const _BriefCard({required this.brief});

  @override
  State<_BriefCard> createState() => _BriefCardState();
}

class _BriefCardState extends State<_BriefCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.brief;
    final isToday = b.localDate ==
        DateTime.now().toIso8601String().substring(0, 10);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? _verdigris.withOpacity(0.6)
              : _border,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Top accent bar (today = teal, others = muted) ──────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isToday ? _verdigris : _textTer.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date + slot badge ────────────────────────────────────
                Row(
                  children: [
                    Text(
                      isToday ? 'Today' : _friendlyDate(b.localDate),
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isToday ? _verdigris : _textSec,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: b.isMorning
                            ? _chartreuse.withOpacity(0.12)
                            : _verdigris.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        b.isMorning ? '☀️ Morning' : '🌙 Evening',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: b.isMorning ? _chartreuse : _verdigris,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isToday) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _verdigris.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('LATEST',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: _verdigris,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                // ── Title ────────────────────────────────────────────────
                Text(b.title,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _white,
                        height: 1.3)),
                const SizedBox(height: 8),
                // ── Highlights (always visible) ───────────────────────────
                if (b.highlights.isNotEmpty)
                  ...b.highlights.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: _verdigris,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(h,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: _white.withOpacity(0.85),
                                  height: 1.45)),
                        ),
                      ],
                    ),
                  )),
                // ── Expand / collapse body ────────────────────────────────
                if (b.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        Text(
                          _expanded ? 'Show less' : 'Read full brief',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _verdigris,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _verdigris, size: 16,
                        ),
                      ],
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bgBot.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _border.withOpacity(0.5)),
                      ),
                      child: Text(b.body,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _textSec,
                              height: 1.6)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final yesterday =
          DateTime.now().subtract(const Duration(days: 1));
      if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day) return 'Yesterday';
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brief Settings Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _BriefSettingsSheet extends StatefulWidget {
  final String   initialMorning;
  final String   initialEvening;
  final bool     initialEnabled;
  final Future<void> Function(String morning, String evening, bool enabled) onSaved;

  const _BriefSettingsSheet({
    required this.initialMorning,
    required this.initialEvening,
    required this.initialEnabled,
    required this.onSaved,
  });

  @override
  State<_BriefSettingsSheet> createState() => _BriefSettingsSheetState();
}

class _BriefSettingsSheetState extends State<_BriefSettingsSheet> {
  late String _morning;
  late String _evening;
  late bool   _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _morning = widget.initialMorning;
    _evening = widget.initialEvening;
    _enabled = widget.initialEnabled;
  }

  // Convert "HH:MM" → TimeOfDay for showTimePicker
  TimeOfDay _toTod(String hhmm) {
    try {
      final parts = hhmm.split(':');
      return TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  // Convert TimeOfDay → "HH:MM"
  String _fromTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  /// Converts "07:00" → "7:00 AM"  /  "19:30" → "7:30 PM"
  String _label(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final ap  = h < 12 ? 'AM' : 'PM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:${m.toString().padLeft(2, '0')} $ap';
    } catch (_) {
      return hhmm;
    }
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final initial = _toTod(isMorning ? _morning : _evening);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _verdigris,
            onPrimary: _white,
            surface: Color(0xFF0A2A38),
            onSurface: _white,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: const Color(0xFF0A1A22),
            hourMinuteColor: _surfaceEl,
            hourMinuteTextColor: _white,
            dialBackgroundColor: _surfaceEl,
            dialHandColor: _verdigris,
            dialTextColor: MaterialStateColor.resolveWith(
              (states) => states.contains(MaterialState.selected)
                  ? _white
                  : _textSec,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isMorning) {
          _morning = _fromTod(picked);
        } else {
          _evening = _fromTod(picked);
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSaved(_morning, _evening, _enabled);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF061820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ───────────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _textTer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ─────────────────────────────────────────────────────
          Text('Brief Schedule',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: _white)),
          const SizedBox(height: 4),
          Text('Times are in your local timezone.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _textSec)),
          const SizedBox(height: 24),

          // ── Enable toggle ──────────────────────────────────────────────
          _settingsRow(
            icon: Icons.notifications_rounded,
            label: 'Enable daily briefs',
            trailing: Switch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeColor: _verdigris,
              inactiveTrackColor: _surfaceEl,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: _border, height: 1),
          const SizedBox(height: 8),

          // ── Morning time ───────────────────────────────────────────────
          Opacity(
            opacity: _enabled ? 1.0 : 0.45,
            child: GestureDetector(
              onTap: _enabled ? () => _pickTime(isMorning: true) : null,
              child: _settingsRow(
                icon: Icons.wb_sunny_rounded,
                iconColor: _chartreuse,
                label: 'Morning brief',
                sublabel: 'Sent after this time if slot has passed',
                trailing: _timeChip(_label(_morning)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Evening time ───────────────────────────────────────────────
          Opacity(
            opacity: _enabled ? 1.0 : 0.45,
            child: GestureDetector(
              onTap: _enabled ? () => _pickTime(isMorning: false) : null,
              child: _settingsRow(
                icon: Icons.nightlight_round,
                iconColor: const Color(0xFF7B8CDE),
                label: 'Evening brief',
                sublabel: 'Sent after this time if slot has passed',
                trailing: _timeChip(_label(_evening)),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Save button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _verdigris,
                foregroundColor: _white,
                disabledBackgroundColor: _verdigris.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: _white, strokeWidth: 2.5))
                  : Text('Save Schedule',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: _white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    String? sublabel,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _surfaceEl,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: iconColor ?? _verdigris, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: _white,
                      fontWeight: FontWeight.w500)),
              if (sublabel != null)
                Text(sublabel,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _textSec)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _timeChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: _verdigris.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _verdigris.withOpacity(0.5)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 13, color: _verdigris,
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      const Icon(Icons.edit_rounded, color: _verdigris, size: 12),
    ]),
  );
}

// ── Local date alias (avoids conflict with Flutter's DateUtils) ────────────────
class DateUtils2 {
  static String briefTimeOfDay() =>
      DateTime.now().hour >= 17 ? 'evening' : 'morning';

  static String briefKey() {
    final tod  = briefTimeOfDay();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return '${tod}_$date';
  }

  static bool isBriefStale(String? key) => key == null || key != briefKey();

  static String shortDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
  }
}
