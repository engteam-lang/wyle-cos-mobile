import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'connect_screen.dart' show kProfileBg, kProfileCard, kProfileBorder, kProfileGradient;
import '../../widgets/coming_soon_overlay.dart';

class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});
  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen>
    with SingleTickerProviderStateMixin, ComingSoonMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  bool _connected  = false;
  bool _bizMode    = false;

  static const _green = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); disposeComingSoon(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: kProfileBg,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: kProfileGradient,
            child: SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    children: [
                      _header(context),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _mainCard(),
                              const SizedBox(height: 24),
                              _infoNote(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (csVisible) buildComingSoonOverlay(),
      ],
    );
  }

  Widget _mainCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _connected ? const Color(0xFF0A2518) : kProfileCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _connected ? _green.withOpacity(0.45) : kProfileBorder,
          width: _connected ? 1.5 : 1.0,
        ),
        boxShadow: _connected
            ? [BoxShadow(color: _green.withOpacity(0.16), blurRadius: 20)]
            : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_rounded, color: _green, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WhatsApp',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(_connected ? '+971 XX XXX XXXX' : 'Messaging & Notifications',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _connected ? _green : const Color(0xFF6A8E8C))),
                  ],
                ),
              ),
              if (_connected)
                _badge(_green, const Color(0xFF0A2518)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => showComingSoon('WhatsApp'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_green.withOpacity(0.85), _green.withOpacity(0.60)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Connect WhatsApp',
                  style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permCard(String title, String subtitle, bool value, {ValueChanged<bool>? onToggle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kProfileCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kProfileBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF6A8E8C))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onToggle,
            activeColor: _green,
            activeTrackColor: _green.withOpacity(0.3),
            inactiveThumbColor: const Color(0xFF5A7A78),
            inactiveTrackColor: kProfileBorder,
          ),
        ],
      ),
    );
  }

  Widget _badge(Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('Connected',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text.toUpperCase(),
      style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF5A7A78), letterSpacing: 1.0));

  Widget _infoNote() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kProfileCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kProfileBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF4FC3F7), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Wyle reads message summaries only — it never stores, shares, '
            'or accesses private conversations without your explicit permission.',
            style: GoogleFonts.poppins(
                fontSize: 12, color: const Color(0xFF7AACB8), height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3530), shape: BoxShape.circle,
              border: Border.all(color: kProfileBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF0A2E1E), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.chat_rounded, color: Color(0xFF4CAF50), size: 18),
        ),
        const SizedBox(width: 10),
        Text('WhatsApp',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    ),
  );
}
