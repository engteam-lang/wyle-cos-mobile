import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/chat_message_model.dart';
import '../../models/obligation_model.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../services/voice_service.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
const _bgTop      = Color(0xFF0B1F1C);
const _bgBot      = Color(0xFF0D0D0D);
const _surface    = Color(0xFF0F2420);
const _surfaceEl  = Color(0xFF1A2E2B);
const _border     = Color(0xFF1F3A36);
const _verdigris  = Color(0xFF1B998B);
const _crimson    = Color(0xFFFF3B30);
const _white      = Color(0xFFFFFFFF);
const _textSec    = Color(0xFF9A9A9A);
const _textTer    = Color(0xFF4A4A4A);
const _alertBg    = Color(0xFF1A0808);

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

  // ── Gender for avatar ─────────────────────────────────────────────────────
  // 'male' or 'female' — reads from user profile; defaults to male
  String get _avatarGender {
    final name = ref.read(appStateProvider).user?.name?.toLowerCase() ?? '';
    // Simple heuristic: can be extended with a profile setting
    return name.contains('she') || name.contains('her') ? 'female' : 'male';
  }

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
      final String response;
      if (file?.bytes != null) {
        response = await AiService.instance.completeWithFile(
          systemPrompt: _buildSystemPrompt(obligations),
          userMessage: aiMessage,
          fileBytes: file!.bytes!,
          mimeType: _mimeType(file.extension),
          maxTokens: 1500,
        );
      } else {
        response = await AiService.instance.complete(
          systemPrompt: _buildSystemPrompt(obligations),
          userMessage: aiMessage,
          maxTokens: 600,
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
            colors: [_bgTop, _bgBot],
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
          Text(
            'WYLE',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _white,
              letterSpacing: 1.5,
            ),
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
          // Profile avatar — navigates to Settings/Profile screen
          GestureDetector(
            onTap: () => context.push(AppRoutes.settings),
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
            onTap: () => context.go(AppRoutes.obligations),
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
          // Tasks FAB with badge
          GestureDetector(
            onTap: () => context.go(AppRoutes.obligations),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: _verdigris,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _verdigris.withOpacity(0.4),
                        blurRadius: 12, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.format_list_bulleted_rounded,
                      color: _white, size: 22),
                ),
                if (obligations.isNotEmpty)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _crimson, shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${obligations.length > 9 ? '9+' : obligations.length}',
                        style: GoogleFonts.inter(
                            color: _white, fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // History / back FAB
          GestureDetector(
            onTap: () => context.go(AppRoutes.home),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _surfaceEl,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.history_rounded, color: _textSec, size: 20),
            ),
          ),
        ],
      ),
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
                  color: _attachedFile != null ? _verdigris : _textSec,
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
              SizedBox(
                height: 56,
                child: AnimatedOpacity(
                  opacity: widget.partialText.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 14, fontStyle: FontStyle.italic,
                          height: 1.5),
                    ),
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
