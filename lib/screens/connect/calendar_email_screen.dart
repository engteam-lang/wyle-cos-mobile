import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Calendar & Email connection screen
// ─────────────────────────────────────────────────────────────────────────────
class CalendarEmailScreen extends ConsumerStatefulWidget {
  const CalendarEmailScreen({super.key});

  @override
  ConsumerState<CalendarEmailScreen> createState() =>
      _CalendarEmailScreenState();
}

class _CalendarEmailScreenState extends ConsumerState<CalendarEmailScreen>
    with SingleTickerProviderStateMixin {
  // ── Enter animation ────────────────────────────────────────────────────────
  late AnimationController _enterCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Connection state ───────────────────────────────────────────────────────
  bool _gmailConnected   = false;
  bool _outlookConnected = false;

  static const _gmailEmail   = 'you@gmail.com';
  static const _outlookEmail = 'you@outlook.com';

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1C1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Email Providers'),
                        const SizedBox(height: 12),
                        _buildGmailCard(),
                        const SizedBox(height: 14),
                        _buildOutlookCard(),
                        const SizedBox(height: 28),
                        _buildInfoNote(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3530),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF254540)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Calendar & Email',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF5A7A78),
        letterSpacing: 1.0,
      ),
    );
  }

  // ── Gmail card ─────────────────────────────────────────────────────────────
  Widget _buildGmailCard() {
    final c = _gmailConnected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c ? const Color(0xFF0A2A1A) : const Color(0xFF132E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c ? const Color(0xFF1B8B5A) : const Color(0xFF1E3E3A),
          width: c ? 1.5 : 1.0,
        ),
        boxShadow: c
            ? [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ────────────────────────────────────────────────────────
          Row(
            children: [
              _providerIcon(
                child: CustomPaint(
                    size: const Size(26, 26), painter: _GoogleGPainter()),
                bg: c
                    ? const Color(0xFF0D3020)
                    : const Color(0xFF1A3530),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gmail',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                    Text(
                      c ? _gmailEmail : 'Google Mail & Calendar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: c
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF6A8E8C),
                      ),
                    ),
                  ],
                ),
              ),
              if (c) _connectedBadge(const Color(0xFF4ADE80), const Color(0xFF14532D)),
            ],
          ),

          // ── Actions ────────────────────────────────────────────────────────
          if (!c) ...[
            const SizedBox(height: 16),
            _connectBtn(
              label: 'Connect Gmail',
              color: const Color(0xFF22C55E),
              onTap: () => setState(() => _gmailConnected = true),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _permissionChips(
              ['Read Mail', 'Send Mail', 'Calendar'],
              const Color(0xFF22C55E),
              const Color(0xFF0D3020),
            ),
            const SizedBox(height: 14),
            _disconnectBtn(
              label: 'Disconnect Gmail',
              onTap: () => setState(() => _gmailConnected = false),
            ),
          ],
        ],
      ),
    );
  }

  // ── Outlook card ───────────────────────────────────────────────────────────
  Widget _buildOutlookCard() {
    final c = _outlookConnected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c ? const Color(0xFF0A1A2E) : const Color(0xFF132E2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c ? const Color(0xFF1E6FBF) : const Color(0xFF1E3E3A),
          width: c ? 1.5 : 1.0,
        ),
        boxShadow: c
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ────────────────────────────────────────────────────────
          Row(
            children: [
              _providerIcon(
                child: CustomPaint(
                    size: const Size(26, 26),
                    painter: _OutlookLogoPainter(
                        holeBg: c
                            ? const Color(0xFF0D1E38)
                            : const Color(0xFF1A3530))),
                bg: c
                    ? const Color(0xFF0D1E38)
                    : const Color(0xFF1A3530),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outlook',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                    Text(
                      c ? _outlookEmail : 'Microsoft Mail & Calendar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: c
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF6A8E8C),
                      ),
                    ),
                  ],
                ),
              ),
              if (c) _connectedBadge(const Color(0xFF60A5FA), const Color(0xFF1E3A5F)),
            ],
          ),

          // ── Actions ────────────────────────────────────────────────────────
          if (!c) ...[
            const SizedBox(height: 16),
            _connectBtn(
              label: 'Connect Outlook',
              color: const Color(0xFF3B82F6),
              onTap: () => setState(() => _outlookConnected = true),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _permissionChips(
              ['Read Mail', 'Send Mail', 'Calendar'],
              const Color(0xFF3B82F6),
              const Color(0xFF0D1E38),
            ),
            const SizedBox(height: 14),
            _disconnectBtn(
              label: 'Disconnect Outlook',
              onTap: () => setState(() => _outlookConnected = false),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _providerIcon({required Widget child, required Color bg}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Center(child: child),
    );
  }

  Widget _connectedBadge(Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('Connected',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _connectBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withOpacity(0.85),
            color.withOpacity(0.60),
          ]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Widget _disconnectBtn({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3A3A)),
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF))),
        ),
      ),
    );
  }

  Widget _permissionChips(List<String> chips, Color color, Color bg) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map((c) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Text(c,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: color.withOpacity(0.85),
                        fontWeight: FontWeight.w500)),
              ))
          .toList(),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF132E2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3E3A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF4FC3F7), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connecting your accounts lets Wyle read your schedule, '
              'draft replies, and surface what matters — privately and securely.',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF7AACB8),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google G — 4-colour ring + horizontal bar
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue   = Color(0xFF4285F4);
  static const _red    = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green  = Color(0xFF34A853);

  void _slice(Canvas canvas, double cx, double cy,
      double outerR, double innerR,
      double startDeg, double sweepDeg, Color color) {
    final startRad = startDeg * math.pi / 180;
    final sweepRad = sweepDeg * math.pi / 180;

    final path = Path()
      ..moveTo(cx + innerR * math.cos(startRad),
               cy + innerR * math.sin(startRad))
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
              startRad, sweepRad, false)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
              startRad + sweepRad, -sweepRad, false)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final outerR = size.width  / 2 * 0.90;
    final innerR = size.width  / 2 * 0.54;

    _slice(canvas, cx, cy, outerR, innerR,  18,  72, _green);   // lower-right
    _slice(canvas, cx, cy, outerR, innerR,  90,  90, _yellow);  // lower-left
    _slice(canvas, cx, cy, outerR, innerR, 180,  90, _red);     // upper-left
    _slice(canvas, cx, cy, outerR, innerR, 270,  72, _blue);    // upper-right

    // Blue horizontal bar (right of centre)
    final barHalf = outerR * 0.175;
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - barHalf, cx + outerR, cy + barHalf),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Outlook "envelope + O" logo painter
// ─────────────────────────────────────────────────────────────────────────────
class _OutlookLogoPainter extends CustomPainter {
  final Color holeBg;
  const _OutlookLogoPainter({required this.holeBg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // Envelope background (Microsoft blue)
    final envRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width:  size.width  * 0.90,
        height: size.height * 0.68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(envRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF0078D4),
    );

    // White "O" circle
    final oCx = cx - size.width * 0.07;
    canvas.drawCircle(
        Offset(oCx, cy), size.width * 0.21, Paint()..color = Colors.white);

    // Hole (card background colour)
    canvas.drawCircle(
        Offset(oCx, cy), size.width * 0.13, Paint()..color = holeBg);

    // Fold lines
    final line = Paint()
      ..color       = Colors.white.withOpacity(0.28)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(envRect.left,  envRect.top),    Offset(cx, cy - 1), line);
    canvas.drawLine(Offset(envRect.right, envRect.top),    Offset(cx, cy - 1), line);
  }

  @override
  bool shouldRepaint(covariant _OutlookLogoPainter old) =>
      old.holeBg != holeBg;
}
