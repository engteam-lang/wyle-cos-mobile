import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wyle_cos/navigation/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SplashScreen
//
// Animation sequence:
//   Phase 1 (0 → 1.2 s)  — image fades in while scaling 0.90 → 1.0
//   Phase 2 (1.2 → 3.0 s) — teal shimmer sweeps left-to-right across logo (once)
//   Phase 3 (3.0 s)       — navigate to welcome / login
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Phase 1 — fade + scale enter
  late final AnimationController _enterCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;

  // Phase 2 — shimmer sweep (plays once after enter)
  late final AnimationController _shimmerCtrl;
  late final Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();

    // ── Phase 1: enter ──────────────────────────────────────────────────────
    _enterCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
    );

    // ── Phase 2: shimmer sweep ──────────────────────────────────────────────
    _shimmerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    );
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve:  Curves.easeInOut,
    );

    // Kick off enter animation immediately
    _enterCtrl.forward();

    // Once enter completes → play shimmer once
    _enterCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _shimmerCtrl.forward();
      }
    });

    // Navigate after total 3.2 s
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) context.go(AppRoutes.welcome);
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: AnimatedBuilder(
              animation: _shimmerAnim,
              builder: (context, child) {
                // Shimmer: a teal highlight band sweeps left → right across the
                // image.  t goes 0 → 1; band is ~40 % of width wide.
                final t = _shimmerAnim.value;

                return ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    // Band centre moves from -30 % to 130 % of image width
                    final centre = bounds.width * (-0.3 + t * 1.6);
                    const half   = 0.20; // half-width of band as fraction

                    return LinearGradient(
                      begin:  Alignment.centerLeft,
                      end:    Alignment.centerRight,
                      colors: const [
                        Colors.transparent,
                        Color(0x001B998B),
                        Color(0x551B998B), // teal highlight peak
                        Color(0x001B998B),
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        ((centre / bounds.width) - half).clamp(0.0, 1.0),
                        (centre / bounds.width).clamp(0.0, 1.0),
                        ((centre / bounds.width) + half).clamp(0.0, 1.0),
                        1.0,
                      ],
                    ).createShader(bounds);
                  },
                  child: child!,
                );
              },
              // The logo image — constrained to 88 % of screen width
              child: Image.asset(
                'assets/logos/wyle_splash.png',
                width:    screenW * 0.92,
                fit:      BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
