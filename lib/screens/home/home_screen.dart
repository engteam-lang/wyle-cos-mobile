import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wyle_cos/models/obligation_model.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';
import 'package:wyle_cos/services/brief_service.dart';
import 'package:wyle_cos/services/google_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour constants (inline so this file is self-contained)
// ─────────────────────────────────────────────────────────────────────────────
const Color _bgDark       = Color(0xFF0D0D0D);
const Color _surfaceDark  = Color(0xFF161616);
const Color _surfaceEl    = Color(0xFF1E1E1E);
const Color _verdigris    = Color(0xFF1B998B);
const Color _chartreuse   = Color(0xFFD5FF3F);
const Color _chartreuseB  = Color(0xFFA8CC00);
const Color _crimson      = Color(0xFFFF3B30);
const Color _orange       = Color(0xFFFF9500);
const Color _white        = Color(0xFFFFFFFF);
const Color _textSec      = Color(0xFF9A9A9A);
const Color _textTer      = Color(0xFF555555);
const Color _border       = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late Timer _clockTimer;
  String _timeString = '';
  bool _briefLoading = false;

  // Urgent-dot blink animation
  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateClock());

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.2, end: 1.0).animate(_blinkCtrl);

    // Load morning brief if stale
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBriefIfStale());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _blinkCtrl.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    setState(() => _timeString = '$h:$m');
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _isEvening => DateTime.now().hour >= 17;

  String _briefKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadBriefIfStale() async {
    final state = ref.read(appStateProvider);
    if (state.lastBriefKey == _briefKey()) return;
    setState(() => _briefLoading = true);
    try {
      final brief = await BriefService.instance.generateBrief(
        state.obligations,
        99,
      );
      ref.read(appStateProvider.notifier).setMorningBrief(brief);
      await ref.read(appStateProvider.notifier).setLastBriefKey(_briefKey());
    } catch (_) {}
    if (mounted) setState(() => _briefLoading = false);
  }

  // ── helpers ──────────────────────────────────────────────────────────────────
  Color _daysColor(String risk, int days) {
    if (risk == 'high' || days <= 7) return _crimson;
    if (risk == 'medium' || days <= 21) return _orange;
    return _verdigris;
  }

  String _daysLabel(int days) => days == 0 ? 'TODAY' : '${days}d';

  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(appStateProvider);
    final obligations = ref.watch(activeObligationsProvider);

    final urgentAlert   = obligations.isNotEmpty ? obligations[0] : null;
    final featuredTask  = obligations.length > 1  ? obligations[1] : null;
    final gridTasks     = obligations.length > 2
        ? obligations.sublist(2, obligations.length.clamp(0, 6))
        : <ObligationModel>[];
    final executeItems  = obligations
        .where((o) => o.risk == 'high' || o.risk == 'medium')
        .take(2)
        .toList();

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(state),
                    const SizedBox(height: 16),
                    _buildStatsBar(obligations),
                    const SizedBox(height: 16),
                    _buildMorningBriefBanner(state),
                    const SizedBox(height: 16),
                    if (urgentAlert != null) ...[
                      _buildUrgentCard(urgentAlert),
                      const SizedBox(height: 16),
                    ],
                    _buildGoogleBanner(state),
                    const SizedBox(height: 16),
                    if (obligations.isEmpty)
                      _buildEmptyState()
                    else ...[
                      _buildPrioritySection(featuredTask, gridTasks, obligations),
                      const SizedBox(height: 16),
                      _buildExecuteSection(executeItems),
                    ],
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AppState state) {
    final firstName = state.user?.name?.split(' ').first ?? 'there';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _timeString,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _textSec,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_greeting, $firstName',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your digital chief of staff is active',
                style: GoogleFonts.inter(fontSize: 13, color: _textSec),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Row(
              children: [
                _dot(_textTer),
                const SizedBox(width: 5),
                _dot(_textTer),
                const SizedBox(width: 5),
                _dot(_white),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  // ── Stats bar ────────────────────────────────────────────────────────────────
  Widget _buildStatsBar(List<ObligationModel> obligations) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _statCell('4.5 HRS SAVED', _white),
            _divider(),
            _statCell('${obligations.length} RUNNING', _verdigris),
            _divider(),
            _statCell('99% RELIABLE', _chartreuse),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String label, Color color) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      );

  Widget _divider() => Container(
        width: 1,
        color: _border,
      );

  // ── Morning brief banner ──────────────────────────────────────────────────────
  Widget _buildMorningBriefBanner(AppState state) {
    final headline = state.morningBrief?.headline ??
        "Tap to view today's priorities";
    final emoji = _isEvening ? '🌙' : '☀️';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.morningBrief),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 48,
              decoration: BoxDecoration(
                color: _verdigris,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        'MORNING BRIEF · LIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _verdigris,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (_briefLoading)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _verdigris,
                      ),
                    )
                  else
                    Text(
                      headline,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _white,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textSec, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Urgent card ───────────────────────────────────────────────────────────────
  Widget _buildUrgentCard(ObligationModel ob) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _crimson.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge row
          Row(
            children: [
              AnimatedBuilder(
                animation: _blinkAnim,
                builder: (_, __) => Opacity(
                  opacity: _blinkAnim.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _crimson,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'URGENT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _crimson,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _crimson.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _daysLabel(ob.daysUntil),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _crimson,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title row
          Row(
            children: [
              Text(ob.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ob.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ob.notes ?? ob.executionPath,
                      style: GoogleFonts.inter(fontSize: 12, color: _textSec),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Handle with Buddy button
          GestureDetector(
            onTap: () => context.go(AppRoutes.buddy),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9F8A), _crimson],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  'Handle with Buddy',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Google data fetchers ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchCalendarEvents() async {
    final token = await GoogleAuthService.instance.getAccessToken();
    if (token == null) return [];
    final now = DateTime.now().toUtc().toIso8601String();
    final uri = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events'
      '?orderBy=startTime&singleEvents=true&maxResults=10&timeMin=${Uri.encodeComponent(now)}',
    );
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) return [];
    final body = json.decode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['items'] ?? []);
  }

  Future<List<Map<String, dynamic>>> _fetchGmailMessages() async {
    final token = await GoogleAuthService.instance.getAccessToken();
    if (token == null) return [];
    final listUri = Uri.parse(
      'https://www.googleapis.com/gmail/v1/users/me/messages?maxResults=8&q=is:unread',
    );
    final listRes = await http.get(listUri, headers: {'Authorization': 'Bearer $token'});
    if (listRes.statusCode != 200) return [];
    final listBody = json.decode(listRes.body) as Map<String, dynamic>;
    final messages = List<Map<String, dynamic>>.from(listBody['messages'] ?? []);
    final result = <Map<String, dynamic>>[];
    for (final msg in messages.take(8)) {
      final id = msg['id'];
      final detailUri = Uri.parse(
        'https://www.googleapis.com/gmail/v1/users/me/messages/$id'
        '?format=metadata&metadataHeaders=subject&metadataHeaders=from&metadataHeaders=date',
      );
      final detailRes = await http.get(detailUri, headers: {'Authorization': 'Bearer $token'});
      if (detailRes.statusCode == 200) {
        final detail = json.decode(detailRes.body) as Map<String, dynamic>;
        final headers = List<Map<String, dynamic>>.from(
          detail['payload']?['headers'] ?? [],
        );
        String subject = '(no subject)';
        String from = '';
        for (final h in headers) {
          if (h['name'] == 'Subject') subject = h['value'] ?? subject;
          if (h['name'] == 'From') from = h['value'] ?? from;
        }
        result.add({'subject': subject, 'from': from, 'id': id});
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchDriveFiles() async {
    final token = await GoogleAuthService.instance.getAccessToken();
    if (token == null) return [];
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?pageSize=10&orderBy=modifiedTime+desc'
      '&fields=files(id,name,mimeType,modifiedTime)',
    );
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) return [];
    final body = json.decode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['files'] ?? []);
  }

  void _openCalendarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _AsyncSheetContent(
        title: 'Upcoming Events',
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFF1A73E8),
        future: _fetchCalendarEvents(),
        emptyMessage: 'No upcoming events found.',
        itemBuilder: (item) {
          final summary = item['summary'] ?? 'Untitled Event';
          final start = item['start'];
          String timeStr = '';
          if (start != null) {
            final dt = start['dateTime'] ?? start['date'];
            if (dt != null) {
              try {
                final parsed = DateTime.parse(dt as String).toLocal();
                timeStr = start['dateTime'] != null
                    ? DateFormat('EEE, MMM d · h:mm a').format(parsed)
                    : DateFormat('EEE, MMM d').format(parsed);
              } catch (_) {
                timeStr = dt.toString();
              }
            }
          }
          return _sheetItem(
            icon: Icons.event_rounded,
            iconColor: const Color(0xFF1A73E8),
            title: summary,
            subtitle: timeStr,
          );
        },
      ),
    );
  }

  void _openGmailSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _AsyncSheetContent(
        title: 'Unread Emails',
        icon: Icons.mail_rounded,
        iconColor: const Color(0xFFEA4335),
        future: _fetchGmailMessages(),
        emptyMessage: 'No unread emails.',
        itemBuilder: (item) => _sheetItem(
          icon: Icons.mail_outline_rounded,
          iconColor: const Color(0xFFEA4335),
          title: item['subject'] ?? '(no subject)',
          subtitle: item['from'] ?? '',
        ),
      ),
    );
  }

  void _openDriveSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _AsyncSheetContent(
        title: 'Recent Drive Files',
        icon: Icons.folder_rounded,
        iconColor: const Color(0xFF34A853),
        future: _fetchDriveFiles(),
        emptyMessage: 'No recent files found.',
        itemBuilder: (item) {
          final name = item['name'] ?? 'Unnamed';
          String modified = '';
          if (item['modifiedTime'] != null) {
            try {
              final dt = DateTime.parse(item['modifiedTime'] as String).toLocal();
              modified = DateFormat('MMM d, y').format(dt);
            } catch (_) {}
          }
          return _sheetItem(
            icon: _driveIcon(item['mimeType'] ?? ''),
            iconColor: const Color(0xFF34A853),
            title: name,
            subtitle: modified.isNotEmpty ? 'Modified $modified' : '',
          );
        },
      ),
    );
  }

  IconData _driveIcon(String mimeType) {
    if (mimeType.contains('spreadsheet')) return Icons.table_chart_rounded;
    if (mimeType.contains('presentation')) return Icons.slideshow_rounded;
    if (mimeType.contains('document')) return Icons.description_rounded;
    if (mimeType.contains('folder')) return Icons.folder_rounded;
    if (mimeType.contains('image')) return Icons.image_rounded;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Widget _sheetItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: _textSec),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Google banner ─────────────────────────────────────────────────────────────
  Widget _buildGoogleBanner(AppState state) {
    if (!state.googleConnected) {
      return _buildConnectBanner();
    }
    return _buildConnectedBanner(state);
  }

  Widget _buildConnectBanner() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.connect),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYNC YOUR SCHEDULE',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _textSec,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.connect),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _googleColorIcon(),
                          const SizedBox(width: 8),
                          Text(
                            'Connect Google Calendar & Gmail',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F1F1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBanner(AppState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _googleColorIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.googleEmail,
                  style: GoogleFonts.inter(fontSize: 12, color: _textSec),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _verdigris.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Connected',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _verdigris,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chipBadge('Gmail', const Color(0xFFEA4335), onTap: _openGmailSheet),
              const SizedBox(width: 8),
              _chipBadge('Calendar', const Color(0xFF1A73E8), onTap: _openCalendarSheet),
              const SizedBox(width: 8),
              _chipBadge('Drive', const Color(0xFF34A853), onTap: _openDriveSheet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _googleColorIcon() {
    return const SizedBox(
      width: 18,
      height: 18,
      child: _GoogleG(),
    );
  }

  Widget _chipBadge(String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(Icons.chevron_right, color: color, size: 12),
            ],
          ],
        ),
      ),
    );
  }

  // ── Priority tasks section ────────────────────────────────────────────────────
  Widget _buildPrioritySection(
    ObligationModel? featured,
    List<ObligationModel> grid,
    List<ObligationModel> all,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PRIORITY TASKS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textSec,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _verdigris.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${all.length} active',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _verdigris,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (featured != null) ...[
          _buildFeaturedCard(featured),
          const SizedBox(height: 10),
        ],
        if (grid.isNotEmpty) _buildGridTasks(grid),
      ],
    );
  }

  Widget _buildFeaturedCard(ObligationModel ob) {
    final topColor = _daysColor(ob.risk, ob.daysUntil);
    return GestureDetector(
      onTap: () => context.go(AppRoutes.obligations),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            // gradient top border
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [topColor, topColor.withOpacity(0.2)],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(ob.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ob.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ob.executionPath,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _textSec),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: topColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _daysLabel(ob.daysUntil),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: topColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: _textTer, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTasks(List<ObligationModel> tasks) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: tasks.length,
      itemBuilder: (_, i) => _buildSmallTaskCard(tasks[i]),
    );
  }

  Widget _buildSmallTaskCard(ObligationModel ob) {
    final c = _daysColor(ob.risk, ob.daysUntil);
    return GestureDetector(
      onTap: () => context.go(AppRoutes.obligations),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceEl,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ob.emoji, style: const TextStyle(fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _daysLabel(ob.daysUntil),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              ob.title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Ready to Execute section ──────────────────────────────────────────────────
  Widget _buildExecuteSection(List<ObligationModel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'READY TO EXECUTE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textSec,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((ob) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildExecuteCard(ob),
            )),
      ],
    );
  }

  Widget _buildExecuteCard(ObligationModel ob) {
    final isHigh = ob.risk == 'high';
    final confidence = isHigh ? '94%' : '88%';
    final confidenceLabel = isHigh ? 'high' : 'medium';
    final saves = isHigh ? 45 : 30;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ob.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ob.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _verdigris.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$confidence $confidenceLabel',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _verdigris,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'saves ${saves}m',
            style: GoogleFonts.inter(fontSize: 11, color: _textSec),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.buddy),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_chartreuse, _chartreuseB],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'Approve & Execute',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D0D0D),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.obligations),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'Review',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textSec,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Text('🗂️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Your stack is clear',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No active obligations. Add one to get started.',
            style: GoogleFonts.inter(fontSize: 13, color: _textSec),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.go(AppRoutes.obligations),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_verdigris, _chartreuse]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  'Add your first task →',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _bgDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.go(AppRoutes.buddy),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  '🎙️ Voice Brain Dump with Buddy',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textSec,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textSec,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                icon: '✦',
                label: 'Automations',
                onTap: () => context.go(AppRoutes.obligations),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: '▦',
                label: 'Insights',
                onTap: () => context.go(AppRoutes.insights),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _surfaceEl,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Text(
              icon,
              style: GoogleFonts.inter(
                fontSize: 22,
                color: _verdigris,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Async bottom-sheet content (loads data then renders list)
// ─────────────────────────────────────────────────────────────────────────────
class _AsyncSheetContent extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Future<List<Map<String, dynamic>>> future;
  final String emptyMessage;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _AsyncSheetContent({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.future,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  @override
  State<_AsyncSheetContent> createState() => _AsyncSheetContentState();
}

class _AsyncSheetContentState extends State<_AsyncSheetContent> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF555555),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          // Content
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1B998B), strokeWidth: 2,
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load data.\nCheck your Google connection.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF9A9A9A)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      widget.emptyMessage,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF9A9A9A)),
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF2A2A2A), height: 1, indent: 16),
                  itemBuilder: (_, i) => widget.itemBuilder(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiny Google "G" painted widget
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    const colors = [
      Color(0xFF4285F4),
      Color(0xFF34A853),
      Color(0xFFFBBC05),
      Color(0xFFEA4335),
    ];
    const sweeps = [
      [0.0, 1.6],
      [1.6, 1.6],
      [3.2, 0.8],
      [4.0, 2.3],
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.25
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.75),
        sweeps[i][0],
        sweeps[i][1],
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
