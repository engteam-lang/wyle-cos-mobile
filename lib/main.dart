import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';
import 'services/deep_link_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase (required before any Firebase service call)
  try {
    await Firebase.initializeApp();
    await NotificationService.instance.init();
  } catch (e) {
    // Firebase init can fail if google-services.json is missing in debug builds
    // The app continues to work — push notifications simply won't be available
    debugPrint('[Firebase] Init failed: $e');
  }

  // On web, surface any uncaught Flutter errors to the browser console so
  // blank-screen issues are visible even in release builds.
  if (kIsWeb) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // ignore: avoid_print
      print('[Flutter error] ${details.exceptionAsString()}\n${details.stack}');
    };
  }

  // Load .env file (API keys)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env not found — proceed without it (keys can be set via env vars)
    if (kIsWeb) {
      // ignore: avoid_print
      print('[Wyle] dotenv load failed: $e — continuing with default config');
    }
  }

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    statusBarBrightness:      Brightness.dark,
  ));

  // Portrait orientation only (matches RN app behaviour)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    // Riverpod root
    const ProviderScope(child: WyleApp()),
  );
}

class WyleApp extends ConsumerStatefulWidget {
  const WyleApp({super.key});

  @override
  ConsumerState<WyleApp> createState() => _WyleAppState();
}

class _WyleAppState extends ConsumerState<WyleApp> {

  @override
  void initState() {
    super.initState();

    DeepLinkService.instance.init(_handleDeepLink);
  }

  bool _isHandlingLink = false;

  Future<void> _handleDeepLink(Uri uri) async {
    if (_isHandlingLink) return;
    _isHandlingLink = true;

    try {
      await Future.microtask(() async {
        if (uri.host == 'oauth-callback') {
          await AuthService.instance.handleOAuthCallback(
            uri: uri,
            ref: ref,
          );

          if (mounted) {
            ref.read(routerProvider).go(AppRoutes.main);
          }
        }
      });
    } finally {
      _isHandlingLink = false;
    }
  }

  Future<void> _handleOAuth(Uri uri) async {

    try {
      // TEMP store so API can use it

      if (mounted) {
        ref.read(routerProvider).go(AppRoutes.main);
      }

    } catch (e) {
      debugPrint('❌ OAuth deep link failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Wyle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.15),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
