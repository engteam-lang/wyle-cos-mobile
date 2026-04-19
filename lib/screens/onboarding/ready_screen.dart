import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Morning Brief Onboarding Screen
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
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // "Let's get started" → show Quick Guide modal
  void _onGetStarted() {
    final gender = _detectGender(ref.read(appStateProvider).user?.name ?? '');
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _QuickGuideDialog(
        gender: gender,
        onComplete: () {
          Navigator.of(context, rootNavigator: true).pop();
          ref.read(appStateProvider.notifier).setOnboardingComplete();
          context.go(AppRoutes.main);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gender = _detectGender(
        ref.watch(appStateProvider).user?.name ?? '');

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
                    _buildAvatar(gender),
                    const SizedBox(height: 28),
                    Text(
                      "I'm Buddy, your AI Chief\nof Staff",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: Colors.white, height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 18),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 15, color: const Color(0xFF8FB8BF),
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: 'Your morning brief is set for '),
                          TextSpan(
                            text: '6:00 AM',
                            style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600,
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
                          fontSize: 13, color: const Color(0xFF4A7A85)),
                    ),
                    const SizedBox(height: 36),
                    _buildCTAButton(),
                    const Spacer(flex: 2),
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
          BoxShadow(color: glowColor.withOpacity(0.35),
              blurRadius: 32, spreadRadius: 4),
          BoxShadow(color: Colors.black.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(assetPath, width: 108, height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              isMale ? Icons.person_rounded : Icons.person_outline_rounded,
              color: glowColor, size: 52,
            )),
      ),
    );
  }

  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: _onGetStarted,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B998B), Color(0xFF52C878), Color(0xFFD4E840)],
            stops: [0.0, 0.45, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1B998B).withOpacity(0.35),
                blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: Text("Let's get started",
            style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: const Color(0xFF001A24),
            ),
          ),
        ),
      ),
    );
  }

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
              child: Text(t.text,
                style: GoogleFonts.poppins(
                  fontSize: 13, color: const Color(0xFF7AACB8), height: 1.45,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  String _detectGender(String name) {
    const f = {'sarah','emma','olivia','sophia','ava','isabella','mia',
      'charlotte','amelia','harper','emily','elizabeth','mila','ella',
      'avery','sofia','camila','aria','luna','chloe','penelope','layla',
      'riley','zoey','nora','lily','eleanor','hannah','priya','aisha',
      'fatima','noura','mariam','reem','sara','lena','dina','hana','dana','maya'};
    return f.contains(name.trim().split(' ').first.toLowerCase())
        ? 'female' : 'male';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Guide Dialog  — matches Figma modal overlay
// ─────────────────────────────────────────────────────────────────────────────
class _QuickGuideDialog extends StatelessWidget {
  final String gender;
  final VoidCallback onComplete;

  const _QuickGuideDialog({required this.gender, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final isMale    = gender != 'female';
    final assetPath = isMale
        ? 'assets/avatars/buddy_male.png'
        : 'assets/avatars/buddy_female.png';
    final glowColor = isMale
        ? const Color(0xFF1B998B)
        : const Color(0xFFE91E8C);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF061A16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1B998B), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top row: spacer + X button ──────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 16),
                  ),
                ),
              ),
            ),

            // ── Avatar ──────────────────────────────────────────────────────
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: glowColor.withOpacity(0.35),
                      blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(assetPath,
                    width: 84, height: 84, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      isMale ? Icons.person_rounded : Icons.person_outline_rounded,
                      color: glowColor, size: 40,
                    )),
              ),
            ),

            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────────
            Text('Quick Guide',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text("Here's how to work with me",
              style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF7AACB8),
              ),
            ),

            const SizedBox(height: 20),

            // ── Three guide items ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _guideItem(
                    iconWidget: const Text('👋',
                        style: TextStyle(fontSize: 20)),
                    title: "I'm always here",
                    body: "When I'm listening, I'll come out. "
                        "When I have something for you, I'll show you.",
                  ),
                  const SizedBox(height: 14),
                  _guideItem(
                    iconWidget: const Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white70, size: 20),
                    title: 'Type or speak',
                    body: 'Use the input bar below. Speaking is faster – '
                        "try telling me what's on your mind.",
                  ),
                  const SizedBox(height: 14),
                  _guideItem(
                    iconWidget: const Icon(Icons.settings_outlined,
                        color: Colors.white70, size: 20),
                    title: 'Connect & customize',
                    body: 'Tap your profile icon (top right) for connections '
                        'and settings. The more you connect, the more I can help.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── "Got it, let's start" button ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                onTap: onComplete,
                child: Container(
                  width: double.infinity, height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1B998B), Color(0xFF52C878), Color(0xFFD4E840),
                      ],
                      stops: [0.0, 0.45, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B998B).withOpacity(0.35),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text("Got it, let's start",
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: const Color(0xFF001A24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideItem({
    required Widget iconWidget,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0E2E28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1B998B).withOpacity(0.3)),
          ),
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(body,
                style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF7AACB8), height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
