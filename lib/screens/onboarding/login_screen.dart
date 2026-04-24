import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';
import 'package:wyle_cos/models/user_model.dart';
import 'package:wyle_cos/services/google_auth_service.dart';
import 'package:wyle_cos/services/buddy_api_service.dart';
import 'package:wyle_cos/constants/app_constants.dart';

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

  // Coming-soon overlay
  bool    _showComingSoon     = false;
  String  _comingSoonProvider = '';
  Timer?  _comingSoonTimer;

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
    _comingSoonTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _stagger(int index, Widget child) => FadeTransition(
    opacity: _enterFades[index],
    child: SlideTransition(position: _enterSlides[index], child: child),
  );

  // ── Coming-soon popup ─────────────────────────────────────────────────────

  void _showComingSoonPopup(String providerLabel) {
    _comingSoonTimer?.cancel();
    setState(() {
      _comingSoonProvider = providerLabel;
      _showComingSoon     = true;
    });
    _comingSoonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showComingSoon = false);
    });
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    _setLoading('google');

    try {
      final oauthData =
          await BuddyApiService.instance.startOAuth('google');

      final authUrl = oauthData?['auth_url'];

      if (authUrl == null || authUrl.isEmpty) {
        throw Exception('No auth URL returned');
      }

      // ✅ Always use external browser (NO WebView)
      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _setError('Could not open the sign-in page.');
      }

      // ⛔ DO NOT complete login here
      // Deep link will handle it

    } catch (e) {
      _setError('Google sign-in failed. Try again.');
    } finally {
      _clearLoading();
    }
  }

  Future<void> _completeOAuthTokenSignIn(
    String token, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAuthToken, token);

    Map<String, dynamic>? profile;
    try {
      profile = await BuddyApiService.instance.getMe();
    } catch (_) {
      // Proceed with best-effort fallback profile if /users/me fails.
    }

    final email = profile?['email'] as String? ?? '';
    final fullName = profile?['full_name'] as String? ??
        (email.split('@').first.isNotEmpty ? email.split('@').first : 'Wyle User');
    final publicId = profile?['public_id'] as String? ??
        userId ??
        token.substring(0, token.length.clamp(0, 8));

    final user = UserModel(
      id: publicId,
      name: fullName,
      email: email,
      onboardingComplete: true,
      onboardingStep: 0,
      preferences: const UserPreferences(),
      autonomyTier: 1,
      insights: const UserInsights(),
    );

    await ref.read(appStateProvider.notifier).setAuth(token, user);
    if (mounted) context.go(AppRoutes.main);
  }

  void _signInWithApple() => _showComingSoonPopup('Apple');

  void _signInWithMicrosoft() => _showComingSoonPopup('Microsoft');

  void _signInWithUAEPass() => _showComingSoonPopup('UAE Pass');

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
    String? apiToken,     // JWT from Buddy API OAuth callback (if available)
  }) async {
    // Use API token if we have one; otherwise generate a local placeholder
    final token = apiToken ?? '${provider}_${DateTime.now().millisecondsSinceEpoch}';
    // onboardingComplete: true — skips Preferences & Scan Obligations screens
    final user = UserModel(
      id: id, name: name, email: email,
      onboardingComplete: true, onboardingStep: 0,
      preferences: const UserPreferences(),
      autonomyTier: 1, insights: const UserInsights(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
    await ref.read(appStateProvider.notifier).setAuth(token, user);
    // Best-effort: fetch profile from Buddy API to get linked accounts
    _fetchBuddyProfile();
    if (mounted) {
      _clearLoading();
      context.go(AppRoutes.main);
    }
  }

  /// Fire-and-forget: fetch /v1/users/me after login to sync linked accounts.
  void _fetchBuddyProfile() {
    BuddyApiService.instance.getMe().then((data) {
      // Data available — can update user model or google accounts here
      // For now just silently succeed; future iterations will hydrate state
    }).catchError((_) { /* not yet linked — that's fine */ });
  }

  // ── Manual token bypass (for when OAuth redirect isn't configured yet) ────

  /// Opens a bottom sheet where the user can paste the JWT they see in the
  /// browser after completing Google OAuth.  Calls GET /v1/users/me to verify
  /// the token, then signs in directly — no redirect URL needed.
  void _showTokenDialog() {
    final ctrl = TextEditingController();
    bool verifying = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            Future<void> submit() async {
              final token = ctrl.text.trim();
              if (token.isEmpty) {
                setSheet(() => dialogError = 'Please paste your token first.');
                return;
              }
              setSheet(() { verifying = true; dialogError = null; });

              try {
                // Temporarily persist the token so BuddyApiService can read it
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(AppConstants.keyAuthToken, token);

                // Verify token + fetch real profile
                Map<String, dynamic>? profile;
                try {
                  profile = await BuddyApiService.instance.getMe();
                } catch (_) { /* proceed with defaults */ }

                final email    = profile?['email']     as String? ?? '';
                final fullName = profile?['full_name'] as String?
                              ?? (email.split('@').first.isNotEmpty
                                  ? email.split('@').first
                                  : 'Wyle User');
                final pubId    = profile?['public_id'] as String?
                              ?? token.substring(0, token.length.clamp(0, 8));

                final user = UserModel(
                  id:                 pubId,
                  name:               fullName,
                  email:              email,
                  onboardingComplete: true,
                  onboardingStep:     0,
                  preferences:        const UserPreferences(),
                  autonomyTier:       1,
                  insights:           const UserInsights(),
                );

                await ref.read(appStateProvider.notifier).setAuth(token, user);

                if (mounted) {
                  Navigator.of(sheetCtx).pop(); // close sheet
                  context.go(AppRoutes.main);
                }
              } catch (e) {
                setSheet(() {
                  verifying    = false;
                  dialogError  = 'Token verification failed. Check it and try again.';
                });
              }
            }

            return Padding(
              // Lift sheet above keyboard
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0A2E38),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C4A56),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Paste your access token',
                      style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'After signing in with Google, copy the access_token '
                      'value from the browser and paste it below.',
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF7AACB8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Token input field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF001E29),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1C4A56)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              autofocus: true,
                              maxLines: 3,
                              minLines: 1,
                              style: GoogleFonts.sourceCodePro(
                                fontSize: 12, color: Colors.white70,
                              ),
                              decoration: InputDecoration(
                                hintText: 'eyJ…',
                                hintStyle: GoogleFonts.sourceCodePro(
                                  fontSize: 12, color: const Color(0xFF4A7A85),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                          // Paste from clipboard shortcut
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded,
                                color: Color(0xFF4A7A85), size: 20),
                            tooltip: 'Paste',
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                ctrl.text = data!.text!.trim();
                                ctrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: ctrl.text.length));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: verifying ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B998B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: verifying
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                            : Text(
                                'Verify & Sign In',
                                style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                    const SizedBox(height: 12),
                    // -- Manual token bypass (temporary until backend redirect is set up) --
                    // GestureDetector(
                    //   onTap: _showTokenDialog,
                    //   child: Padding(
                    //     padding: const EdgeInsets.symmetric(vertical: 6),
                    //     child: Text(
                    //       'Already have a token?',
                    //       style: GoogleFonts.poppins(
                    //         fontSize: 11,
                    //         color: const Color(0xFF2A6A78),
                    //         decoration: TextDecoration.underline,
                    //         decorationColor: const Color(0xFF2A6A78),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Coming-soon overlay ────────────────────────────────────────
              if (_showComingSoon) _buildComingSoonOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        // Tap anywhere on the dim layer to dismiss early
        onTap: () {
          _comingSoonTimer?.cancel();
          setState(() => _showComingSoon = false);
        },
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Center(
            child: GestureDetector(
              // Prevent taps on the card from dismissing
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF001A24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFCB9A2D),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCB9A2D).withOpacity(0.25),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB9A2D).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFCB9A2D).withOpacity(0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Color(0xFFCB9A2D),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Coming Soon',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      '$_comingSoonProvider login\nwill be available soon.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF7AACB8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Auto-close hint
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Color(0xFFCB9A2D), size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Closes automatically',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF4A7A85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Language pill ─────────────────────────────────────────────────────────

  Widget _buildLanguagePill() {
    const languages = ['English', 'हिंदी', 'العربية'];

    return PopupMenuButton<String>(
      initialValue: _selectedLang,
      onSelected: (value) => setState(() => _selectedLang = value),
      color: const Color(0xFF003343),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF1C4A56)),
      ),
      itemBuilder: (context) => languages
          .map((lang) => PopupMenuItem<String>(
                value: lang,
                child: Text(
                  lang,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: lang == _selectedLang
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: lang == _selectedLang
                        ? const Color(0xFF1B998B)
                        : Colors.white,
                  ),
                ),
              ))
          .toList(),
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
              child: Image.asset(
                'assets/logos/wyle_logo_white.png',
                height: 92,
                fit: BoxFit.contain,
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
          isLoading: false,
          onTap: _signInWithApple,
          child: const Icon(Icons.apple, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 20),
        _SSOCircle(
          isLoading: false,
          onTap: _signInWithMicrosoft,
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
    return _PressableButton(
      onTap: _signInWithUAEPass,
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
        child: Row(
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
// Google "G" icon — closer to official branded geometry
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(size.width, size.height) / 2 * 0.86;
    final strokeWidth = radius * 0.50;

    // Google brand colours
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    // Arc sequence and angles tuned to match Google's official "G".
    void drawArc(Color color, double startDeg, double sweepDeg) {
      arcPaint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        arcPaint,
      );
    }

    drawArc(red, -40, 180);
    drawArc(yellow, 140, 76);
    drawArc(green, 216, 106);
    drawArc(blue, 322, 64);

    // Signature horizontal blue bar.
    final barHeight = strokeWidth * 0.56;
    final barLeft = cx + radius * 0.05;
    final barRight = cx + radius * 1.02;
    final barRect = Rect.fromLTRB(
      barLeft,
      cy - barHeight / 2,
      barRight,
      cy + barHeight / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(barHeight / 2)),
      Paint()..color = blue..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _OAuthCaptureResult {
  final String token;
  final String? userId;
  const _OAuthCaptureResult({
    required this.token,
    this.userId,
  });
}

class _GoogleOAuthWebViewScreen extends StatefulWidget {
  final String initialUrl;
  const _GoogleOAuthWebViewScreen({required this.initialUrl});

  @override
  State<_GoogleOAuthWebViewScreen> createState() => _GoogleOAuthWebViewScreenState();
}

class _GoogleOAuthWebViewScreenState extends State<_GoogleOAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            _tryFinishWithRaw(request.url);
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            _tryFinishWithRaw(url);
            if (_isCapturing) return;
            try {
              final body = await _controller.runJavaScriptReturningResult(
                'document.body ? document.body.innerText : ""',
              );
              _tryFinishWithRaw(_normalizeJsResult(body));
            } catch (_) {}
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _tryFinishWithRaw(String raw) {
    if (_isCapturing) return;
    final result = _extractOAuthResult(raw);
    if (result == null) return;
    _isCapturing = true;
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  static String _normalizeJsResult(Object jsValue) {
    final s = jsValue.toString().trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is String) return decoded;
      } catch (_) {}
    }
    return s;
  }

  static _OAuthCaptureResult? _extractOAuthResult(String raw) {
    if (raw.isEmpty) return null;

    try {
      final uri = Uri.parse(raw);
      String? token = uri.queryParameters['auth_token'] ??
          uri.queryParameters['token'] ??
          uri.queryParameters['access_token'];
      String? userId = uri.queryParameters['user_id'] ?? uri.queryParameters['user_public_id'];

      // Support hash-based callback URLs: /#/auth-callback?auth_token=...
      if ((token == null || token.isEmpty) && uri.fragment.contains('?')) {
        final queryPart = uri.fragment.substring(uri.fragment.indexOf('?') + 1);
        final fragmentQuery = Uri.splitQueryString(queryPart);
        token = fragmentQuery['auth_token'] ??
            fragmentQuery['token'] ??
            fragmentQuery['access_token'];
        userId ??= fragmentQuery['user_id'] ?? fragmentQuery['user_public_id'];
      }
      if (token != null && token.isNotEmpty) {
        return _OAuthCaptureResult(token: token, userId: userId);
      }
    } catch (_) {}

    final tokenMatch = RegExp(r'"(?:auth_token|access_token|token)"\s*:\s*"([^"]+)"')
        .firstMatch(raw);
    if (tokenMatch != null) {
      final token = tokenMatch.group(1)!;
      final userIdMatch =
          RegExp(r'"(?:user_public_id|user_id)"\s*:\s*"([^"]+)"').firstMatch(raw);
      return _OAuthCaptureResult(
        token: token,
        userId: userIdMatch?.group(1),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001E29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001E29),
        title: Text(
          'Google Sign-In',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
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
