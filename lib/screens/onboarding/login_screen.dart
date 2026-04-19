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
// Login Screen — SSO only, matching Figma design
// Background: dark teal-to-black gradient
// Providers: Google · Apple · Microsoft (circle icons) + UAE Pass (full-width)
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _loadingProvider; // 'google' | 'apple' | 'microsoft' | 'uaepass'
  String? _errorMessage;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Auth helpers ─────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'google';
      _errorMessage = null;
    });
    try {
      final account = await GoogleAuthService.instance.signIn();
      if (!mounted) return;
      if (account != null) {
        await _completeAuth(
          id: account.id,
          name: account.displayName ?? account.email.split('@').first,
          email: account.email,
          provider: 'google',
        );
      } else {
        setState(() => _errorMessage = 'Google sign-in was cancelled.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _loadingProvider = null; });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'apple';
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    // TODO: Implement Apple Sign-In via sign_in_with_apple package
    await _completeAuth(
      id: 'apple_demo_001',
      name: 'Demo User',
      email: 'demo@icloud.com',
      provider: 'apple',
    );
  }

  Future<void> _signInWithMicrosoft() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'microsoft';
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    // TODO: Implement Microsoft MSAL sign-in
    await _completeAuth(
      id: 'microsoft_demo_001',
      name: 'Demo User',
      email: 'demo@outlook.com',
      provider: 'microsoft',
    );
  }

  Future<void> _signInWithUAEPass() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'uaepass';
      _errorMessage = null;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    // TODO: Implement UAE Pass OAuth
    await _completeAuth(
      id: 'uaepass_demo_001',
      name: 'Demo User',
      email: 'demo@uaepass.ae',
      provider: 'uaepass',
    );
  }

  Future<void> _completeAuth({
    required String id,
    required String name,
    required String email,
    required String provider,
  }) async {
    final token = '${provider}_token_${DateTime.now().millisecondsSinceEpoch}';
    final user = UserModel(
      id: id,
      name: name,
      email: email,
      onboardingComplete: false,
      onboardingStep: 1,
      preferences: const UserPreferences(),
      autonomyTier: 1,
      insights: const UserInsights(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);

    await ref.read(appStateProvider.notifier).setAuth(token, user);

    if (mounted) {
      setState(() { _isLoading = false; _loadingProvider = null; });
      context.go(AppRoutes.preparation);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF002F3A), // Nocturne
              Color(0xFF001A24),
              Color(0xFF000D12),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _buildLogo(),
                  const Spacer(flex: 3),
                  _buildSSORow(),
                  const SizedBox(height: 28),
                  _buildOrDivider(),
                  const SizedBox(height: 28),
                  _buildUAEPassButton(),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) _buildErrorText(),
                  const Spacer(flex: 2),
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'WYLE',
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your AI Chief of Staff',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF8FB8BF),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ── Three SSO Circles ────────────────────────────────────────────────────

  Widget _buildSSORow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SSOCircle(
          provider: 'google',
          isLoading: _loadingProvider == 'google',
          onTap: _isLoading ? null : _signInWithGoogle,
          child: _GoogleIcon(),
        ),
        const SizedBox(width: 24),
        _SSOCircle(
          provider: 'apple',
          isLoading: _loadingProvider == 'apple',
          onTap: _isLoading ? null : _signInWithApple,
          child: const Icon(Icons.apple, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 24),
        _SSOCircle(
          provider: 'microsoft',
          isLoading: _loadingProvider == 'microsoft',
          onTap: _isLoading ? null : _signInWithMicrosoft,
          child: _MicrosoftIcon(),
        ),
      ],
    );
  }

  // ── OR Divider ────────────────────────────────────────────────────────────

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: const Color(0xFF1C4A56)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A8A96),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: const Color(0xFF1C4A56)),
        ),
      ],
    );
  }

  // ── UAE Pass Button ───────────────────────────────────────────────────────

  Widget _buildUAEPassButton() {
    final isLoading = _loadingProvider == 'uaepass';
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithUAEPass,
      child: AnimatedOpacity(
        opacity: _isLoading && !isLoading ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1B998B), // teal
                Color(0xFF4DBF7A), // mid-green
                Color(0xFFCBD842), // yellow-green
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B998B).withOpacity(0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF001A24),
                  ),
                )
              else ...[
                // UAE flag square icon
                Container(
                  width: 28, height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.transparent,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Column(
                      children: [
                        Expanded(child: Container(color: const Color(0xFF00732F))),
                        Expanded(child: Container(color: Colors.white)),
                        Expanded(child: Container(color: Colors.black)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Continue with UAE Pass',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF001A24),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildErrorText() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        _errorMessage!,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFFFF6B6B),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF4A7A85), size: 13),
        const SizedBox(width: 6),
        Text(
          'Secure authentication · No passwords required',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF4A7A85),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SSO Circle Button
// ─────────────────────────────────────────────────────────────────────────────

class _SSOCircle extends StatefulWidget {
  final String provider;
  final bool isLoading;
  final VoidCallback? onTap;
  final Widget child;

  const _SSOCircle({
    required this.provider,
    required this.isLoading,
    required this.onTap,
    required this.child,
  });

  @override
  State<_SSOCircle> createState() => _SSOCircleState();
}

class _SSOCircleState extends State<_SSOCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) => _pressCtrl.forward(),
      onTapCancel: () => _pressCtrl.forward(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) => Transform.scale(
          scale: _pressCtrl.value,
          child: child,
        ),
        child: Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0A2E38),
            border: Border.all(
              color: const Color(0xFF1C4A56),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1B998B),
                    ),
                  ),
                )
              : Center(child: widget.child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google "G" Icon
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the circular arcs in Google colors
    final colors = [
      const Color(0xFFEA4335), // red - top
      const Color(0xFFFBBC05), // yellow - bottom-left
      const Color(0xFF34A853), // green - bottom
      const Color(0xFF4285F4), // blue - left
    ];

    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Red arc (top to right)
    canvas.drawArc(
      rect, -1.57, 1.57, false,
      Paint()..color = colors[0]..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
    // Yellow arc
    canvas.drawArc(
      rect, 0.0, 1.57, false,
      Paint()..color = colors[1]..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
    // Green arc
    canvas.drawArc(
      rect, 1.57, 1.0, false,
      Paint()..color = colors[2]..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
    // Blue arc
    canvas.drawArc(
      rect, 2.57, 1.0, false,
      Paint()..color = colors[3]..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );

    // Blue horizontal line (the bar of the G)
    final barY = center.dy;
    final barLeft = center.dx;
    final barRight = center.dx + radius - strokeWidth / 2;
    canvas.drawLine(
      Offset(barLeft, barY),
      Offset(barRight, barY),
      Paint()..color = colors[3]..strokeWidth = strokeWidth * 0.85..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Microsoft ⊞ Icon
// ─────────────────────────────────────────────────────────────────────────────

class _MicrosoftIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24, height: 24,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        padding: EdgeInsets.zero,
        children: [
          Container(color: const Color(0xFFF25022)),  // red
          Container(color: const Color(0xFF7FBA00)),  // green
          Container(color: const Color(0xFF00A4EF)),  // blue
          Container(color: const Color(0xFFFFB900)),  // yellow
        ],
      ),
    );
  }
}
