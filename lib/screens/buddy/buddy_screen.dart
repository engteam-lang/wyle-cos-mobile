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

// ── Palette (local for Buddy screen dark theme) ───────────────────────────────
const _bg         = Color(0xFF0D0D0D);
const _surface    = Color(0xFF161616);
const _surfaceEl  = Color(0xFF1E1E1E);
const _border     = Color(0xFF2A2A2A);
const _verdigris  = Color(0xFF1B998B);
const _chartreuse = Color(0xFFD5FF3F);
const _crimson    = Color(0xFFFF3B30);
const _white      = Color(0xFFFFFFFF);
const _textSec    = Color(0xFF9A9A9A);
const _textTer    = Color(0xFF555555);

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
  static const _welcomeMsg =
      "Hi! I'm Buddy, your AI chief of staff. I can help you manage your obligations, "
      "check your calendar, and take care of tasks. What would you like to do today?";

  final List<ChatMessageModel> _messages    = [];
  final TextEditingController  _textCtrl    = TextEditingController();
  final ScrollController       _scrollCtrl  = ScrollController();

  bool           _isRecording  = false;
  bool           _isProcessing = false;
  bool           _isSpeaking   = false;
  String         _partialText  = '';
  PlatformFile?  _attachedFile;

  late AnimationController _waveCtrl;

  // Entry animation for the overlay
  late AnimationController _overlayCtrl;
  late Animation<double>   _overlayAnim;

  @override
  void initState() {
    super.initState();

    _waveCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..repeat(reverse: true);

    _overlayCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 380));
    _overlayAnim = CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeOutCubic);

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

  // ── Chat history persistence ──────────────────────────────────────────────────

  /// Load today's messages from SharedPreferences.
  /// If stored date differs from today, auto-clears old history.
  Future<void> _loadHistory() async {
    final prefs   = await SharedPreferences.getInstance();
    final today   = DateTime.now().toIso8601String().substring(0, 10);
    final stored  = prefs.getString(_kChatDate);

    if (stored == today) {
      final raw = prefs.getStringList(_kChatMessages) ?? [];
      if (raw.isNotEmpty) {
        final msgs = raw.map((s) {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return ChatMessageModel(
            id:        m['id'] as String,
            role:      m['role'] as String,
            content:   m['content'] as String,
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
      // New day — wipe old history
      await prefs.remove(_kChatMessages);
      await prefs.setString(_kChatDate, today);
    }

    // Fresh session: show welcome message
    if (mounted) setState(() {
      _messages.clear();
      _messages.add(ChatMessageModel.assistant(_welcomeMsg));
    });
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs  = await SharedPreferences.getInstance();
    final today  = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_kChatDate, today);
    final raw = _messages.map((m) => jsonEncode({
      'id':      m.id,
      'role':    m.role,
      'content': m.content,
      'ts':      m.timestamp.toIso8601String(),
    })).toList();
    await prefs.setStringList(_kChatMessages, raw);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kChatMessages);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_kChatDate, today);
    if (mounted) setState(() {
      _messages.clear();
      _messages.add(ChatMessageModel.assistant(_welcomeMsg));
    });
    _saveHistory();
  }

  // ── Recording ────────────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    setState(() {
      _isRecording = true;
      _partialText = '';
    });
    _overlayCtrl.forward(from: 0);

    await VoiceService.instance.startListening(
      // Final recognised text → send message
      (text) {
        if (!mounted) return;
        _overlayCtrl.reverse().then((_) {
          if (!mounted) return;
          setState(() {
            _isRecording = false;
            _partialText = '';
          });
          if (text.trim().isNotEmpty) _sendMessage(text);
        });
      },
      // Status changes (idle / error)
      (state) {
        if ((state == 'idle' || state == 'error') && mounted) {
          _overlayCtrl.reverse().then((_) {
            if (mounted) setState(() {
              _isRecording = false;
              _partialText = '';
            });
          });
        }
      },
      // Live partial transcript shown in overlay
      onPartial: (partial) {
        if (mounted) setState(() => _partialText = partial);
      },
    );
  }

  Future<void> _stopRecording() async {
    _overlayCtrl.reverse().then((_) {
      if (mounted) setState(() {
        _isRecording = false;
        _partialText = '';
      });
    });
    await VoiceService.instance.stopListening();
  }

  // ── Send message ──────────────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final file = _attachedFile;
    final hasFile = file != null;
    if (text.trim().isEmpty && !hasFile) return;
    _textCtrl.clear();

    // What shows in the chat bubble
    final displayText = text.trim().isNotEmpty
        ? (hasFile ? '$text\n📎 ${file.name}' : text)
        : '📎 ${file!.name}';

    // What the AI receives — file name + extension hint so it can reason about it
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
      // If the file has bytes, use the vision/document API; otherwise text-only
      final String response;
      if (file?.bytes != null) {
        response = await AiService.instance.completeWithFile(
          systemPrompt: _buildSystemPrompt(obligations),
          userMessage:  aiMessage,
          fileBytes:    file!.bytes!,
          mimeType:     _mimeType(file.extension),
          maxTokens:    1500,
        );
      } else {
        response = await AiService.instance.complete(
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
          ? "I couldn't analyse that file right now. "
            "Image and PDF analysis requires Claude (credits needed) or Gemini (may be rate-limited). "
            "For plain text files (.txt, .csv), Groq is used and works without credits. "
            "Please try again in a moment."
          : "Sorry, I couldn't process that right now. Please check your connection and try again.";
      setState(() {
        _messages.add(ChatMessageModel.assistant(errMsg));
        _isProcessing = false;
      });
    }
  }

  String _buildSystemPrompt(List<ObligationModel> obligations) {
    final obList = obligations.take(8).map((o) =>
        '• ${o.emoji} ${o.title} (${o.risk} risk, ${o.daysUntil} days until due, path: ${o.executionPath})'
    ).join('\n');

    return '''You are Wyle Buddy, an AI digital chief of staff for UAE professionals.
You help manage obligations, deadlines, and life admin tasks.
Be concise, practical, and friendly. Use short paragraphs.

IMPORTANT — response rules:
- Answer ONLY what the user asked. Do NOT append task reminders, obligation nudges, or steering sentences (e.g. "Shall I guide you…", "Would you like to focus on…", "You still have tasks due…") unless the user explicitly asks about their tasks or schedule.
- If the user asks a general question (definitions, facts, how-to), give a direct, complete answer and stop there.
- Only bring up obligations when the user asks about tasks, deadlines, or their schedule.

Active obligations (use only when user asks about tasks/schedule):
$obList

Total active: ${obligations.length}

When the user does ask about tasks, prioritize high-risk items due soon.
For execution paths, give step-by-step instructions.
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

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main chat UI ──────────────────────────────────────────────────
            Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildMessageList()),
                _buildNowPlayingBar(),
                _buildAttachmentPreview(),
                _buildInputBar(),
              ],
            ),

            // ── Voice recording overlay (fades in on top — no scale to avoid jitter)
            if (_isRecording)
              FadeTransition(
                opacity: _overlayAnim,
                child: _VoiceRecordingOverlay(
                  partialText: _partialText,
                  onStop: _stopRecording,
                ),
              ),

            // Stack has no more overlay buttons — now-playing bar lives in Column
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Buddy orb avatar — static, no scale animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1B998B), Color(0xFFD5FF3F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _verdigris.withOpacity(_isSpeaking ? 0.75 : 0.35),
                  blurRadius: _isSpeaking ? 20 : 10,
                  spreadRadius: _isSpeaking ? 3 : 1,
                ),
              ],
            ),
            child: const Center(
              child: Text('◎', style: TextStyle(fontSize: 20, color: _white)),
            ),
          ),

          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buddy',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
                Row(
                  children: [
                    Container(width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: _verdigris, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      _isRecording    ? 'Listening…'
                      : _isProcessing ? 'Thinking…'
                      : _isSpeaking   ? 'Speaking…'
                      : 'Ready',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _verdigris,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Clear chat button
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                backgroundColor: _surfaceEl,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text('Clear chat?',
                    style: GoogleFonts.poppins(
                        color: _white, fontWeight: FontWeight.w600)),
                content: Text(
                    'This will remove all messages for today.',
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
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _surfaceEl,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _textSec, size: 18),
            ),
          ),

          // Back button (top-right) — Buddy has no bottom nav, so we need this
          GestureDetector(
            onTap: () => context.go(AppRoutes.home),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _surfaceEl,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textSec, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [_verdigris, Color(0xFFD5FF3F)]),
              ),
              child: const Center(
                  child: Text('◎', style: TextStyle(fontSize: 12, color: _white))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isUser ? _verdigris : _surfaceEl,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4  : 16),
                ),
                border: isUser ? null : Border.all(color: _border),
              ),
              child: Text(msg.content,
                style: GoogleFonts.inter(
                    fontSize: 14, color: _white, height: 1.5)),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [_verdigris, Color(0xFFD5FF3F)]),
            ),
            child: const Center(
                child: Text('◎', style: TextStyle(fontSize: 12, color: _white))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceEl,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
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

  // ── File attachment ───────────────────────────────────────────────────────────
  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // read bytes so the AI can actually see the content
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _attachedFile = result.files.first);
      }
    } catch (_) {}
  }

  /// Returns the MIME type for a given file extension.
  String _mimeType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png':              return 'image/png';
      case 'gif':              return 'image/gif';
      case 'webp':             return 'image/webp';
      case 'heic':             return 'image/heic';
      case 'pdf':              return 'application/pdf';
      case 'txt': case 'md':   return 'text/plain';
      case 'csv':              return 'text/csv';
      default:                 return 'application/octet-stream';
    }
  }

  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': case 'heic':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc': case 'docx':
        return Icons.description_outlined;
      case 'xls': case 'xlsx': case 'csv':
        return Icons.table_chart_outlined;
      case 'ppt': case 'pptx':
        return Icons.slideshow_outlined;
      default:
        return Icons.attach_file_rounded;
    }
  }

  // Slides up above the input bar when a file is attached
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
              Icon(_fileIcon(file?.extension),
                  color: _verdigris, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file?.name ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                (file?.extension ?? '').toUpperCase(),
                style: GoogleFonts.inter(
                    color: _textSec, fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _attachedFile = null),
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _border,
                    shape: BoxShape.circle,
                  ),
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

  // ── Now-playing bar (slides in when Buddy is reading TTS) ────────────────────
  Widget _buildNowPlayingBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      // Height animates 0 → 60 — gives a smooth slide-up from the input bar
      height: _isSpeaking ? 60 : 0,
      child: SingleChildScrollView(
        // Prevents overflow while height is still animating to 0
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          height: 60,
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1F1E), // very dark verdigris tint
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _verdigris.withOpacity(0.45), width: 1),
            boxShadow: [
              BoxShadow(
                color: _verdigris.withOpacity(0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),

              // Animated waveform — shows audio is actively playing
              _buildMiniWaveform(),

              const SizedBox(width: 12),

              // Label
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buddy is reading',
                      style: GoogleFonts.inter(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                    Text('Tap ■ to stop',
                      style: GoogleFonts.inter(
                        color: _textSec,
                        fontSize: 11,
                      )),
                  ],
                ),
              ),

              // Stop button
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
                    border: Border.all(
                        color: _verdigris.withOpacity(0.5), width: 1),
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

  // Five animated bars that represent audio playback
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
            width: 3,
            height: h,
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

  // ── Input bar ─────────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // ── Upload / attach button ──────────────────────────────────────────
          GestureDetector(
            onTap: _pickAttachment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _attachedFile != null
                    ? _verdigris.withOpacity(0.18)
                    : _surfaceEl,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _attachedFile != null
                      ? _verdigris.withOpacity(0.6)
                      : _border,
                ),
              ),
              child: Icon(
                _attachedFile != null
                    ? Icons.attach_file_rounded
                    : Icons.add_rounded,
                color: _attachedFile != null ? _verdigris : _textSec,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Text field ──────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceEl,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _textCtrl,
                style: GoogleFonts.inter(color: _white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _attachedFile != null
                      ? 'Ask about this file…'
                      : 'Ask Buddy anything…',
                  hintStyle: GoogleFonts.inter(color: _textTer, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Send button ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _sendMessage(_textCtrl.text),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _verdigris,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.send_rounded, color: _white, size: 18),
            ),
          ),
          const SizedBox(width: 8),

          // ── Mic button ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? _crimson.withOpacity(0.9)
                    : const Color(0xFF252525),
                boxShadow: _isRecording
                    ? [BoxShadow(color: _crimson.withOpacity(0.35),
                            blurRadius: 14, spreadRadius: 1)]
                    : null,
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none_rounded,
                color: _isRecording ? _white : _textSec,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice Recording Overlay
// Full-screen immersive UI shown when mic is active — pulsingripple rings,
// animated waveform bars, live partial transcript, 3-second auto-stop hint.
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceRecordingOverlay extends StatefulWidget {
  final String      partialText;
  final VoidCallback onStop;

  const _VoiceRecordingOverlay({
    required this.partialText,
    required this.onStop,
  });

  @override
  State<_VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<_VoiceRecordingOverlay>
    with TickerProviderStateMixin {

  // Ripple rings expanding outward
  late AnimationController _rippleCtrl;

  // Glow halo pulse (opacity only — no scale to prevent visual jitter)
  late AnimationController _orbCtrl;

  // Waveform bar heights — randomised via timer
  List<double> _barHeights = List.filled(9, 8.0);
  Timer?       _waveTimer;
  final _rand  = Random();

  // Baseline bell-curve heights so outer bars are shorter
  static const _basePeaks = [
    10.0, 16.0, 24.0, 34.0, 44.0, 34.0, 24.0, 16.0, 10.0
  ];

  @override
  void initState() {
    super.initState();

    // Ripple rings — 2.4s full cycle, three rings staggered by 1/3
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();

    // Glow halo — opacity only, no scale
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    // Waveform randomisation every 180 ms → AnimatedContainer smoothes it
    _waveTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) {
        setState(() {
          _barHeights = List.generate(9, (i) =>
              _basePeaks[i] * (0.25 + _rand.nextDouble() * 0.75));
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

  // Single ripple ring at a given phase offset
  Widget _rippleRing(double phaseOffset, double maxExpand,
      double maxOpacity, double strokeWidth) {
    return AnimatedBuilder(
      animation: _rippleCtrl,
      builder: (_, __) {
        final t = (_rippleCtrl.value + phaseOffset) % 1.0;
        return Container(
          width:  96 + t * maxExpand,
          height: 96 + t * maxExpand,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _verdigris.withOpacity((1.0 - t) * maxOpacity),
              width: strokeWidth,
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
              // ── Top spacer + subtle heading ─────────────────────────────────
              const SizedBox(height: 60),

              Text('BUDDY IS LISTENING',
                style: GoogleFonts.inter(
                  color: _verdigris.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3.0,
                )),

              const Spacer(),

              // ── Ripple orb — fixed 260×260 box so expanding rings never shift layout
              SizedBox(
                width: 260, height: 260,
                child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outer ring (lowest opacity, widest spread)
                  _rippleRing(0.66, 100, 0.20, 1.0),
                  // Mid ring
                  _rippleRing(0.33, 100, 0.40, 1.5),
                  // Inner ring (highest opacity, tightest)
                  _rippleRing(0.00, 100, 0.65, 2.0),

                  // Glow halo behind orb
                  AnimatedBuilder(
                    animation: _orbCtrl,
                    builder: (_, __) => Container(
                      width: 108, height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _verdigris
                                .withOpacity(0.28 + _orbCtrl.value * 0.22),
                            blurRadius: 48,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center orb — static size, no scale (prevents screen jitter)
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF22BBA8),
                          _verdigris,
                          const Color(0xFF0A4A44),
                          const Color(0xFF041A18),
                        ],
                        stops: const [0.0, 0.35, 0.72, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: _verdigris.withOpacity(0.55),
                            blurRadius: 28,
                            spreadRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.mic_rounded,
                        color: Colors.white, size: 40),
                  ),
                ],
              ),
              ),

              const Spacer(),

              // ── Waveform bars ───────────────────────────────────────────────
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
                              ? [_verdigris, _chartreuse]
                              : [
                                  _verdigris.withOpacity(0.4),
                                  _verdigris,
                                ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 36),

              // ── Live partial transcript ─────────────────────────────────────
              // Fixed-height container — text updates in-place, zero layout shift
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
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      widget.partialText.isNotEmpty
                          ? '"${widget.partialText}"'
                          : '',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Listening badge ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing red dot
                  _BlinkingDot(),
                  const SizedBox(width: 8),
                  Text('Listening',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                    )),
                ],
              ),

              const SizedBox(height: 8),
              Text('Auto-stops after 3 s of silence',
                style: GoogleFonts.inter(
                    color: Colors.white24, fontSize: 11, letterSpacing: 0.3)),

              const Spacer(),

              // ── Stop button ─────────────────────────────────────────────────
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
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        )),
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

// ── Blinking red dot for "recording" status ───────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;

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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _crimson.withOpacity(_fade.value),
          boxShadow: [
            BoxShadow(
                color: _crimson.withOpacity(_fade.value * 0.6),
                blurRadius: 6,
                spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
