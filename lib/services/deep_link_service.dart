import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Listens for incoming deep links from the OS (Android only).
///
/// Two cases handled:
///  1. Cold start — app was closed; OS launches it with a deep link URI.
///     [AppLinks.getLatestAppLink] gives us that URI once on startup.
///  2. Warm / foreground — app already running; OS delivers the URI via
///     [AppLinks.uriLinkStream].
///
/// On web, deep links are not applicable — this service does nothing.
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();

  /// Call once in [WyleApp.initState].
  /// [onLink] is invoked for both cold-start and warm-start deep links.
  Future<void> init(void Function(Uri uri) onLink) async {
    // Deep links are mobile-only — skip entirely on web.
    if (kIsWeb) return;

    // ── Case 1: cold-start ────────────────────────────────────────────────────
    // If the app was launched by tapping a deep link, getLatestAppLink()
    // returns that URI.  Use microtask so the widget tree is ready.
    try {
      final initial = await _appLinks.getLatestAppLink();
      if (initial != null) {
        Future.microtask(() => onLink(initial));
      }
    } catch (_) {
      // Safe to ignore — not all platforms / versions support this.
    }

    // ── Case 2: warm / foreground ─────────────────────────────────────────────
    _appLinks.uriLinkStream.listen(onLink);
  }
}
