import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class WyleApp extends ConsumerWidget {
  const WyleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // routerProvider creates GoRouter exactly once — read is sufficient.
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title:            'Wyle',
      debugShowCheckedModeBanner: false,
      theme:            AppTheme.dark,
      routerConfig:     router,
      builder: (context, child) {
        // Enforce font scaling limits so layout doesn't break on accessibility sizes
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
