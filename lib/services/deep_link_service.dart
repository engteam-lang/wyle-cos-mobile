import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Listens for incoming deep links from the OS (Android only).
///
/// Uses [AppLinks.uriLinkStream] which covers both:
///  - Warm start: app is already running when the deep link arrives.
///  - Cold start: app_links 6.x emits the launch URI as the first stream
///    event when the app is opened via a deep link.
///
/// On web, deep links are not applicable — this service is a no-op.
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  /// Call once in [WyleApp.initState].
  void init(void Function(Uri uri) onLink) {
    // Deep links are mobile-only — skip entirely on web.
    if (kIsWeb) return;

    AppLinks().uriLinkStream.listen((uri) {
      onLink(uri);
    });
  }
}
