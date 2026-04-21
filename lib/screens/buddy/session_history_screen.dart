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
const _crimson   = Color(0xFFFF3B30);

// ── Data class that combines a conversation with its loaded detail ─────────────
class _ConvSummary {
  final ConversationModel conv;
  final int messageCount;
  /// Last message timestamp, or null if unknown
  final DateTime? lastAt;

  const _ConvSummary({
    required this.conv,
    required this.messageCount,
    this.lastAt,
  });
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
  List<_ConvSummary>? _summaries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _loadConversations() async {
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      final convs = await BuddyApiService.instance.getConversations();

      // Load messages for each conversation in parallel (cap at 30 threads).
      // This gives us message count + the last-message timestamp.
      final limited = convs.take(30).toList();

      final msgFutures = limited.map((c) =>
        BuddyApiService.instance
            .getConversationMessages(c.id)
            .catchError((_) => <ConversationMessageModel>[]));

      final allMessages = await Future.wait(msgFutures);

      final summaries = List.generate(limited.length, (i) {
        final msgs  = allMessages[i];
        final conv  = limited[i];

        // ── Derive timestamp ─────────────────────────────────────────────────
        // Priority: conversation.updatedAt → last message createdAt → null
        DateTime? lastAt;
        final rawTs = conv.updatedAt ?? conv.createdAt;
        if (rawTs != null) {
          lastAt = _tryParseDate(rawTs);
        } else if (msgs.isNotEmpty) {
          final msgTs = msgs.last.createdAt;
          if (msgTs != null) lastAt = _tryParseDate(msgTs);
        }

        return _ConvSummary(
          conv:         conv,
          messageCount: msgs.length,
          lastAt:       lastAt,
        );
      });

      if (mounted) setState(() { _summaries = summaries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error   = 'Could not load session history.\nCheck your connection and try again.';
        _loading = false;
      });
    }
  }

  DateTime? _tryParseDate(String s) {
    try { return DateTime.parse(s).toLocal(); } catch (_) { return null; }
  }

  // ── Timestamp display ─────────────────────────────────────────────────────────
  String _formatDate(DateTime? dt, int index) {
    if (dt == null) {
      // No timestamp from API — derive a label from list position
      if (index == 0) return 'Most recent';
      if (index == 1) return 'Previous';
      return 'Earlier';
    }
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    final h     = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min   = dt.minute.toString().padLeft(2, '0');
    final ampm  = dt.hour < 12 ? 'AM' : 'PM';
    final time  = '$h:$min $ampm';

    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }

  // ── Derive display title ──────────────────────────────────────────────────────
  String _displayTitle(_ConvSummary s) {
    final raw = s.conv.title;
    if (raw != null && raw.trim().isNotEmpty && raw != 'Main') return raw.trim();
    return 'Conversation #${s.conv.id}';
  }

  // ── Detail sheet ─────────────────────────────────────────────────────────────
  void _showDetail(BuildContext context, _ConvSummary summary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConversationDetailSheet(
        summary: summary,
        displayTitle: _displayTitle(summary),
        formatDate: (dt) => _formatDate(dt, 0),
      ),
    );
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
            onTap: _loadConversations,
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
    if (_error != null) return _buildError();
    final list = _summaries ?? [];
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
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _verdigris,
            ),
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
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textSec, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadConversations,
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

  Widget _buildList(BuildContext context, List<_ConvSummary> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildCard(ctx, list[i], i),
    );
  }

  // ── Conversation card ─────────────────────────────────────────────────────────
  Widget _buildCard(BuildContext context, _ConvSummary s, int index) {
    final dateLabel = _formatDate(s.lastAt, index);
    final title     = _displayTitle(s);

    return GestureDetector(
      onTap: () => _showDetail(context, s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Meta row: date | message count ──────────────────────────────
            Row(
              children: [
                // Clock + date
                const Icon(Icons.access_time_rounded,
                    color: _amber, size: 14),
                const SizedBox(width: 5),
                Text(
                  dateLabel,
                  style: GoogleFonts.inter(
                    color: _amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Chat bubble + count
                if (s.messageCount > 0) ...[
                  const Icon(Icons.chat_bubble_outline_rounded,
                      color: _textSec, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${s.messageCount}',
                    style: GoogleFonts.inter(
                      color: _textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // ── Conversation title ───────────────────────────────────────────
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation Detail Bottom Sheet
// Shows full message transcript for one conversation, loaded from the API.
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationDetailSheet extends StatefulWidget {
  final _ConvSummary summary;
  final String displayTitle;
  final String Function(DateTime?) formatDate;

  const _ConversationDetailSheet({
    required this.summary,
    required this.displayTitle,
    required this.formatDate,
  });

  @override
  State<_ConversationDetailSheet> createState() =>
      _ConversationDetailSheetState();
}

class _ConversationDetailSheetState extends State<_ConversationDetailSheet> {
  List<ConversationMessageModel>? _messages;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await BuddyApiService.instance
          .getConversationMessages(widget.summary.conv.id);
      if (mounted) setState(() { _messages = msgs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _messages = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.82),
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
                      Text(widget.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _white)),
                      if (widget.summary.lastAt != null) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.access_time_rounded,
                              color: _amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            widget.formatDate(widget.summary.lastAt),
                            style: GoogleFonts.inter(
                                color: _amber, fontSize: 11),
                          ),
                        ]),
                      ],
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
          Flexible(child: _buildMessages()),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _verdigris)),
      );
    }

    final msgs = _messages ?? [];
    if (msgs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('No messages in this session',
              style: GoogleFonts.inter(color: _textSec, fontSize: 14)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: msgs.length,
      itemBuilder: (_, i) => _buildBubble(msgs[i]),
    );
  }

  Widget _buildBubble(ConversationMessageModel msg) {
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
          child: Text(
            msg.content,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isUser ? _white : const Color(0xFFD0D0D0),
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
