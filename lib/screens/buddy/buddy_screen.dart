import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message_model.dart';
import '../../models/obligation_model.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_colors.dart';
import '../../constants/app_constants.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _salmon    = Color(0xFFFF9F8A);
const _crimson   = Color(0xFFFF3B30);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);

class BuddyScreen extends ConsumerStatefulWidget {
  const BuddyScreen({super.key});

  @override
  ConsumerState<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends ConsumerState<BuddyScreen>
    with TickerProviderStateMixin {

  final List<ChatMessageModel> _messages   = [];
  final TextEditingController  _textCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  bool _isRecording   = false;
  bool _isProcessing  = false;
  bool _isSpeaking    = false;

  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();

    _waveCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    VoiceService.instance.init();

    // Welcome message
    _messages.add(ChatMessageModel.assistant(
      "Hi! I'm Buddy, your AI chief of staff. I can help you manage your obligations, "
      "check your calendar, and take care of tasks. What would you like to do today?",
    ));
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  // ── Voice recording ─────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await VoiceService.instance.stopListening();
      setState(() => _isRecording = false);
      return;
    }

    setState(() => _isRecording = true);
    await VoiceService.instance.startListening(
      (text) {
        if (text.isNotEmpty) {
          setState(() => _isRecording = false);
          _sendMessage(text);
        } else {
          setState(() => _isRecording = false);
        }
      },
      (state) {
        if (state == 'idle' || state == 'error') {
          if (mounted) setState(() => _isRecording = false);
        }
      },
    );
  }

  // ── Send message ─────────────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();

    final userMsg = ChatMessageModel.user(text);
    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      final obligations = ref.read(activeObligationsProvider);
      final response = await AiService.instance.complete(
        systemPrompt: _buildSystemPrompt(obligations),
        userMessage:  text,
        maxTokens:    600,
      );

      final assistantMsg = ChatMessageModel.assistant(response);
      setState(() {
        _messages.add(assistantMsg);
        _isProcessing = false;
      });
      _scrollToBottom();

      // Speak the response
      setState(() => _isSpeaking = true);
      await VoiceService.instance.speak(response);
      if (mounted) setState(() => _isSpeaking = false);
    } catch (e) {
      setState(() {
        _messages.add(ChatMessageModel.assistant(
          "Sorry, I couldn't process that right now. Please check your connection and try again.",
        ));
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
          curve:    Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildQuickPrompts(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Buddy orb avatar
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: _isSpeaking ? _pulse.value : 1.0,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B998B), Color(0xFFD5FF3F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: _verdigris.withOpacity(0.4),
                        blurRadius: 12, spreadRadius: 1),
                  ],
                ),
                child: const Center(
                  child: Text('◎', style: TextStyle(fontSize: 20, color: _white)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buddy', style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: _verdigris, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isRecording   ? 'Listening…'
                      : _isProcessing ? 'Thinking…'
                      : _isSpeaking   ? 'Speaking…'
                      : 'Ready',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _verdigris, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                  colors: [_verdigris, Color(0xFFD5FF3F)],
                ),
              ),
              child: const Center(
                child: Text('◎', style: TextStyle(fontSize: 12, color: _white)),
              ),
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
              child: Text(
                msg.content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isUser ? _white : _white,
                  height: 1.5,
                ),
              ),
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
              gradient: LinearGradient(colors: [_verdigris, Color(0xFFD5FF3F)]),
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
                  final offset = i * 0.33;
                  final anim   = ((_waveCtrl.value + offset) % 1.0);
                  return Container(
                    width: 7, height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _verdigris.withOpacity(0.4 + anim * 0.6),
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

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppConstants.buddyQuickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final prompt = AppConstants.buddyQuickPrompts[i];
          return GestureDetector(
            onTap: () => _sendMessage(prompt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Text(prompt,
                style: GoogleFonts.inter(
                    fontSize: 12, color: _textSec, fontWeight: FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Text input
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
                  hintText: 'Ask Buddy anything…',
                  hintStyle: GoogleFonts.inter(color: _textTer, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
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

          // Mic button
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: _isRecording ? _pulse.value : 1.0,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? _crimson.withOpacity(0.9)
                        : const Color(0xFF252525),
                    boxShadow: _isRecording
                        ? [BoxShadow(color: _crimson.withOpacity(0.4),
                              blurRadius: 16, spreadRadius: 2)]
                        : null,
                  ),
                  child: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none_rounded,
                    color: _isRecording ? _white : _textSec,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
