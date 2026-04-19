import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';
import 'package:wyle_cos/models/user_model.dart';
import 'package:wyle_cos/services/google_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Login Screen — matches Figma design exactly
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {

  bool _isLoading = false;
  String? _loadingProvider;
  String? _errorMessage;
  String _selectedLang = 'English';

  // Shimmer on WYLE text
  late AnimationController _shimmerCtrl;

  // Staggered entrance — 6 layers
  late List<AnimationController> _enterCtrls;
  late List<Animation<double>>   _enterFades;
  late List<Animation<Offset>>   _enterSlides;

  static const _staggerDelay = 120; // ms between each element

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 6 staggered elements:
    // 0 = language pill, 1 = logo, 2 = SSO row,
    // 3 = OR divider, 4 = UAE button, 5 = footer
    _enterCtrls = List.generate(6, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    ));
    _enterFades = _enterCtrls.map((c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut)
    ).toList();
    _enterSlides = _enterCtrls.map((c) =>
      Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut))
    ).toList();

    // Fire them with stagger
    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * _staggerDelay), () {
        if (mounted) _enterCtrls[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    for (final c in _enterCtrls) c.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _stagger(int index, Widget child) => FadeTransition(
    opacity: _enterFades[index],
    child: SlideTransition(position: _enterSlides[index], child: child),
  );

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    _setLoading('google');
    try {
      final result = await GoogleAuthService.instance.signIn();
      if (!mounted) return;
      if (result.success) {
        await _completeAuth(
          id: result.id ?? result.email,
          name: result.displayName ?? result.email.split('@').first,
          email: result.email,
          provider: 'google',
        );
      } else {
        _setError(result.error == 'Cancelled'
            ? 'Sign-in was cancelled.'
            : 'Google sign-in failed. Try again.');
      }
    } catch (_) {
      _setError('Google sign-in failed. Try again.');
    } finally {
      _clearLoading();
    }
  }

  Future<void> _signInWithApple() async {
    _setLoading('apple');
    await Future.delayed(const Duration(milliseconds: 600));
    // TODO: sign_in_with_apple package
    await _completeAuth(
      id: 'apple_demo', name: 'Demo User',
      email: 'demo@icloud.com', provider: 'apple',
    );
  }

  Future<void> _signInWithMicrosoft() async {
    _setLoading('microsoft');
    await Future.delayed(const Duration(milliseconds: 600));
    // TODO: MSAL
    await _completeAuth(
      id: 'ms_demo', name: 'Demo User',
      email: 'demo@outlook.com', provider: 'microsoft',
    );
  }

  Future<void> _signInWithUAEPass() async {
    _setLoading('uaepass');
    await Future.delayed(const Duration(milliseconds: 600));
    // TODO: UAE Pass OAuth
    await _completeAuth(
      id: 'uae_demo', name: 'Demo User',
      email: 'demo@uaepass.ae', provider: 'uaepass',
    );
  }

  void _setLoading(String p) => setState(() {
    _isLoading = true; _loadingProvider = p; _errorMessage = null;
  });
  void _clearLoading() {
    if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
  }
  void _setError(String msg) {
    if (mounted) setState(() => _errorMessage = msg);
  }

  Future<void> _completeAuth({
    required String id, required String name,
    required String email, required String provider,
  }) async {
    final token = '${provider}_${DateTime.now().millisecondsSinceEpoch}';
    final user = UserModel(
      id: id, name: name, email: email,
      onboardingComplete: false, onboardingStep: 1,
      preferences: const UserPreferences(),
      autonomyTier: 1, insights: const UserInsights(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
    await ref.read(appStateProvider.notifier).setAuth(token, user);
    if (mounted) {
      _clearLoading();
      context.go(AppRoutes.preparation);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF002F3A),
              Color(0xFF001E29),
              Color(0xFF000D12),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Language selector — top right
              Positioned(
                top: 12, right: 16,
                child: _stagger(0, _buildLanguagePill()),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    _stagger(1, _buildLogo()),
                    const Spacer(flex: 4),
                    _stagger(2, _buildSSORow()),
                    const SizedBox(height: 32),
                    _stagger(3, _buildOrDivider()),
                    const SizedBox(height: 32),
                    _stagger(4, _buildUAEPassButton()),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _buildErrorText(),
                    ],
                    const Spacer(flex: 3),
                    _stagger(5, _buildFooter()),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Language pill ─────────────────────────────────────────────────────────

  Widget _buildLanguagePill() {
    return GestureDetector(
      onTap: () {
        // TODO: show language picker
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0A3040),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF1C4A56), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedLang,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Logo with shimmer ─────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) {
            final t = _shimmerCtrl.value;
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Colors.white,
                  Colors.white,
                  Color(0xFF7FFFF4),
                  Colors.white,
                  Colors.white,
                ],
                stops: [
                  0.0,
                  (t - 0.25).clamp(0.0, 1.0),
                  t.clamp(0.0, 1.0),
                  (t + 0.25).clamp(0.0, 1.0),
                  1.0,
                ],
              ).createShader(bounds),
              child: Text(
                'WYLE',
                style: GoogleFonts.poppins(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Your AI Chief of Staff',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF7AACB8),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Three SSO circles ─────────────────────────────────────────────────────

  Widget _buildSSORow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SSOCircle(
          isLoading: _loadingProvider == 'google',
          onTap: _isLoading ? null : _signInWithGoogle,
          child: const _GoogleIcon(),
        ),
        const SizedBox(width: 20),
        _SSOCircle(
          isLoading: _loadingProvider == 'apple',
          onTap: _isLoading ? null : _signInWithApple,
          child: const Icon(Icons.apple, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 20),
        _SSOCircle(
          isLoading: _loadingProvider == 'microsoft',
          onTap: _isLoading ? null : _signInWithMicrosoft,
          child: const _MicrosoftIcon(),
        ),
      ],
    );
  }

  // ── OR divider ────────────────────────────────────────────────────────────

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF1C4A56))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text('OR',
            style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: const Color(0xFF4A7A85), letterSpacing: 2,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF1C4A56))),
      ],
    );
  }

  // ── UAE Pass button ───────────────────────────────────────────────────────

  Widget _buildUAEPassButton() {
    final isLoading = _loadingProvider == 'uaepass';
    return _PressableButton(
      onTap: _isLoading ? null : _signInWithUAEPass,
      child: Container(
        width: double.infinity, height: 58,
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
              blurRadius: 22, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isLoading
            ? const Center(child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Color(0xFF001A24),
                ),
              ))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // "AE" badge — UAE Pass logo style
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001A24).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'AE',
                      style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: const Color(0xFF001A24),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with UAE Pass',
                    style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: const Color(0xFF001A24),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildErrorText() => Text(
    _errorMessage!,
    textAlign: TextAlign.center,
    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFFF6B6B)),
  );

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.lock_outline_rounded, color: Color(0xFF4A7A85), size: 13),
      const SizedBox(width: 6),
      Text(
        'Secure authentication · No passwords required',
        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF4A7A85)),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SSO Circle button with press scale animation
// ─────────────────────────────────────────────────────────────────────────────
class _SSOCircle extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onTap;
  final Widget child;
  const _SSOCircle({required this.isLoading, required this.onTap, required this.child});
  @override State<_SSOCircle> createState() => _SSOCircleState();
}

class _SSOCircleState extends State<_SSOCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.90, upperBound: 1.0, value: 1.0);
  }
  @override void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.reverse(),
      onTapUp:   (_) { _press.forward(); widget.onTap?.call(); },
      onTapCancel: () => _press.forward(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(scale: _press.value, child: child),
        child: Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0A2E38),
            border: Border.all(color: const Color(0xFF1C4A56), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: widget.isLoading
              ? const Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF1B998B))))
              : Center(child: widget.child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pressable scale wrapper for UAE Pass button
// ─────────────────────────────────────────────────────────────────────────────
class _PressableButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _PressableButton({required this.onTap, required this.child});
  @override State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.97, upperBound: 1.0, value: 1.0);
  }
  @override void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { if (widget.onTap != null) _press.reverse(); },
      onTapUp:   (_) { _press.forward(); widget.onTap?.call(); },
      onTapCancel: () => _press.forward(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(scale: _press.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google "G" icon
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    // Draw a proper Google G using nested containers + clip
    return SizedBox(
      width: 28, height: 28,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 1;
    final sw = size.width * 0.165;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - sw / 2);

    Paint p(Color c) => Paint()
      ..color = c
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    // Angles: 0 = right, π/2 = bottom, π = left, 3π/2 = top
    // Red:   from -110° to  10°  (top-right arc)
    // Yellow: from  10° to  90°  (bottom-right)
    // Green:  from  90° to 210°  (bottom-left)
    // Blue:   from 210° to 250°  (left, stub)
    const deg = 3.14159265 / 180;
    canvas.drawArc(rect, -110 * deg, 120 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect,   10 * deg,  80 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect,   90 * deg, 120 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect,  210 * deg,  40 * deg, false, p(const Color(0xFF4285F4)));

    // Horizontal bar of the G (blue)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = sw * 0.9
      ..strokeCap = StrokeCap.butt;
    final barY  = cy;
    final barX1 = cx;
    final barX2 = cx + r - sw / 2;
    canvas.drawLine(Offset(barX1, barY), Offset(barX2, barY), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Microsoft ⊞ icon
// ─────────────────────────────────────────────────────────────────────────────
class _MicrosoftIcon extends StatelessWidget {
  const _MicrosoftIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26, height: 26,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2.5,
        crossAxisSpacing: 2.5,
        padding: EdgeInsets.zero,
        children: [
          Container(color: const Color(0xFFF25022)),
          Container(color: const Color(0xFF7FBA00)),
          Container(color: const Color(0xFF00A4EF)),
          Container(color: const Color(0xFFFFB900)),
        ],
      ),
    );
  }
}
