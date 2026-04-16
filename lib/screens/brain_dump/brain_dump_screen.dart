import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/obligation_model.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../services/voice_service.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _chartrB   = Color(0xFFA8CC00);
const _crimson   = Color(0xFFFF3B30);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);

class BrainDumpScreen extends ConsumerStatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  ConsumerState<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends ConsumerState<BrainDumpScreen>
    with TickerProviderStateMixin {

  final TextEditingController _textCtrl = TextEditingController();
  bool   _isRecording  = false;
  bool   _isProcessing = false;
  String _transcript   = '';
  List<ObligationModel> _parsed = [];
  String? _error;

  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  static const String _systemPrompt = '''You are Wyle, an AI chief of staff.
Parse the following voice/text input and extract obligations/tasks.
Return a JSON array of obligation objects:
[{
  "_id": "unique_id",
  "emoji": "emoji for type",
  "title": "short title",
  "type": "visa|emirates_id|car_registration|insurance|school_fee|mortgage_emi|subscription|medical|document|bill|custom",
  "daysUntil": number (estimate if not mentioned, use 30 as default),
  "risk": "high|medium|low",
  "amount": number or null,
  "status": "active",
  "executionPath": "step-by-step action",
  "notes": "any relevant notes or null",
  "source": "voice"
}]
Return only the JSON array, no explanation.''';

  @override
  void initState() {
    super.initState();
    _waveCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
        ..repeat(reverse: true);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);
    _pulse     = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    VoiceService.instance.init();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    VoiceService.instance.stopListening();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await VoiceService.instance.stopListening();
      setState(() => _isRecording = false);
      return;
    }

    setState(() { _isRecording = true; _transcript = ''; _parsed = []; _error = null; });
    await VoiceService.instance.startListening(
      (text) {
        setState(() { _transcript = text; _isRecording = false; });
        if (text.isNotEmpty) _parseTranscript(text);
      },
      (s) { if (s == 'idle' || s == 'error') setState(() => _isRecording = false); },
    );
  }

  Future<void> _parseText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _transcript = text; _parsed = []; _error = null; });
    await _parseTranscript(text);
  }

  Future<void> _parseTranscript(String text) async {
    setState(() => _isProcessing = true);
    try {
      final response = await AiService.instance.complete(
        systemPrompt: _systemPrompt,
        userMessage:  text,
        maxTokens:    1000,
      );

      final list = AiService.parseJsonArray(response);
      if (list != null && list.isNotEmpty) {
        final obligations = list.map((json) {
          json['_id'] ??= DateTime.now().millisecondsSinceEpoch.toString() +
              '_${list.indexOf(json)}';
          return ObligationModel.fromJson(json);
        }).toList();
        setState(() => _parsed = obligations);
      } else {
        setState(() => _error = 'Could not parse obligations. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addAllObligations() {
    for (final ob in _parsed) {
      ref.read(appStateProvider.notifier).addObligation(ob);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_parsed.length} obligation${_parsed.length == 1 ? '' : 's'} added!'),
      backgroundColor: _verdigris,
    ));
    Navigator.of(context).pop();
  }

  void _removeObligation(int index) {
    setState(() => _parsed.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMicSection(),
                    const SizedBox(height: 16),
                    _buildTextInput(),
                    if (_transcript.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTranscriptCard(),
                    ],
                    if (_isProcessing) ...[
                      const SizedBox(height: 20),
                      _buildProcessingCard(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorCard(),
                    ],
                    if (_parsed.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildParsedObligations(),
                    ],
                  ],
                ),
              ),
            ),
            if (_parsed.isNotEmpty) _buildAddAllButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              child: const Icon(Icons.close, color: _white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Brain Dump', style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
                Text('Speak or type — Wyle will organize it',
                    style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicSection() {
    return Center(
      child: Column(
        children: [
          // Waveform animation (only during recording)
          if (_isRecording)
            AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) {
                  final heights = [8.0, 14.0, 22.0, 36.0, 22.0, 14.0, 8.0];
                  final anim = ((_waveCtrl.value + i * 0.14) % 1.0);
                  return Container(
                    width: 4, height: heights[i] * (0.6 + anim * 0.4),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _verdigris,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            )
          else
            const SizedBox(height: 36),

          const SizedBox(height: 16),

          // Mic button
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: _isRecording ? _pulse.value : 1.0,
                child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isRecording
                          ? [_crimson, const Color(0xFFFF6B6B)]
                          : [_verdigris, const Color(0xFF157A6E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? _crimson : _verdigris).withOpacity(0.4),
                        blurRadius: 20, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none_rounded,
                    color: _white, size: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isRecording ? 'Tap to stop' : 'Tap to record',
            style: GoogleFonts.inter(fontSize: 13, color: _textSec),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            style: GoogleFonts.inter(color: _white, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Or type your obligations here…\ne.g. "I need to renew my car registration in 7 days and pay DEWA bill"',
              hintStyle: GoogleFonts.inter(color: _textTer, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _parseText,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_verdigris, Color(0xFF157A6E)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Parse',
                        style: GoogleFonts.inter(
                            color: _white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _verdigris.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _verdigris.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOU SAID', style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _verdigris, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(_transcript,
              style: GoogleFonts.inter(fontSize: 14, color: _white, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _verdigris)),
        const SizedBox(width: 12),
        Text('Wyle is parsing your obligations…',
            style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
      ]),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _crimson.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _crimson.withOpacity(0.25)),
      ),
      child: Text(_error!,
          style: GoogleFonts.inter(fontSize: 13, color: _crimson)),
    );
  }

  Widget _buildParsedObligations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('PARSED OBLIGATIONS',
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _textSec, letterSpacing: 1.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _verdigris.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _verdigris.withOpacity(0.3)),
              ),
              child: Text('${_parsed.length}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _verdigris, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_parsed.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildParsedCard(_parsed[i], i),
        )),
      ],
    );
  }

  Widget _buildParsedCard(ObligationModel ob, int index) {
    final riskColor = ob.risk == 'high'   ? _crimson
                    : ob.risk == 'medium' ? _chartreuse
                    : _verdigris;

    return Container(
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color strip
          Container(height: 3,
            decoration: BoxDecoration(
              color: riskColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ob.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(ob.title, style: GoogleFonts.inter(
                          fontSize: 15, color: _white, fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: () => _removeObligation(index),
                      child: const Icon(Icons.close, color: _textTer, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(ob.executionPath,
                    style: GoogleFonts.inter(fontSize: 12, color: _textSec)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip('${ob.daysUntil}d', riskColor),
                    const SizedBox(width: 8),
                    _chip(ob.risk.toUpperCase(), riskColor),
                    if (ob.amount != null) ...[
                      const SizedBox(width: 8),
                      _chip('AED ${ob.amount!.toInt()}', _textSec),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(text, style: GoogleFonts.inter(
        fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _buildAddAllButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: GestureDetector(
        onTap: _addAllObligations,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_chartreuse, _chartrB]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              'Add ${_parsed.length} Obligation${_parsed.length == 1 ? '' : 's'} →',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _bg),
            ),
          ),
        ),
      ),
    );
  }
}
