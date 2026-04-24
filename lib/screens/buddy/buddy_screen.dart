import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/chat_message_model.dart';
import '../../models/conversation_model.dart';
import '../../models/insights_summary_model.dart';
import '../../models/obligation_model.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../services/buddy_api_service.dart';
import '../../services/voice_service.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
const _bgTop      = Color(0xFF002F3A);   // matches login screen gradient top
const _bgBot      = Color(0xFF000D12);   // matches login screen gradient bottom
const _surface    = Color(0xFF0A2A38);
const _surfaceEl  = Color(0xFF1A3A4A);
const _border     = Color(0xFF1C4A56);
const _verdigris  = Color(0xFF1B998B);
const _crimson    = Color(0xFFFF3B30);
const _white      = Color(0xFFFFFFFF);
const _textSec    = Color(0xFF9A9A9A);
const _textTer    = Color(0xFF4A4A4A);
const _alertBg    = Color(0xFF1A0808);

// ─────────────────────────────────────────────────────────────────────────────
// Completion-intent helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns true if the utterance looks like "I finished / paid / completed …"
bool _hasCompletionIntent(String text) {
  final lower = text.toLowerCase();
  const patterns = [
    'i paid', 'i have paid', "i've paid",
    'i completed', 'i have completed', "i've completed",
    'i finished', 'i have finished', "i've finished",
    'already paid', 'already done', 'already completed',
    'mark as completed', 'mark as done', 'mark it as',
    'done with', 'completed the', 'paid the', 'finished the',
    'i did the', 'i have done', "i've done",
    'remove the task', 'remove it from',
  ];
  return patterns.any((p) => lower.contains(p));
}

String _normalizeForMatch(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();

/// Fuzzy-matches the utterance against active obligations.
/// Returns the best match or null.
ObligationModel? _findObligationInUtterance(
    String text, List<ObligationModel> obligations) {
  final lower = _normalizeForMatch(text);
  for (final ob in obligations) {
    if (ob.status == 'completed') continue;
    final words = _normalizeForMatch(ob.title)
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();
    if (words.isEmpty) continue;
    final matched = words.where((w) => lower.contains(w)).length;
    if (matched / words.length >= 0.5) return ob;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// BuddyScreen
// ─────────────────────────────────────────────────────────────────────────────
class BuddyScreen extends ConsumerStatefulWidget {
  const BuddyScreen({super.key});

  @override
  ConsumerState<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends ConsumerState<BuddyScreen>
    with TickerProviderStateMixin {

  static const _kChatMessages = 'wyle_buddy_messages';
  static const _kChatDate     = 'wyle_buddy_date';

  final List<ChatMessageModel> _messages   = [];
  final TextEditingController  _textCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  bool           _isRecording  = false;
  bool           _isProcessing = false;
  bool           _isSpeaking   = false;
  String         _partialText  = '';
  PlatformFile?  _attachedFile;
  bool           _alertDismissed = false;

  late AnimationController _waveCtrl;
  late AnimationController _overlayCtrl;
  late Animation<double>   _overlayAnim;

  String get _avatarGender => ref.watch(buddyAvatarGenderProvider);

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _overlayCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 380));
    _overlayAnim = CurvedAnimation(
        parent: _overlayCtrl, curve: Curves.easeOutCubic);
    VoiceService.instance.init();
    _loadHistory();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _overlayCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  // ── Welcome message ───────────────────────────────────────────────────────
  String get _welcomeMsg {
    final firstName =
        ref.read(appStateProvider).user?.name?.split(' ').first ?? 'there';
    final obligations = ref.read(activeObligationsProvider);
    if (obligations.isEmpty) {
      return 'Hey $firstName. Nothing is on my radar yet. '
          'Tell me what is on your mind and I will get to work.';
    }
    return 'Hey $firstName. I can see ${obligations.length} active item'
        '${obligations.length == 1 ? '' : 's'} on your radar. '
        'Tell me what is on your mind and I will get to work.';
  }

  // ── History persistence ───────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final prefs  = await SharedPreferences.getInstance();
    final today  = DateTime.now().toIso8601String().substring(0, 10);
    final stored = prefs.getString(_kChatDate);

    if (stored == today) {
      final raw = prefs.getStringList(_kChatMessages) ?? [];
      if (raw.isNotEmpty) {
        final msgs = raw.map((s) {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return ChatMessageModel(
            id: m['id'] as String, role: m['role'] as String,
            content: m['content'] as String,
            timestamp: DateTime.parse(m['ts'] as String),
          );
        }).toList();
        if (mounted) {
          setState(() { _messages..clear()..addAll(msgs); });
          _scrollToBottom();
        }
        return;
      }
    } else {
      await prefs.remove(_kChatMessages);
      await prefs.setString(_kChatDate, today);
    }
    if (mounted) setState(() {
      _messages.clear();
      _messages.add(ChatMessageModel.assistant(_welcomeMsg));
    });
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kChatDate, DateTime.now().toIso8601String().substring(0, 10));
    await prefs.setStringList(_kChatMessages, _messages.map((m) =>
        jsonEncode({'id': m.id, 'role': m.role,
                    'content': m.content, 'ts': m.timestamp.toIso8601String()})
    ).toList());
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kChatMessages);
    await prefs.setString(
        _kChatDate, DateTime.now().toIso8601String().substring(0, 10));
    if (mounted) setState(() {
      _messages.clear();
      _messages.add(ChatMessageModel.assistant(_welcomeMsg));
    });
    _saveHistory();
  }

  // ── Voice ─────────────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) { await _stopRecording(); return; }
    setState(() { _isRecording = true; _partialText = ''; });
    _overlayCtrl.forward(from: 0);
    await VoiceService.instance.startListening(
      (text) {
        if (!mounted) return;
        _overlayCtrl.reverse().then((_) {
          if (!mounted) return;
          setState(() { _isRecording = false; _partialText = ''; });
          if (text.trim().isNotEmpty) _sendMessage(text);
        });
      },
      (state) {
        if ((state == 'idle' || state == 'error') && mounted) {
          _overlayCtrl.reverse().then((_) {
            if (mounted) setState(() { _isRecording = false; _partialText = ''; });
          });
        }
      },
      onPartial: (p) { if (mounted) setState(() => _partialText = p); },
    );
  }

  Future<void> _stopRecording() async {
    _overlayCtrl.reverse().then((_) {
      if (mounted) setState(() { _isRecording = false; _partialText = ''; });
    });
    await VoiceService.instance.stopListening();
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final file    = _attachedFile;
    final hasFile = file != null;
    if (text.trim().isEmpty && !hasFile) return;
    _textCtrl.clear();

    final displayText = text.trim().isNotEmpty
        ? (hasFile ? '$text\n📎 ${file.name}' : text)
        : '📎 ${file!.name}';
    final aiMessage = hasFile
        ? '${text.trim().isNotEmpty ? text : 'I have uploaded a file.'}'
          '\n\n[Attached: "${file.name}" (${(file.extension ?? 'file').toUpperCase()})]'
        : text;

    setState(() {
      _messages.add(ChatMessageModel.user(displayText));
      _isProcessing = true;
      _attachedFile = null;
    });
    _scrollToBottom();

    try {
      final obligations = ref.read(activeObligationsProvider);
      String response;

      if (file?.bytes != null) {
        // File attachments: always use AiService (vision-capable)
        response = await AiService.instance.completeWithFile(
          systemPrompt: _buildSystemPrompt(obligations),
          userMessage: aiMessage,
          fileBytes: file!.bytes!,
          mimeType: _mimeType(file.extension),
          maxTokens: 1500,
        );
      } else {
        // Text messages: try Buddy API first, fall back to AiService
        response = await _sendViaBuddyApi(aiMessage)
            ?? await AiService.instance.complete(
                 systemPrompt: _buildSystemPrompt(obligations),
                 userMessage:  aiMessage,
                 maxTokens:    600,
               );
      }

      setState(() {
        _messages.add(ChatMessageModel.assistant(response));
        _isProcessing = false;
      });
      _saveHistory();
      _scrollToBottom();
      setState(() => _isSpeaking = true);
      await VoiceService.instance.speak(response);
      if (mounted) setState(() => _isSpeaking = false);
    } catch (e) {
      final errMsg = hasFile
          ? "I couldn't analyse that file right now. Image and PDF analysis "
            "requires Claude or Gemini. For plain text files, Groq works fine. "
            "Please try again in a moment."
          : "Sorry, I couldn't process that right now. Please check your "
            "connection and try again.";
      setState(() {
        _messages.add(ChatMessageModel.assistant(errMsg));
        _isProcessing = false;
      });
    }
  }

  /// Sends the message to the Wyle backend (/v1/chat/messages).
  /// Returns the assistant reply string, or null if the call fails
  /// (in which case the caller falls back to AiService).
  /// Handles both task creation (suggested_actions) and task completion
  /// (completed_action_item_ids from backend, or client-side intent detection).
  Future<String?> _sendViaBuddyApi(String content) async {
    // ── Client-side completion intent detection (works even without backend
    //    support — acts as a reliable fallback).
    final obligations = ref.read(appStateProvider).obligations;
    final clientMatch = _hasCompletionIntent(content)
        ? _findObligationInUtterance(content, obligations)
        : null;

    try {
      final convId = ref.read(appStateProvider).activeConversationId;
      final apiResp = await BuddyApiService.instance.sendMessage(
        content:        content,
        conversationId: convId,
      );

      // Persist the conversation id so follow-up messages stay in the same thread
      if (apiResp.conversationId != convId) {
        await ref.read(appStateProvider.notifier)
            .setActiveConversation(apiResp.conversationId);
      }

      // ── Backend-assisted completion (highest accuracy) ────────────────────
      if (apiResp.completedActionItemIds.isNotEmpty) {
        _processCompletedByBackend(apiResp.completedActionItemIds);
      } else if (clientMatch != null) {
        // ── Client-side fallback ──────────────────────────────────────────
        _markObligationDone(clientMatch);
      }

      // ── Auto-create tasks from suggested_actions ──────────────────────────
      if (apiResp.suggestedActions.isNotEmpty) {
        _processSuggestedActions(apiResp);
      }

      return apiResp.assistantContent;
    } catch (_) {
      // API unavailable — still apply client-side completion if detected,
      // then fall back to AiService for the response.
      if (clientMatch != null) _markObligationDone(clientMatch);
      return null;
    }
  }

  /// Marks obligations that the backend explicitly identified as completed.
  /// Matches by the stable `buddy_action_{id}` ID pattern.
  /// Also persists status to the API so the change survives a re-login.
  void _processCompletedByBackend(List<int> ids) {
    final allObs = ref.read(appStateProvider).obligations;
    int count = 0;
    for (final backendId in ids) {
      final ob = allObs.cast<ObligationModel?>().firstWhere(
        (o) => o!.id == 'buddy_action_$backendId',
        orElse: () => null,
      );
      if (ob != null) {
        ref.read(appStateProvider.notifier).resolveObligation(ob.id);
        // Persist to backend — fire-and-forget, ignore errors (local state is source of truth for UX)
        BuddyApiService.instance.markActionItemDone(backendId).catchError((_) {});
        count++;
      }
    }
    if (count > 0 && mounted) _showCompletionSnackbar(count);
  }

  /// Marks a single obligation as done and shows a confirmation toast.
  /// Also persists status to the API so the change survives a re-login.
  void _markObligationDone(ObligationModel ob) {
    ref.read(appStateProvider.notifier).resolveObligation(ob.id);
    // Extract the numeric backend ID from the stable 'buddy_action_{id}' format
    // and persist the completion to the API.
    if (ob.id.startsWith('buddy_action_')) {
      final backendId = int.tryParse(ob.id.replaceFirst('buddy_action_', ''));
      if (backendId != null) {
        BuddyApiService.instance.markActionItemDone(backendId).catchError((_) {});
      }
    }
    if (mounted) _showCompletionSnackbar(1, title: ob.title);
  }

  void _showCompletionSnackbar(int count, {String? title}) {
    final label = title != null
        ? '✓  "${title}" marked as done'
        : '✓  $count task${count == 1 ? '' : 's'} marked as done';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F3D35),
        behavior:        SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 80, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _verdigris, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _white,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Converts each SuggestedAction in the API response into an ObligationModel
  /// and adds them to the global obligations list.  Deduplication is handled
  /// by addObligations (it skips items whose IDs already exist).
  void _processSuggestedActions(ChatApiResponse resp) {
    final toAdd = <ObligationModel>[];

    for (int i = 0; i < resp.suggestedActions.length; i++) {
      final action = resp.suggestedActions[i];
      if (action.title.isEmpty) continue;

      // Stable ID — uses the backend-persisted ID when available
      final persistedId = i < resp.persistedActionItemIds.length
          ? resp.persistedActionItemIds[i]
          : null;
      final id = persistedId != null
          ? 'buddy_action_$persistedId'
          : 'buddy_${DateTime.now().millisecondsSinceEpoch}_$i';

      // Calculate daysUntil and build a human-readable "starts at" note
      int daysUntil = 1;
      String? noteText;
      if (action.startsAt != null) {
        try {
          final start = DateTime.parse(action.startsAt!).toLocal();
          daysUntil = start.difference(DateTime.now()).inDays;
          final h    = start.hour % 12 == 0 ? 12 : start.hour % 12;
          final min  = start.minute.toString().padLeft(2, '0');
          final ampm = start.hour < 12 ? 'AM' : 'PM';
          const months = [
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec',
          ];
          final day = daysUntil == 0 ? 'Today'
                    : daysUntil == 1 ? 'Tomorrow'
                    : '${months[start.month - 1]} ${start.day}';
          noteText = '$day at $h:$min $ampm';
        } catch (_) {}
      }

      final risk = daysUntil <= 0 ? 'high'
                 : daysUntil < 7  ? 'high'
                 : daysUntil < 30 ? 'medium'
                 : 'low';

      // Emoji: 📅 for events, ✅ for tasks
      final emoji = action.kind == 'event' ? '📅' : '✅';

      toAdd.add(ObligationModel(
        id:            id,
        emoji:         emoji,
        title:         action.title,
        type:          'custom',
        daysUntil:     daysUntil,
        risk:          risk,
        status:        'active',
        executionPath: 'Scheduled by Buddy',
        notes:         noteText,
        source:        'buddy',
      ));
    }

    if (toAdd.isEmpty) return;

    // addObligations skips IDs that already exist — safe to call repeatedly
    ref.read(appStateProvider.notifier).addObligations(toAdd);

    // Brief teal toast confirming how many tasks were added
    if (mounted) {
      final count = toAdd.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F3D35),
          behavior:        SnackBarBehavior.floating,
          // Right margin keeps the snackbar clear of the Tasks FAB
          margin: const EdgeInsets.fromLTRB(16, 0, 80, 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: _verdigris, size: 16),
              const SizedBox(width: 8),
              Text(
                '${count == 1 ? '1 task' : '$count tasks'} added to your list',
                style: GoogleFonts.inter(
                    fontSize: 13, color: _white,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _buildSystemPrompt(List<ObligationModel> obligations) {
    final obList = obligations.take(8).map((o) =>
        '• ${o.emoji} ${o.title} (${o.risk} risk, ${o.daysUntil}d until due, '
        'path: ${o.executionPath})').join('\n');
    return '''You are Wyle Buddy, an AI digital chief of staff for UAE professionals.
You help manage obligations, deadlines, and life admin tasks.
Be concise, practical, and friendly. Use short paragraphs.

IMPORTANT — response rules:
- Answer ONLY what the user asked. Do NOT append task reminders or steering sentences unless the user explicitly asks.
- If the user asks a general question, give a direct answer and stop.
- Only bring up obligations when the user asks about tasks or schedule.

Active obligations (use only when relevant):
$obList

Total active: ${obligations.length}
Currency: AED. Context: Dubai, UAE.''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.any, allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _attachedFile = result.files.first);
      }
    } catch (_) {}
  }

  String _mimeType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png':              return 'image/png';
      case 'pdf':              return 'application/pdf';
      case 'txt': case 'md':   return 'text/plain';
      case 'csv':              return 'text/csv';
      default:                 return 'application/octet-stream';
    }
  }

  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return Icons.image_outlined;
      case 'pdf':   return Icons.picture_as_pdf_outlined;
      case 'doc': case 'docx': return Icons.description_outlined;
      case 'xls': case 'xlsx': case 'csv': return Icons.table_chart_outlined;
      default:      return Icons.attach_file_rounded;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final obligations = ref.watch(activeObligationsProvider);
    final urgentOb = obligations.isNotEmpty ? obligations[0] : null;

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
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  // Alert card for most urgent obligation
                  if (urgentOb != null && !_alertDismissed &&
                      urgentOb.daysUntil <= 1)
                    _buildAlertCard(urgentOb),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildMessageList(),
                        // Right-side FABs
                        _buildRightFabs(context, obligations),
                      ],
                    ),
                  ),
                  _buildNowPlayingBar(),
                  _buildAttachmentPreview(),
                  _buildInputBar(),
                ],
              ),
              // Voice overlay
              if (_isRecording)
                FadeTransition(
                  opacity: _overlayAnim,
                  child: _VoiceRecordingOverlay(
                    partialText: _partialText,
                    onStop: _stopRecording,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        children: [
          // WYLE logo
          Image.asset(
            'assets/logos/wyle_logo_white.png',
            height: 36,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          // Clear chat
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                backgroundColor: const Color(0xFF1A2E2B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text('Clear chat?',
                    style: GoogleFonts.poppins(
                        color: _white, fontWeight: FontWeight.w600)),
                content: Text('This will remove all messages for today.',
                    style: GoogleFonts.inter(color: _textSec, fontSize: 13)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(color: _textSec)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      _clearHistory();
                    },
                    child: Text('Clear',
                        style: GoogleFonts.inter(
                            color: _crimson, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            child: Container(
              width: 38, height: 38,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _surfaceEl,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _textSec, size: 18),
            ),
          ),
          // Profile avatar — navigates to Profile screen
          GestureDetector(
            onTap: () => context.go(AppRoutes.connect),
            child: _BuddyAvatar(gender: _avatarGender, size: 40),
          ),
        ],
      ),
    );
  }

  // ── Alert card ────────────────────────────────────────────────────────────
  Widget _buildAlertCard(ObligationModel ob) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _alertBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _crimson.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _crimson, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ob.emoji} ${ob.title} — due TODAY!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _alertDismissed = true),
                child: const Icon(Icons.close_rounded,
                    color: _textSec, size: 18),
              ),
            ],
          ),
          if (ob.notes != null) ...[
            const SizedBox(height: 6),
            Text(ob.notes!,
                style: GoogleFonts.inter(fontSize: 12, color: _textSec),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showTasksBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _crimson,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('View Task',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    final hasUserMessages = _messages.any((m) => m.role == 'user');

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 72, 12),
      itemCount: _messages.length + (_isProcessing ? 1 : 0) +
          (!hasUserMessages ? 1 : 0),
      itemBuilder: (context, index) {
        // Voice dump pill at end when no user messages yet
        if (!hasUserMessages && index == _messages.length) {
          return _buildVoiceDumpPill();
        }
        if (_isProcessing && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _BuddyAvatar(gender: _avatarGender, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isUser
                    ? _verdigris
                    : const Color(0xFF0F3D35),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null
                    : Border.all(color: _verdigris.withOpacity(0.3)),
              ),
              child: Text(msg.content,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: _white, height: 1.55)),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _BuddyAvatar(gender: _avatarGender, size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3D35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _verdigris.withOpacity(0.3)),
            ),
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final t = ((_waveCtrl.value + i * 0.33) % 1.0);
                  return Container(
                    width: 7, height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _verdigris.withOpacity(0.4 + t * 0.6),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Or start with a voice dump" pill shown when chat is fresh
  Widget _buildVoiceDumpPill() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceEl,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _verdigris.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_rounded, color: _verdigris, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Or start with a voice dump',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _verdigris,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Right FABs ────────────────────────────────────────────────────────────
  Widget _buildRightFabs(
      BuildContext context, List<ObligationModel> obligations) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: Column(
        children: [
          // ── Tasks FAB — green gradient + badge ─────────────────────────
          GestureDetector(
            onTap: () => _showTasksBottomSheet(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B998B), Color(0xFF52C878), Color(0xFFA8FF3E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B998B).withOpacity(0.45),
                        blurRadius: 14, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.checklist_rounded,
                      color: _white, size: 24),
                ),
                if (obligations.isNotEmpty)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                        color: _crimson, shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${obligations.length > 9 ? '9+' : obligations.length}',
                          style: GoogleFonts.inter(
                              color: _white, fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── History FAB — navigates to full Session History screen ────────
          GestureDetector(
            onTap: () => context.push(AppRoutes.sessionHistory),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A18),
                shape: BoxShape.circle,
                border: Border.all(color: _verdigris.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _verdigris.withOpacity(0.2),
                    blurRadius: 8, spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.history_rounded,
                  color: _verdigris.withOpacity(0.9), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tasks bottom sheet ────────────────────────────────────────────────────
  void _showTasksBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // No obligations param — sheet watches activeObligationsProvider directly
      builder: (_) => const _TasksBottomSheet(),
    );
  }

  // ── Now playing bar ───────────────────────────────────────────────────────
  Widget _buildNowPlayingBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: _isSpeaking ? 60 : 0,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          height: 60,
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2420),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _verdigris.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              _buildMiniWaveform(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buddy is reading',
                        style: GoogleFonts.inter(
                            color: _white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('Tap ■ to stop',
                        style: GoogleFonts.inter(
                            color: _textSec, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await VoiceService.instance.stopSpeaking();
                  if (mounted) setState(() => _isSpeaking = false);
                },
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: _verdigris.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _verdigris.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.stop_rounded,
                      color: _verdigris, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniWaveform() {
    const heights = [6.0, 12.0, 16.0, 12.0, 6.0];
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (i) {
          final phase = (_waveCtrl.value + i * 0.22) % 1.0;
          final h = heights[i] * (0.35 + phase * 0.65);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 3, height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _verdigris,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ── Attachment preview ────────────────────────────────────────────────────
  Widget _buildAttachmentPreview() {
    final file = _attachedFile;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: file != null ? 50 : 0,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          height: 50,
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surfaceEl,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _verdigris.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              Icon(_fileIcon(file?.extension), color: _verdigris, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(file?.name ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: _white, fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              Text((file?.extension ?? '').toUpperCase(),
                  style: GoogleFonts.inter(
                      color: _textSec, fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _attachedFile = null),
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                      color: _border, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: _textSec, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F2420),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _verdigris.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Attach button
            GestureDetector(
              onTap: _pickAttachment,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(
                  _attachedFile != null
                      ? Icons.attach_file_rounded
                      : Icons.add_rounded,
                  color: _attachedFile != null
                      ? _verdigris
                      : const Color(0xFFCB9A2D), // amber, matches Figma
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: GoogleFonts.inter(color: _white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _attachedFile != null
                      ? 'Ask about this file…'
                      : 'Tell Buddy anything.',
                  hintStyle: GoogleFonts.inter(
                      color: _textTer, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 14),
                ),
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
              ),
            ),
            // Send button (only shows when typing)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textCtrl,
              builder: (_, v, __) => v.text.trim().isNotEmpty
                  ? GestureDetector(
                      onTap: () => _sendMessage(_textCtrl.text),
                      child: Container(
                        width: 36, height: 36,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: _verdigris,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: _white, size: 16),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Mic button
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? _crimson.withOpacity(0.9)
                      : _verdigris,
                  boxShadow: _isRecording
                      ? [BoxShadow(color: _crimson.withOpacity(0.4),
                              blurRadius: 12)]
                      : [BoxShadow(color: _verdigris.withOpacity(0.3),
                              blurRadius: 8)],
                ),
                child: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none_rounded,
                  color: _white, size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buddy Avatar Widget — male / female
// Uses real 3D avatar images from assets/avatars/
// ─────────────────────────────────────────────────────────────────────────────
class _BuddyAvatar extends StatelessWidget {
  final String gender; // 'male' or 'female'
  final double size;

  const _BuddyAvatar({required this.gender, required this.size});

  @override
  Widget build(BuildContext context) {
    final isMale = gender != 'female';
    final assetPath = isMale
        ? 'assets/avatars/buddy_male.png'
        : 'assets/avatars/buddy_female.png';
    final glowColor = isMale
        ? const Color(0xFF1B998B)
        : const Color(0xFFE91E8C);

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.35),
            blurRadius: size * 0.4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.asset(
          assetPath,
          width: size, height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackAvatar(
            size: size, isMale: isMale,
          ),
        ),
      ),
    );
  }
}

// Fallback gradient circle if asset fails to load
class _FallbackAvatar extends StatelessWidget {
  final double size;
  final bool isMale;
  const _FallbackAvatar({required this.size, required this.isMale});

  @override
  Widget build(BuildContext context) {
    final color1 = isMale ? const Color(0xFF1B998B) : const Color(0xFFE91E8C);
    final color2 = isMale ? const Color(0xFF0A4A44) : const Color(0xFF7B1FA2);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
      ),
      child: Icon(
        isMale ? Icons.person_rounded : Icons.person_outline_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice Recording Overlay
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceRecordingOverlay extends StatefulWidget {
  final String       partialText;
  final VoidCallback onStop;
  const _VoiceRecordingOverlay(
      {required this.partialText, required this.onStop});
  @override
  State<_VoiceRecordingOverlay> createState() =>
      _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<_VoiceRecordingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _rippleCtrl;
  late AnimationController _orbCtrl;
  List<double> _barHeights = List.filled(9, 8.0);
  Timer? _waveTimer;
  final _rand = Random();
  static const _basePeaks = [
    10.0, 16.0, 24.0, 34.0, 44.0, 34.0, 24.0, 16.0, 10.0
  ];

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _waveTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) {
        setState(() {
          _barHeights = List.generate(
              9, (i) => _basePeaks[i] * (0.25 + _rand.nextDouble() * 0.75));
        });
      }
    });
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _orbCtrl.dispose();
    _waveTimer?.cancel();
    super.dispose();
  }

  Widget _rippleRing(double phase, double maxExp, double maxOpacity, double sw) {
    return AnimatedBuilder(
      animation: _rippleCtrl,
      builder: (_, __) {
        final t = (_rippleCtrl.value + phase) % 1.0;
        return Container(
          width: 96 + t * maxExp, height: 96 + t * maxExp,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _verdigris.withOpacity((1.0 - t) * maxOpacity),
              width: sw,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        color: Colors.black.withOpacity(0.90),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text('BUDDY IS LISTENING',
                  style: GoogleFonts.inter(
                      color: _verdigris.withOpacity(0.7),
                      fontSize: 11, fontWeight: FontWeight.w600,
                      letterSpacing: 3.0)),
              const Spacer(),
              SizedBox(
                width: 260, height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    _rippleRing(0.66, 100, 0.20, 1.0),
                    _rippleRing(0.33, 100, 0.40, 1.5),
                    _rippleRing(0.00, 100, 0.65, 2.0),
                    AnimatedBuilder(
                      animation: _orbCtrl,
                      builder: (_, __) => Container(
                        width: 108, height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: _verdigris
                                .withOpacity(0.28 + _orbCtrl.value * 0.22),
                            blurRadius: 48, spreadRadius: 12,
                          )],
                        ),
                      ),
                    ),
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          const Color(0xFF22BBA8), _verdigris,
                          const Color(0xFF0A4A44), const Color(0xFF041A18),
                        ], stops: const [0.0, 0.35, 0.72, 1.0]),
                        boxShadow: [BoxShadow(
                            color: _verdigris.withOpacity(0.55),
                            blurRadius: 28, spreadRadius: 4)],
                      ),
                      child: const Icon(Icons.mic_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(9, (i) {
                  final isCenter = i == 4;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      width: isCenter ? 5 : 4,
                      height: _barHeights[i],
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isCenter
                              ? [_verdigris, const Color(0xFFD5FF3F)]
                              : [_verdigris.withOpacity(0.4), _verdigris],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 36),
              AnimatedOpacity(
                opacity: widget.partialText.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    widget.partialText.isNotEmpty
                        ? '"${widget.partialText}"'
                        : '',
                    textAlign: TextAlign.center,
                    // No maxLines / no ellipsis — show the full transcript
                    style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 14, fontStyle: FontStyle.italic,
                        height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BlinkingDot(),
                  const SizedBox(width: 8),
                  Text('Listening',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.8)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Auto-stops after 3 s of silence',
                  style: GoogleFonts.inter(
                      color: Colors.white24, fontSize: 11,
                      letterSpacing: 0.3)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onStop,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 48),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white24, width: 1),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: _crimson,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Stop recording',
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _crimson.withOpacity(_fade.value),
          boxShadow: [BoxShadow(
              color: _crimson.withOpacity(_fade.value * 0.6),
              blurRadius: 6, spreadRadius: 1)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tasks Bottom Sheet — Tasks + Insights tabs, urgent + active groups
// ─────────────────────────────────────────────────────────────────────────────
class _TasksBottomSheet extends ConsumerStatefulWidget {
  // No constructor param needed — reads live from activeObligationsProvider
  const _TasksBottomSheet();

  @override
  ConsumerState<_TasksBottomSheet> createState() => _TasksBottomSheetState();
}

class _TasksBottomSheetState extends ConsumerState<_TasksBottomSheet> {
  int _tab = 0; // 0 = Tasks, 1 = Insights

  // ── Insights state ──────────────────────────────────────────────────────────
  InsightsSummaryModel? _insights;
  bool   _insightsLoading    = false;
  bool   _insightsComingSoon = false;   // true when backend returns 404
  String? _insightsError;

  @override
  Widget build(BuildContext context) {
    // Watch the same provider the FAB badge uses — both counts are always in sync
    final obligations = ref.watch(activeObligationsProvider);

    final urgent = obligations
        .where((o) => o.daysUntil <= 0 || o.risk == 'high')
        .toList();
    final active = obligations
        .where((o) => !(o.daysUntil <= 0 || o.risk == 'high'))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF071512),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ───────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A3E3B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Tab row ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Tasks tab
                GestureDetector(
                  onTap: () => setState(() => _tab = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _tab == 0
                          ? const Color(0xFF0F3A30)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _tab == 0
                            ? _verdigris.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('Tasks',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _tab == 0 ? _verdigris : _textSec)),
                        if (obligations.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: _crimson, shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${obligations.length > 9 ? '9+' : obligations.length}',
                                style: GoogleFonts.inter(
                                    color: _white, fontSize: 9,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Insights tab
                GestureDetector(
                  onTap: () {
                    setState(() => _tab = 1);
                    if (_insights == null && !_insightsLoading) {
                      _fetchInsights();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _tab == 1
                          ? const Color(0xFF1A2E0A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _tab == 1
                            ? const Color(0xFFD5FF3F).withOpacity(0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text('Insights',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _tab == 1
                                ? const Color(0xFFD5FF3F)
                                : _textSec)),
                  ),
                ),
                const Spacer(),
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
          const SizedBox(height: 16),

          // ── Content ───────────────────────────────────────────────────────
          if (_tab == 0)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (urgent.isNotEmpty) ...[
                    _sectionHeader(
                      icon: Icons.error_outline_rounded,
                      label: 'URGENT - NEXT 2 HOURS',
                      color: const Color(0xFFFF5252),
                    ),
                    const SizedBox(height: 10),
                    ...urgent.map((o) => _taskCard(o, isUrgent: true)),
                    const SizedBox(height: 16),
                  ],
                  if (active.isNotEmpty) ...[
                    _sectionHeader(
                      icon: Icons.access_time_rounded,
                      label: 'ACTIVE TASKS',
                      color: _verdigris,
                    ),
                    const SizedBox(height: 10),
                    ...active.map((o) => _taskCard(o, isUrgent: false)),
                  ],
                  if (obligations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No active tasks at the moment.\n'
                          'You are all caught up.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: _textSec,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Flexible(child: _buildInsightsTab()),
        ],
      ),
    );
  }

  // ── Fetch insights from API ─────────────────────────────────────────────────
  Future<void> _fetchInsights() async {
    setState(() {
      _insightsLoading    = true;
      _insightsError      = null;
      _insightsComingSoon = false;
    });
    try {
      final data = await BuddyApiService.instance.getInsightsSummary();
      if (mounted) setState(() { _insights = data; _insightsLoading = false; });
    } catch (e) {
      if (!mounted) return;
      // 404 → endpoint not yet live on the backend
      final is404 = e is DioException &&
          e.response?.statusCode == 404;
      setState(() {
        _insightsLoading    = false;
        _insightsComingSoon = is404;
        _insightsError      = is404 ? null : 'Could not load insights.\nTap to retry.';
      });
    }
  }

  // ── Insights tab UI ─────────────────────────────────────────────────────────
  Widget _buildInsightsTab() {
    if (_insightsComingSoon) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A1A),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFD5FF3F).withOpacity(0.3)),
                ),
                child: const Center(
                  child: Text('🚀', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Insights Coming Soon',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Your productivity stats will appear\nhere once the feature goes live.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: _textSec, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    if (_insightsLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD5FF3F), strokeWidth: 2.5),
        ),
      );
    }
    if (_insightsError != null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: GestureDetector(
            onTap: _fetchInsights,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: _textSec, size: 40),
                const SizedBox(height: 12),
                Text(_insightsError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: _textSec, fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A2A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Retry',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFFD5FF3F),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final d = _insights;
    if (d == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // ── Life Operating Score ──────────────────────────────────────────
        _insightScoreCard(d.productivityScore),
        const SizedBox(height: 14),

        // ── 2×2 stat grid ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _statTile(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFD5A820),
              value: d.hoursSavedEstimate % 1 == 0
                  ? '${d.hoursSavedEstimate.toInt()} hours'
                  : '${d.hoursSavedEstimate.toStringAsFixed(1)} hours',
              label: 'Time Saved',
            )),
            const SizedBox(width: 12),
            Expanded(child: _statTile(
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF1B998B),
              value: '${d.tasksDone}',
              label: 'Tasks Done',
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statTile(
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFFD5A820),
              value: '${d.meetingsCount}',
              label: 'Meetings',
            )),
            const SizedBox(width: 12),
            Expanded(child: _statTile(
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF1B998B),
              value: '${d.messagesCount}',
              label: 'Messages',
            )),
          ],
        ),
        const SizedBox(height: 14),

        // ── Weekly Pattern ────────────────────────────────────────────────
        if (d.weeklyPattern.insightText.isNotEmpty)
          _weeklyPatternCard(d.weeklyPattern),
      ],
    );
  }

  Widget _insightScoreCard(int score) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFD5FF3F).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Life Operating Score',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _white)),
                const SizedBox(height: 6),
                Text(
                  _scoreSubtitle(score),
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF7AACB8),
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 62, height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFD5FF3F),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$score',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF001A0A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scoreSubtitle(int score) {
    if (score >= 85) return 'Excellent! Keep up the great work.';
    if (score >= 70) return 'Your productivity is on a strong track.';
    if (score >= 50) return 'Good progress — a few more wins await.';
    return 'Let\'s work on improving your productivity.';
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2218),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A3A28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _white)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF7AACB8))),
        ],
      ),
    );
  }

  Widget _weeklyPatternCard(WeeklyPatternData pattern) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A3A28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: Color(0xFF1B998B), size: 16),
              const SizedBox(width: 7),
              Text('Weekly Pattern',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _white)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pattern.insightText,
            style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF7AACB8),
                height: 1.55),
          ),
          if (pattern.bestDays.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: pattern.bestDays.map((day) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5FF3F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFD5FF3F).withOpacity(0.3)),
                ),
                child: Text(day,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD5FF3F))),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 7),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.0)),
      ],
    );
  }

  Widget _taskCard(ObligationModel o, {required bool isUrgent}) {
    final borderColor = isUrgent
        ? const Color(0xFFFF5252).withOpacity(0.5)
        : _verdigris.withOpacity(0.35);
    final timeColor =
        isUrgent ? const Color(0xFFFF9800) : _verdigris;
    final actionIcon = o.executionPath == 'auto'
        ? Icons.bolt_rounded
        : Icons.access_time_rounded;
    final timeText = o.daysUntil == 0
        ? 'Due today'
        : o.daysUntil < 0
            ? 'Overdue'
            : '${o.daysUntil}d';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1F1C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            // ── Task info ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${o.emoji} ${o.title}',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _white)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: timeColor, size: 12),
                      const SizedBox(width: 4),
                      Text(timeText,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: timeColor,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Status icon ────────────────────────────────────────────────
            Icon(actionIcon, color: timeColor, size: 18),
            const SizedBox(width: 4),

            // ── Delete button ──────────────────────────────────────────────
            GestureDetector(
              onTap: () => _confirmDeleteTask(o),
              child: Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: _crimson.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _crimson.withOpacity(0.25)),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: _crimson.withOpacity(0.8), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation dialog ─────────────────────────────────────────────
  void _confirmDeleteTask(ObligationModel o) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1E2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _crimson.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _crimson.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ───────────────────────────────────────────────────────
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _crimson.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _crimson.withOpacity(0.3)),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: _crimson, size: 26),
              ),
              const SizedBox(height: 16),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                'Delete Task?',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _white,
                ),
              ),
              const SizedBox(height: 8),

              // ── Task name preview ─────────────────────────────────────────
              Text(
                '"${o.emoji} ${o.title}"',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF7AACB8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This will permanently remove the task.\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF5A7A78),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── Buttons ───────────────────────────────────────────────────
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3A4A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Center(
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _deleteTask(o);
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _crimson.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _crimson.withOpacity(0.5)),
                        ),
                        child: Center(
                          child: Text('Delete',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _crimson,
                              )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Perform delete ─────────────────────────────────────────────────────────
  void _deleteTask(ObligationModel o) {
    // 1. Remove from local state immediately (optimistic update)
    ref.read(appStateProvider.notifier).removeObligation(o.id);

    // 2. Call backend API if this is a backend-persisted task
    if (o.id.startsWith('buddy_action_')) {
      final backendId =
          int.tryParse(o.id.replaceFirst('buddy_action_', ''));
      if (backendId != null) {
        BuddyApiService.instance
            .deleteActionItem(backendId)
            .catchError((_) {});
      }
    }
  }
}
