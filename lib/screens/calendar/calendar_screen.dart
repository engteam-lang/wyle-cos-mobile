import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _crimson   = Color(0xFFFF3B30);
const _orange    = Color(0xFFFF9500);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);

class _CalEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final String calendar; // 'google' | 'outlook'
  final String? color;
  final bool hasConflict;
  const _CalEvent({
    required this.title, required this.start, required this.end,
    required this.calendar, this.color, this.hasConflict = false,
  });
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _loading = false;
  List<_CalEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    // Mock calendar events
    final now = DateTime.now();
    setState(() {
      _events = [
        _CalEvent(
          title: 'Team Standup',
          start: now.copyWith(hour: 9, minute: 0),
          end:   now.copyWith(hour: 9, minute: 30),
          calendar: 'google', color: '#4285F4',
        ),
        _CalEvent(
          title: 'Emirates ID Appointment',
          start: now.copyWith(hour: 11, minute: 0),
          end:   now.copyWith(hour: 12, minute: 0),
          calendar: 'google', color: '#34A853',
        ),
        _CalEvent(
          title: 'Project Review',
          start: now.copyWith(hour: 14, minute: 0),
          end:   now.copyWith(hour: 15, minute: 30),
          calendar: 'outlook', color: '#0078D4',
        ),
        _CalEvent(
          title: 'Client Call',
          start: now.copyWith(hour: 14, minute: 30),
          end:   now.copyWith(hour: 15, minute: 0),
          calendar: 'google', color: '#EA4335',
          hasConflict: true,
        ),
      ];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (!state.googleConnected && state.outlookAccounts.isEmpty)
              _buildNoAccountBanner()
            else
              Expanded(child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _verdigris))
                  : _buildEventList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calendar', style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
                Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                    style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadEvents,
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

  Widget _buildNoAccountBanner() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, color: _verdigris, size: 40),
            const SizedBox(height: 14),
            Text('Connect Your Calendar', style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: _white)),
            const SizedBox(height: 8),
            Text('Connect Google Calendar or Outlook to see your events and detect conflicts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _textSec, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList() {
    final conflicts = _events.where((e) => e.hasConflict).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conflicts.isNotEmpty) ...[
            _sectionLabel('⚠️  CONFLICTS DETECTED'),
            const SizedBox(height: 8),
            ...conflicts.map((e) => _buildConflictBanner(e)),
            const SizedBox(height: 16),
          ],
          _sectionLabel('TODAY\'S EVENTS'),
          const SizedBox(height: 8),
          ..._events.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildEventCard(e),
          )),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
        color: _textTer, letterSpacing: 1.5));

  Widget _buildConflictBanner(_CalEvent e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _crimson.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _crimson.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: _crimson, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Conflict: "${e.title}" overlaps with another event',
          style: GoogleFonts.inter(fontSize: 13, color: _crimson),
        )),
      ]),
    );
  }

  Widget _buildEventCard(_CalEvent e) {
    final color  = _parseColor(e.color ?? '#1B998B');
    final dur    = e.end.difference(e.start).inMinutes;
    final isGoog = e.calendar == 'google';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: e.hasConflict
            ? _crimson.withOpacity(0.4) : _border),
      ),
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('HH:mm').format(e.start),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: _white, fontWeight: FontWeight.w600)),
                Text('${dur}m',
                    style: GoogleFonts.inter(fontSize: 11, color: _textTer)),
              ],
            ),
          ),
          // Color strip
          Container(width: 3, height: 40,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: GoogleFonts.inter(
                    fontSize: 14, color: _white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(isGoog ? Icons.g_mobiledata : Icons.mail_outline,
                      color: _textTer, size: 13),
                  const SizedBox(width: 4),
                  Text(isGoog ? 'Google' : 'Outlook',
                      style: GoogleFonts.inter(fontSize: 11, color: _textTer)),
                  if (e.hasConflict) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _crimson.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('CONFLICT',
                          style: GoogleFonts.inter(
                              fontSize: 9, color: _crimson, fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _verdigris;
    }
  }
}
