import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Morning Brief Onboarding Screen  — matches Figma design
// "I'm Buddy, your AI Chief of Staff"
// ─────────────────────────────────────────────────────────────────────────────
class ReadyScreen extends ConsumerStatefulWidget {
  const ReadyScreen({super.key});

  @override
  ConsumerState<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends ConsumerState<ReadyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    ref.read(appStateProvider.notifier).setOnboardingComplete();
    context.go(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final gender   = _detectGender(appState.user?.name ?? '');

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF002F3A), Color(0xFF001A24), Color(0xFF000D12)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ── Avatar (rounded square, like Figma) ──────────────────
                    _buildAvatar(gender),

                    const SizedBox(height: 28),

                    // ── Headline ─────────────────────────────────────────────
                    Text(
                      "I'm Buddy, your AI Chief\nof Staff",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Morning brief copy ───────────────────────────────────
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8FB8BF),
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: 'Your morning brief is set for '),
                          TextSpan(
                            text: '6:00 AM',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B998B),
                            ),
                          ),
                          const TextSpan(text: '\nevery day.'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'You can change this anytime in your profile.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF4A7A85),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── "Let's get started" button ───────────────────────────
                    _buildCTAButton(),

                    const Spacer(flex: 2),

                    // ── Three tips ───────────────────────────────────────────
                    _buildTips(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  // Rounded-square white card (like Figma) rather than a circle
  Widget _buildAvatar(String gender) {
    final isMale    = gender != 'female';
    final assetPath = isMale
        ? 'assets/avatars/buddy_male.png'
        : 'assets/avatars/buddy_female.png';
    final glowColor = isMale
        ? const Color(0xFF1B998B)
        : const Color(0xFFE91E8C);

    return Container(
      width: 108, height: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          assetPath,
          width: 108, height: 108,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF0A2E38),
            child: Icon(
              isMale ? Icons.person_rounded : Icons.person_outline_rounded,
              color: glowColor,
              size: 52,
            ),
          ),
        ),
      ),
    );
  }

  // ── CTA button ─────────────────────────────────────────────────────────────
  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: _continue,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B998B), Color(0xFF52C878), Color(0xFFD4E840)],
            stops: [0.0, 0.45, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B998B).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            "Let's get started",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF001A24),
            ),
          ),
        ),
      ),
    );
  }

  // ── Three tips ─────────────────────────────────────────────────────────────
  Widget _buildTips() {
    final tips = [
      (icon: Icons.chat_bubble_outline_rounded,
       text: 'Talk to me naturally – I understand context'),
      (icon: Icons.mic_none_rounded,
       text: 'Voice dumps work best – just tell me everything'),
      (icon: Icons.settings_outlined,
       text: 'Tap your profile icon anytime for settings'),
    ];

    return Column(
      children: tips.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0A2E38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(t.icon, color: const Color(0xFF1B998B), size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.text,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF7AACB8),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // ── Gender heuristic ───────────────────────────────────────────────────────
  String _detectGender(String name) {
    const femaleNames = {
      'sarah','emma','olivia','sophia','ava','isabella','mia','charlotte',
      'amelia','harper','evelyn','abigail','emily','elizabeth','mila','ella',
      'avery','sofia','camila','aria','luna','chloe','penelope','layla',
      'riley','zoey','nora','lily','eleanor','hannah','priya','aisha',
      'fatima','noura','mariam','reem','sara','lena','dina','hana','dana','maya',
    };
    final first = name.trim().split(' ').first.toLowerCase();
    return femaleNames.contains(first) ? 'female' : 'male';
  }
}
