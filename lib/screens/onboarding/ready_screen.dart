import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';

class ReadyScreen extends ConsumerStatefulWidget {
  const ReadyScreen({super.key});

  @override
  ConsumerState<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends ConsumerState<ReadyScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _checkController;
  late Animation<double> _checkScaleAnimation;
  late Animation<double> _checkOpacityAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _checkOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _checkController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _checkController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    ref.read(appStateProvider.notifier).setOnboardingComplete();
    context.go(AppRoutes.main);
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
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildCheckCircle(),
                const SizedBox(height: 40),
                _buildTextContent(),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
                  child: _buildDashboardButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckCircle() {
    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _checkScaleAnimation.value * _pulseAnimation.value,
          child: Opacity(
            opacity: _checkOpacityAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1B998B).withOpacity(0.08),
                    border: Border.all(
                      color: const Color(0xFF1B998B).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                // Inner circle
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1B998B).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFF1B998B),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B998B).withOpacity(0.4),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF1B998B),
                    size: 52,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextContent() {
    return Column(
      children: [
        Text(
          "You're All Set!",
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFEFFFE),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Wyle is ready to manage your life',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: const Color(0xFF8FB8BF),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              _buildFeatureLine(Icons.auto_awesome_rounded,
                  'Your AI chief of staff is configured'),
              const SizedBox(height: 12),
              _buildFeatureLine(
                  Icons.notifications_active_rounded, 'Smart reminders are enabled'),
              const SizedBox(height: 12),
              _buildFeatureLine(
                  Icons.security_rounded, 'Your data is encrypted and private'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureLine(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1B998B), size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF8FB8BF),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardButton() {
    return GestureDetector(
      onTap: _goToDashboard,
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
              color: const Color(0xFF1B998B).withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Go to Dashboard →',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF002F3A),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
