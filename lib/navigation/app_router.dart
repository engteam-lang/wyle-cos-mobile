import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/preferences_screen.dart';
import '../screens/onboarding/obligation_scan_screen.dart';
import '../screens/onboarding/ready_screen.dart';
import '../screens/onboarding/preparation_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/obligations/obligations_screen.dart';
import '../screens/buddy/buddy_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/brain_dump/brain_dump_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/food/food_screen.dart';
import '../screens/connect/connect_screen.dart';
import '../screens/brief/morning_brief_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/main/main_screen.dart';

// ── Route names ───────────────────────────────────────────────────────────────
class AppRoutes {
  static const splash         = '/';
  static const welcome        = '/welcome';
  static const login          = '/login';
  static const preferences    = '/preferences';
  static const obligationScan = '/obligation-scan';
  static const ready          = '/ready';
  static const preparation    = '/preparation';
  static const main           = '/main';
  static const home           = '/main/home';
  static const obligations    = '/main/obligations';
  static const buddy          = '/main/buddy';
  static const wallet         = '/main/wallet';
  static const insights       = '/main/insights';
  static const brainDump      = '/brain-dump';
  static const calendar       = '/calendar';
  static const food           = '/food';
  static const connect        = '/main/connect';
  static const morningBrief   = '/morning-brief';
  static const settings       = '/settings';
}

// ── Auth change notifier ──────────────────────────────────────────────────────
// Bridges Riverpod state changes → GoRouter's refreshListenable.
// GoRouter is created ONCE; this notifier tells it to re-run redirect guards
// whenever auth state changes — without recreating the router itself.
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

// ── Router provider ───────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier();

  // ref.listen → calls callback on change but does NOT rebuild this Provider,
  // so GoRouter is created exactly once for the lifetime of the app.
  ref.listen<AppState>(appStateProvider, (_, __) => notifier.notify());

  // Clean up the ChangeNotifier when the provider is disposed.
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    // refreshListenable triggers redirect re-evaluation without recreation.
    refreshListenable: notifier,
    redirect: (context, state) {
      // Use ref.read — we only need the current snapshot, not a subscription.
      final authState = ref.read(appStateProvider);
      final isAuth    = authState.isAuthenticated;
      final onboarded = authState.user?.onboardingComplete ?? false;
      final loc       = state.matchedLocation;

      // Onboarding routes — always accessible when not authed
      const onboardingRoutes = {
        AppRoutes.splash, AppRoutes.welcome, AppRoutes.login,
        AppRoutes.preferences, AppRoutes.obligationScan,
        AppRoutes.ready, AppRoutes.preparation,
      };

      if (!isAuth && !onboardingRoutes.contains(loc)) {
        // Welcome screen disabled — go straight to login
        // return AppRoutes.welcome;
        return AppRoutes.login;
      }
      if (isAuth && !onboarded && onboardingRoutes.contains(loc) &&
          loc != AppRoutes.preferences &&
          loc != AppRoutes.obligationScan &&
          loc != AppRoutes.ready &&
          loc != AppRoutes.preparation) {
        return AppRoutes.preferences;
      }
      if (isAuth && onboarded && onboardingRoutes.contains(loc)) {
        return AppRoutes.main;
      }
      return null;
    },
    routes: [
      // ── Onboarding ──────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.splash,         builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.welcome,        builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.login,          builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.preferences,    builder: (_, __) => const PreferencesScreen()),
      GoRoute(path: AppRoutes.obligationScan, builder: (_, __) => const ObligationScanScreen()),
      GoRoute(path: AppRoutes.ready,          builder: (_, __) => const ReadyScreen()),
      GoRoute(path: AppRoutes.preparation,    builder: (_, __) => const PreparationScreen()),

      // ── /main redirect → /main/buddy (Buddy chat is the landing page) ─────────
      GoRoute(
        path: AppRoutes.main,
        redirect: (_, __) => AppRoutes.buddy,
      ),

      // ── Main shell (bottom tabs) ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          GoRoute(path: AppRoutes.home,        builder: (_, __) => const HomeScreen()),
          GoRoute(path: AppRoutes.obligations, builder: (_, __) => const ObligationsScreen()),
          GoRoute(path: AppRoutes.buddy,       builder: (_, __) => const BuddyScreen()),
          GoRoute(path: AppRoutes.wallet,      builder: (_, __) => const WalletScreen()),
          GoRoute(path: AppRoutes.insights,    builder: (_, __) => const InsightsScreen()),
          GoRoute(path: AppRoutes.connect,     builder: (_, __) => const ConnectScreen()),
        ],
      ),

      // ── Modal / full-screen routes ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.brainDump,
        pageBuilder: (context, state) => const MaterialPage(
          child: BrainDumpScreen(),
          fullscreenDialog: true,
        ),
      ),
      GoRoute(path: AppRoutes.calendar,     builder: (_, __) => const CalendarScreen()),
      GoRoute(path: AppRoutes.food,         builder: (_, __) => const FoodScreen()),
      GoRoute(path: AppRoutes.morningBrief, builder: (_, __) => const MorningBriefScreen()),
      GoRoute(path: AppRoutes.settings,     builder: (_, __) => const SettingsScreen()),
    ],
  );
});
