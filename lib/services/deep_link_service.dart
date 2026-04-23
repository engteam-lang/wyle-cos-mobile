import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();

  void init(Function(Uri uri) onLink) {
    _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) {
        onLink(uri);
      }
    });
  }
}