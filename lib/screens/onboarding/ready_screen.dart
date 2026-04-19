import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Morning Brief Onboarding Screen
// Figma: "I'm Buddy, your AI Chief of Staff"
// Shows once after login — Buddy introduces the daily 6 AM morning brief.
// ─────────────────────────────────────────────────────────────────────────────
class ReadyScreen extends ConsumerStatefulWidget {
  const ReadyScreen({super.key});

  @override
  ConsumerState<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends ConsumerState<ReadyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
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
    final userName = appState.user?.name ?? '';
    final gender = _detectGender(userName);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF002F3A),
              Color(0xFF001A24),
              Color(0xFF000D12),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Avatar
                    _buildAvatar(gender),
                    const SizedBox(height: 36),
                    // Headline
                    _buildHeadline(),
                    const SizedBox(height: 20),
                    // Morning brief message
                    _buildBriefMessage(),
                    const Spacer(flex: 3),
                    // Continue button
                    _buildContinueButton(),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAvatar(String gender) {
    final isMale = gender != 'female';
    final assetPath = isMale
        ? 'assets/avatars/buddy_male.png'
        : 'assets/avatars/buddy_female.png';
    final glowColor =
        isMale ? const Color(0xFF1B998B) : const Color(0xFFE91E8C);

    return Column(
      children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.35),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(55),
            child: Image.asset(
              assetPath,
              width: 110, height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isMale
                        ? [const Color(0xFF1B998B), const Color(0xFF0A4A44)]
                        : [const Color(0xFFE91E8C), const Color(0xFF7B1FA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  isMale ? Icons.person_rounded : Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Buddy',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4A9E94),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ── Headline ──────────────────────────────────────────────────────────────

  Widget _buildHeadline() {
    return Text(
      "I'm Buddy, your AI Chief\nof Staff",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.25,
      ),
    );
  }

  // ── Morning brief message ─────────────────────────────────────────────────

  Widget _buildBriefMessage() {
    return Column(
      children: [
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
        const SizedBox(height: 10),
        Text(
          'You can change this anytime in your profile.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4A7A85),
          ),
        ),
      ],
    );
  }

  // ── Continue button ───────────────────────────────────────────────────────

  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: _continue,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B998B), Color(0xFF4DBF7A), Color(0xFFCBD842)],
            stops: [0.0, 0.5, 1.0],
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
            'Continue',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF001A24),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _detectGender(String name) {
    const femaleNames = {
      'sarah', 'emma', 'olivia', 'sophia', 'ava', 'isabella', 'mia',
      'charlotte', 'amelia', 'harper', 'evelyn', 'abigail', 'emily',
      'elizabeth', 'mila', 'ella', 'avery', 'sofia', 'camila', 'aria',
      'luna', 'chloe', 'penelope', 'layla', 'riley', 'zoey', 'nora',
      'lily', 'eleanor', 'hannah', 'priya', 'aisha', 'fatima', 'noura',
      'mariam', 'reem', 'sara', 'lena', 'dina', 'hana', 'dana', 'maya',
    };
    final first = name.trim().split(' ').first.toLowerCase();
    return femaleNames.contains(first) ? 'female' : 'male';
  }
}
