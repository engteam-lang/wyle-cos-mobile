import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/app_state.dart';
import 'buddy_api_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Called by [DeepLinkService] when the OS delivers the OAuth redirect URI.
  ///
  /// Expected URI format:
  ///   com.wyle.buddy://oauth-callback?auth_token=<JWT>&user_public_id=<id>
  Future<void> handleOAuthCallback({
    required Uri uri,
    required WidgetRef ref,
  }) async {
    // ── 1. Extract token ──────────────────────────────────────────────────────
    final token = uri.queryParameters['auth_token'] ??
        uri.queryParameters['token'] ??
        uri.queryParameters['access_token'];

    if (token == null || token.isEmpty) {
      throw Exception('OAuth callback missing auth_token parameter');
    }

    final userId = uri.queryParameters['user_public_id'] ??
        uri.queryParameters['user_id'];

    // ── 2. Persist token so API interceptor can attach it ─────────────────────
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAuthToken, token);

    // ── 3. Fetch real profile — proceed gracefully if /users/me fails ─────────
    Map<String, dynamic>? profile;
    try {
      profile = await BuddyApiService.instance.getMe();
    } catch (_) {
      // API unreachable or token not yet valid — build user from token data
    }

    final email    = profile?['email']     as String? ?? '';
    final fullName = profile?['full_name'] as String?
        ?? (email.isNotEmpty ? email.split('@').first : 'Wyle User');
    final pubId    = profile?['public_id'] as String?
        ?? userId
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
  }
}
