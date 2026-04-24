import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/conversation_model.dart';
import '../../services/buddy_api_service.dart';

// ── Palette (matches Buddy screen) ────────────────────────────────────────────
const _bgTop     = Color(0xFF002F3A);
const _bgBot     = Color(0xFF000D12);
const _surface   = Color(0xFF0A2A38);
const _border    = Color(0xFF1C4A56);
const _verdigris = Color(0xFF1B998B);
const _amber     = Color(0xFFCB9A2D);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);

// ── A day-session: all messages from one calendar day ─────────────────────────
class _DaySession {
  final DateTime date;           // midnight of the day (local)
  final List<ConversationMessageModel> messages;

  const _DaySession({required this.date, required this.messages});

  int get messageCount => messages.length;

  /// User-visible label: "Today", "Yesterday", or "Apr 22, 2026"
  String get dateLabel {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff  = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Time range: "9:30 AM – 11:45 AM"
  String get timeRange {
    if (messages.isEmpty) return '';
    DateTime? first = _msgTime(messages.first);
    DateTime? last  = _msgTime(messages.last);
    if (first == null) return '';
    final start = _fmt12(first);
    if (last == null || last == first) return start;
    return '$start – ${_fmt12(last)}';
  }

  static DateTime? _msgTime(ConversationMessageModel m) {
    if (m.createdAt == null) return null;
    try { return DateTime.parse(m.createdAt!).toLocal(); } catch (_) { return null; }
  }

  static String _fmt12(DateTime dt) {
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min  = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$min $ampm';
  }

  /// Number of user turns
  int get userTurns => messages.where((m) => m.role == 'user').length;
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionHistoryScreen
// ─────────────────────────────────────────────────────────────────────────────
class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  List<_DaySession>? _sessions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _loadSessions() async {
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      // 1. Fetch all conversations
      final convs = await BuddyApiService.instance.getConversations();
      if (convs.isEmpty) {
        if (mounted) setState(() { _sessions = []; _loading = false; });
        return;
      }

      // 2. Fetch messages for each conversation (parallel, capped at 30)
      final limited = convs.take(30).toList();
      final msgFutures = limited.map((c) =>
          BuddyApiService.instance
              .getConversationMessages(c.id)
              .catchError((_) => <ConversationMessageModel>[]));
      final allMessages = await Future.wait(msgFutures);

      // 3. Flatten every message, then group by calendar day
      final flat = allMessages.expand((msgs) => msgs).toList();
      final Map<DateTime, List<ConversationMessageModel>> byDay = {};

      for (final msg in flat) {
        DateTime dayKey;
        if (msg.createdAt != null) {
          try {
            final dt = DateTime.parse(msg.createdAt!).toLocal();
            dayKey = DateTime(dt.year, dt.month, dt.day);
          } catch (_) {
            dayKey = DateTime(1970); // unknown date bucket
          }
        } else {
          dayKey = DateTime(1970);
        }
        byDay.putIfAbsent(dayKey, () => []).add(msg);
      }

      // 4. Sort days newest-first; discard the unknown-date bucket if empty
      final days = byDay.keys
          .where((d) => d.year != 1970 || (byDay[d]?.isNotEmpty ?? false))
          .toList()
        ..sort((a, b) => b.compareTo(a));

      // If all messages lacked timestamps, fall back to one "All messages" session
      if (days.isEmpty && flat.isNotEmpty) {
        final fallback = _DaySession(date: DateTime(1970), messages: flat);
        if (mounted) setState(() { _sessions = [fallback]; _loading = false; });
        return;
      }

      final sessions = days.map((d) => _DaySession(
        date:     d,
        messages: List.unmodifiable(byDay[d]!),
      )).toList();

      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error   = 'Could not load session history.\nCheck your connection and try again.';
        _loading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, Color(0xFF001E29), _bgBot],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        )),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Text(
            'Session History',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _white,
            ),
          ),
          const Spacer(),
          // Refresh
          GestureDetector(
            onTap: _loadSessions,
            child: Container(
              width: 36, height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A4A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.refresh_rounded, color: _textSec, size: 18),
            ),
          ),
          // Close
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A4A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.close_rounded, color: _textSec, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error  != null) return _buildError();
    final list = _sessions ?? [];
    if (list.isEmpty) return _buildEmpty();
    return _buildList(context, list);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _verdigris),
          ),
          const SizedBox(height: 16),
          Text('Loading sessions…',
              style: GoogleFonts.inter(color: _textSec, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _textSec, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _textSec, fontSize: 14, height: 1.5)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadSessions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _verdigris,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Retry',
                    style: GoogleFonts.inter(
                        color: _white, fontSize: 14, fontWeight: FontWeight.w600)),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: _textSec, size: 48),
          const SizedBox(height: 16),
          Text('No sessions yet',
              style: GoogleFonts.poppins(
                  color: _white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Your Buddy conversation history will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textSec, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<_DaySession> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildCard(ctx, list[i]),
    );
  }

  // ── Session card (one per day) ─────────────────────────────────────────────
  Widget _buildCard(BuildContext context, _DaySession session) {
    final isToday     = session.dateLabel == 'Today';
    final isYesterday = session.dateLabel == 'Yesterday';
    final accentColor = isToday ? _verdigris : (isYesterday ? _amber : _textSec);

    return GestureDetector(
      onTap: () => _showDetail(context, session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday ? _verdigris.withOpacity(0.5) : _border,
            width: isToday ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: date badge | message count ─────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isToday
                            ? Icons.today_rounded
                            : Icons.calendar_today_rounded,
                        color: accentColor,
                        size: 12,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        session.dateLabel,
                        style: GoogleFonts.inter(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Message count pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          color: _textSec, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${session.messageCount} messages',
                        style: GoogleFonts.inter(
                          color: _textSec,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Time range ──────────────────────────────────────────────────
            if (session.timeRange.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: _textSec, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    session.timeRange,
                    style: GoogleFonts.inter(
                      color: _textSec,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── Preview: first user message ─────────────────────────────────
            Builder(builder: (_) {
              final firstUser = session.messages
                  .where((m) => m.role == 'user')
                  .firstOrNull;
              if (firstUser == null) return const SizedBox.shrink();
              return Text(
                '"${firstUser.content}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Detail sheet ─────────────────────────────────────────────────────────────
  void _showDetail(BuildContext context, _DaySession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DaySessionDetailSheet(session: session),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheet — shows all messages for one day
// ─────────────────────────────────────────────────────────────────────────────
class _DaySessionDetailSheet extends StatelessWidget {
  final _DaySession session;
  const _DaySessionDetailSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFF071512),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3E3B),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 14),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.dateLabel}\'s Session',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _white),
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.access_time_rounded,
                            color: _amber, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          session.timeRange.isNotEmpty
                              ? session.timeRange
                              : '${session.messageCount} messages',
                          style: GoogleFonts.inter(color: _amber, fontSize: 11),
                        ),
                      ]),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A2E2B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1C3430), height: 1),

          // Messages
          Flexible(
            child: session.messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text('No messages',
                          style: GoogleFonts.inter(
                              color: _textSec, fontSize: 14)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: session.messages.length,
                    itemBuilder: (_, i) => _buildBubble(context, session.messages[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, ConversationMessageModel msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? _verdigris.withOpacity(0.22)
                : const Color(0xFF0F2420),
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(16),
              topRight:    const Radius.circular(16),
              bottomLeft:  Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(
              color: isUser
                  ? _verdigris.withOpacity(0.35)
                  : const Color(0xFF1F3A36),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.content,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isUser ? _white : const Color(0xFFD0D0D0),
                  height: 1.5,
                ),
              ),
              if (msg.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _bubbleTime(msg.createdAt!),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _bubbleTime(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min  = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '$h:$min $ampm';
    } catch (_) {
      return '';
    }
  }
}
