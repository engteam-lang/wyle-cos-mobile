import 'package:app_links/app_links.dart';

/// Listens for incoming deep links from the OS.
///
/// Two cases:
///  1. Cold start — app was closed; OS launches it with a deep link URI.
///     [AppLinks.getInitialAppLink] gives us that URI once on startup.
///  2. Warm/foreground — app is already running; OS delivers the URI via a
///     stream event.  [AppLinks.uriLinkStream] covers this case.
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();

  /// Call once in [WyleApp.initState].
  /// [onLink] is invoked for both cold-start and warm-start deep links.
  Future<void> init(void Function(Uri uri) onLink) async {
    // ── Case 1: cold-start ────────────────────────────────────────────────────
    // If the app was launched by tapping a deep link, getInitialAppLink()
    // returns that URI.  Delay by one frame so the widget tree is ready.
    try {
      final initial = await _appLinks.getInitialAppLink();
      if (initial != null) {
        // Use addPostFrameCallback so routing context is available
        Future.microtask(() => onLink(initial));
      }
    } catch (_) {
      // Not all platforms support getInitialAppLink — safe to ignore.
    }

    // ── Case 2: warm / foreground ─────────────────────────────────────────────
    _appLinks.uriLinkStream.listen(onLink);
  }
}
