import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';

class PreparationScreen extends ConsumerStatefulWidget {
  const PreparationScreen({super.key});

  @override
  ConsumerState<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends ConsumerState<PreparationScreen>
    with TickerProviderStateMixin {
  // Pulsing orb
  late AnimationController _orbController;
  late Animation<double> _orbScaleAnimation;
  late Animation<double> _orbGlowAnimation;

  // Fade in content
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Loading dots
  late AnimationController _dotsController;

  // Step text animation
  int _currentStep = 0;
  final List<String> _steps = [
    'Preparing your dashboard...',
    'Loading your obligations...',
    'Configuring AI assistant...',
  ];

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _orbScaleAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );
    _orbGlowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Cycle through loading messages
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _currentStep = 1);
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _currentStep = 2);
    });

    // Navigate after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final appState = ref.read(appStateProvider);
      if (appState.token != null && appState.user != null) {
        // setAuth was already called during login — ensure state is current
        await ref.read(appStateProvider.notifier).setAuth(
          appState.token!,
          appState.user!,
        );
      }
      if (mounted) {
        context.go(AppRoutes.ready); // → Morning brief onboarding screen
      }
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF002F3A),
              Color(0xFF001015),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _buildOrb(),
                const SizedBox(height: 56),
                _buildLoadingText(),
                const SizedBox(height: 24),
                _buildDots(),
                const Spacer(flex: 3),
                _buildBrandTag(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outermost glow
            Container(
              width: 200 * _orbScaleAnimation.value,
              height: 200 * _orbScaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(27, 153, 139,
                        _orbGlowAnimation.value * 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Mid ring
            Container(
              width: 140 * _orbScaleAnimation.value,
              height: 140 * _orbScaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(27, 153, 139,
                        _orbGlowAnimation.value * 0.25),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: Color.fromRGBO(
                      27, 153, 139, _orbGlowAnimation.value * 0.3),
                  width: 1,
                ),
              ),
            ),
            // Core orb
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(
                        27, 153, 139, _orbGlowAnimation.value * 0.9 + 0.1),
                    const Color(0xFF0D6E63),
                    const Color(0xFF083D38),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(
                        27, 153, 139, _orbGlowAnimation.value * 0.7),
                    blurRadius: 40 * _orbGlowAnimation.value,
                    spreadRadius: 4,
                    offset: Offset.zero,
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(
                        27, 153, 139, _orbGlowAnimation.value * 0.3),
                    blurRadius: 80,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Color.fromRGBO(
                    254, 255, 254, _orbGlowAnimation.value * 0.6 + 0.4),
                size: 36,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        _steps[_currentStep],
        key: ValueKey(_currentStep),
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: const Color(0xFFFEFFFE),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final phase = (index / 3);
            final rawValue = (_dotsController.value - phase) % 1.0;
            // Creates a wave effect across the three dots
            final t = (rawValue < 0.5)
                ? rawValue * 2
                : (1.0 - rawValue) * 2;
            final opacity = 0.25 + (t * 0.75);
            final scale = 0.7 + (t * 0.5);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromRGBO(27, 153, 139, opacity),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildBrandTag() {
    return Column(
      children: [
        Opacity(
          opacity: 0.4,
          child: Image.asset(
            'assets/logos/wyle_logo_white.png',
            height: 20,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'DIGITAL CHIEF OF STAFF',
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4A7A85),
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
