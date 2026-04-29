import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Top-level handler for FCM messages received while the app is terminated.
/// Must be a top-level function (not a class method) — Firebase requirement.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised before any Firebase call in background isolate
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Manages Firebase initialisation and FCM device-token lifecycle.
///
/// Usage:
///   1. Call [NotificationService.init] once in main() after Firebase.initializeApp().
///   2. Call [NotificationService.getToken] after login to get the FCM token
///      and register it with the backend via POST /v1/users/me/devices.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialised = false;

  // ── Foreground message stream ──────────────────────────────────────────────
  /// Broadcast stream of FCM messages received while the app is in the
  /// foreground.  UI widgets listen to this to show in-app banners.
  final _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get foregroundStream =>
      _foregroundController.stream;

  // ── Init ───────────────────────────────────────────────────────────────────

  /// Initialise FCM, request permission, and register the background handler.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Register background handler (Android/iOS only — web has no background)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    }

    // Request permission (required on iOS; on Android 13+ shows a dialog too)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      announcement:  false,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
    );

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Android: show heads-up banners while app is in foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for foreground messages — broadcast to UI via foregroundStream
    // so widgets can show in-app banners without a separate local-notification
    // plugin.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message received');
      debugPrint('[FCM]   title : ${message.notification?.title}');
      debugPrint('[FCM]   body  : ${message.notification?.body}');
      debugPrint('[FCM]   data  : ${message.data}');
      _foregroundController.add(message); // notify UI
    });

    // Listen for notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] App opened from background notification: ${message.data}');
      // TODO: navigate to relevant screen based on message.data
    });

    // Check if app was launched by tapping a notification (terminated state)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] App launched from terminated notification: ${initial.data}');
      // TODO: navigate to relevant screen based on initial.data
    }
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  /// Returns the FCM registration token for this device, or null on error.
  /// On token refresh, [onTokenRefresh] is called with the new token.
  Future<String?> getToken({void Function(String token)? onTokenRefresh}) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] Device token: $token');

      // Listen for token rotation (FCM rotates tokens periodically)
      if (onTokenRefresh != null) {
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          debugPrint('[FCM] Token refreshed: $newToken');
          onTokenRefresh(newToken);
        });
      }

      return token;
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
      return null;
    }
  }
}
