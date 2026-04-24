import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'connect_screen.dart' show kProfileBg, kProfileCard, kProfileBorder, kProfileGradient;
import '../../widgets/coming_soon_overlay.dart';

class SocialAccountsScreen extends ConsumerStatefulWidget {
  const SocialAccountsScreen({super.key});
  @override
  ConsumerState<SocialAccountsScreen> createState() => _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends ConsumerState<SocialAccountsScreen>
    with SingleTickerProviderStateMixin, ComingSoonMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  static const _meta = {
    'LinkedIn':    (Color(0xFF0A66C2), Color(0xFF0A1A38), Icons.work_outline_rounded,    'Professional Network'),
    'X (Twitter)': (Color(0xFFE7E7E7), Color(0xFF1A1A1A), Icons.tag_rounded,             'Microblogging Platform'),
    'Instagram':   (Color(0xFFE1306C), Color(0xFF2E0A1E), Icons.photo_camera_rounded,    'Photo & Video Sharing'),
    'Facebook':    (Color(0xFF1877F2), Color(0xFF0A1A38), Icons.facebook_rounded,        'Social Network'),
  };

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    disposeComingSoon();
    super.dispose();
  }

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
                            children: _meta.entries.map((e) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _card(e.key),
                              )).toList(),
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

  Widget _card(String name) {
    final m        = _meta[name]!;
    final accent   = m.$1;
    final iconBg   = m.$2;
    final iconData = m.$3;
    final subtitle = m.$4;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kProfileCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kProfileBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(iconData, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF6A8E8C))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showComingSoon(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1B998B).withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B998B).withOpacity(0.4)),
              ),
              child: Text('Connect',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B998B))),
            ),
          ),
        ],
      ),
    );
  }

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
            color: const Color(0xFF0A2A46), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.language_rounded, color: Color(0xFF42A5F5), size: 18),
        ),
        const SizedBox(width: 10),
        Text('Social Accounts',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    ),
  );
}
