import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/user_model.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';
import '../../services/buddy_api_service.dart';
import '../../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthCallbackScreen
// Handles the redirect back from api.wyle.ai after OAuth.
// Expected URL:  .../#/auth-callback?token=JWT&user_id=xxx
// ─────────────────────────────────────────────────────────────────────────────
class AuthCallbackScreen extends ConsumerStatefulWidget {
  final String? token;
  final String? userId;

  const AuthCallbackScreen({super.key, this.token, this.userId});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  String _status = 'Completing sign-in…';
  bool   _error  = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // ── 1. Extract token from widget params or current URL ─────────────────
      String? token = widget.token;

      if ((token == null || token.isEmpty) && kIsWeb) {
        // Read from the browser URL directly as a fallback
        token = _extractTokenFromUrl();
      }

      if (token == null || token.isEmpty) {
        setState(() { _status = 'Sign-in failed — no token received.'; _error = true; });
        return;
      }

      // ── 2. Save token ──────────────────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAuthToken, token);

      // ── 3. Fetch real profile from /v1/users/me ────────────────────────────
      setState(() => _status = 'Loading your profile…');
      Map<String, dynamic>? profile;
      try {
        profile = await BuddyApiService.instance.getMe();
      } catch (_) { /* proceed with partial data */ }

      final email    = profile?['email']     as String? ?? '';
      final fullName = profile?['full_name'] as String? ?? email.split('@').first;
      final pubId    = profile?['public_id'] as String? ?? widget.userId ?? token.substring(0, 8);

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

      if (mounted) context.go(AppRoutes.main);

    } catch (e) {
      if (mounted) setState(() { _status = 'Sign-in error: $e'; _error = true; });
    }
  }

  /// Reads ?token= from the current browser URL (web only).
  String? _extractTokenFromUrl() {
    if (!kIsWeb) return null;
    try {
      // ignore: undefined_prefixed_name, avoid_web_libraries_in_flutter
      final href = Uri.base.toString();
      final uri  = Uri.parse(href);
      return uri.queryParameters['token']
          ?? uri.queryParameters['access_token'];
    } catch (_) {
      return null;
    }
  }

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
            colors: [Color(0xFF002F3A), Color(0xFF001E29), Color(0xFF000D12)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_error)
                    const SizedBox(
                      width: 48, height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFF1B998B), strokeWidth: 3),
                    )
                  else
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFFF6B6B), size: 48),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _error ? const Color(0xFFFF6B6B) : Colors.white70,
                    ),
                  ),
                  if (_error) ...[
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.login),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B998B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF1B998B).withOpacity(0.5)),
                        ),
                        child: Text('Back to Login',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1B998B))),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
