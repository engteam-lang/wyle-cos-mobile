import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/chat_message_model.dart';
import '../../models/obligation_model.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../services/voice_service.dart';
import '../../constants/app_constants.dart';

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

  final List<ChatMessageModel> _messages    = [];
  final TextEditingController  _textCtrl    = TextEditingController();
  final ScrollController       _scrollCtrl  = ScrollController();

  bool   _isRecording  = false;
  bool   _isProcessing = false;
  bool   _isSpeaking   = false;
  String _partialText  = '';

  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  // Entry animation for the overlay
  late AnimationController _overlayCtrl;
  late Animation<double>   _overlayAnim;

  @override
  void initState() {
    super.initState();

    _waveCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse     = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _overlayCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 380));
    _overlayAnim = CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeOutCubic);

    VoiceService.instance.init();

    _messages.add(ChatMessageModel.assistant(
      "Hi! I'm Buddy, your AI chief of staff. I can help you manage your obligations, "
      "check your calendar, and take care of tasks. What would you like to do today?",
    ));
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _overlayCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    VoiceService.instance.stopListening();
    super.dispose();
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
    if (text.trim().isEmpty) return;
    _textCtrl.clear();

    setState(() {
      _messages.add(ChatMessageModel.user(text));
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

      setState(() {
        _messages.add(ChatMessageModel.assistant(response));
        _isProcessing = false;
      });
      _scrollToBottom();

      setState(() => _isSpeaking = true);
      await VoiceService.instance.speak(response);
      if (mounted) setState(() => _isSpeaking = false);
    } catch (_) {
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
                _buildQuickPrompts(),
                _buildInputBar(),
              ],
            ),

            // ── Voice recording overlay (slides in on top) ────────────────────
            if (_isRecording)
              FadeTransition(
                opacity: _overlayAnim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1.0)
                      .animate(_overlayAnim),
                  child: _VoiceRecordingOverlay(
                    partialText: _partialText,
                    onStop: _stopRecording,
                  ),
                ),
              ),
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

  // ── Quick prompts ─────────────────────────────────────────────────────────────
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
                    fontSize: 12, color: _textSec,
                    fontWeight: FontWeight.w500)),
            ),
          );
        },
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
          // Text field
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
                  hintStyle:
                      GoogleFonts.inter(color: _textTer, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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

          // Mic button — tapping opens the full-screen recording overlay
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

  // Center orb gentle breathe
  late AnimationController _orbCtrl;
  late Animation<double>   _orbScale;

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

    // Orb breathe
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _orbScale = Tween<double>(begin: 1.0, end: 1.09)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));

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

              // ── Ripple orb ──────────────────────────────────────────────────
              Stack(
                alignment: Alignment.center,
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

                  // Center orb
                  AnimatedBuilder(
                    animation: _orbCtrl,
                    builder: (_, __) => Transform.scale(
                      scale: _orbScale.value,
                      child: Container(
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
                    ),
                  ),
                ],
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                child: widget.partialText.isNotEmpty
                    ? Container(
                        key: ValueKey(widget.partialText),
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
                          '"${widget.partialText}"',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            height: 1.55,
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 52),
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
