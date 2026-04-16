import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF002F3A),
              Color(0xFF001820),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _buildLogo(),
                  const SizedBox(height: 48),
                  _buildHeroHeading(),
                  const SizedBox(height: 40),
                  _buildFeatureCards(),
                  const SizedBox(height: 48),
                  _buildGetStartedButton(),
                  const SizedBox(height: 20),
                  _buildSignInLink(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'WYLE',
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: FontWeight.w200,
            color: const Color(0xFFFEFFFE),
            letterSpacing: 14,
            shadows: [
              const Shadow(
                color: Color(0x661B998B),
                blurRadius: 24,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Shimmer underline
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              height: 2,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF1B998B).withOpacity(0.1),
                    const Color(0xFF1B998B).withOpacity(0.9),
                    const Color(0xFFD5FF3F).withOpacity(0.8),
                    const Color(0xFF1B998B).withOpacity(0.1),
                  ],
                  stops: [
                    0.0,
                    (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                    _shimmerController.value.clamp(0.0, 1.0),
                    (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'DIGITAL CHIEF OF STAFF',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8FB8BF),
            letterSpacing: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeading() {
    return Column(
      children: [
        Text(
          'Your life,\norchestrated.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: const Color(0xFFFEFFFE),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your AI-powered chief of staff that manages\nyour schedule, obligations, and priorities.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF8FB8BF),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    final features = [
      (
        icon: Icons.auto_awesome_rounded,
        title: 'AI-Powered Management',
        subtitle: 'Smart scheduling and task prioritization',
      ),
      (
        icon: Icons.calendar_today_rounded,
        title: 'Calendar Intelligence',
        subtitle: 'Sync and optimize across all your calendars',
      ),
      (
        icon: Icons.mic_rounded,
        title: 'Voice First',
        subtitle: 'Hands-free control with natural language',
      ),
    ];

    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeatureCard(
                  icon: f.icon,
                  title: f.title,
                  subtitle: f.subtitle,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildGetStartedButton() {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.login),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B998B), Color(0xFFD5FF3F)],
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
            'Get Started →',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF002F3A),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.login),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF8FB8BF),
          ),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign In',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B998B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D4A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A5060), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1B998B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1B998B), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFEFFFE),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF8FB8BF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
