import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/app_state.dart';
import 'buddy_api_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<void> handleOAuthCallback({
    required Uri uri,
    required WidgetRef ref,
  }) async {
    final token = uri.queryParameters['auth_token'];

    if (token == null || token.isEmpty) {
      throw Exception('Missing auth token');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAuthToken, token);

    final profile = await BuddyApiService.instance.getMe();

    final user = UserModel(
      id: profile['public_id'],
      name: profile['full_name'],
      email: profile['email'],
      onboardingComplete: true,
      onboardingStep: 0,
      preferences: UserPreferences(), // ❗ remove const
      autonomyTier: 1,
      insights: UserInsights(), // ❗ remove const
    );

    await ref.read(appStateProvider.notifier).setAuth(token, user);
  }
}