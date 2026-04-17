import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  final bool success;
  final String email;
  final String? accessToken;
  final String? error;

  const GoogleAuthResult({
    required this.success,
    this.email = '',
    this.accessToken,
    this.error,
  });
}

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  // Lazy so it's created after dotenv loads.
  // On web, clientId must be passed explicitly (no google-services.json).
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? (dotenv.env['EXPO_PUBLIC_GOOGLE_CLIENT_ID']?.isNotEmpty == true
            ? dotenv.env['EXPO_PUBLIC_GOOGLE_CLIENT_ID']
            : null)
        : null,
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/calendar.readonly',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _currentUser;

  /// Sign in with Google and return the result
  Future<GoogleAuthResult> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleAuthResult(success: false, error: 'Cancelled');
      }

      final auth = await account.authentication;
      _currentUser = account;

      return GoogleAuthResult(
        success:     true,
        email:       account.email,
        accessToken: auth.accessToken,
      );
    } catch (e) {
      return GoogleAuthResult(success: false, error: e.toString());
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Check if currently signed in
  Future<GoogleAuthResult?> checkSignIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;

      final auth = await account.authentication;
      _currentUser = account;

      return GoogleAuthResult(
        success:     true,
        email:       account.email,
        accessToken: auth.accessToken,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get the current access token (refreshes if needed)
  Future<String?> getAccessToken() async {
    if (_currentUser == null) return null;
    try {
      final auth = await _currentUser!.authentication;
      return auth.accessToken;
    } catch (_) {
      return null;
    }
  }

  String? get currentEmail => _currentUser?.email;
}
