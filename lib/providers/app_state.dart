import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/obligation_model.dart';
import '../models/user_model.dart';
import '../models/insights_model.dart';
import '../models/morning_brief_model.dart';
import '../models/action_item_model.dart';
import '../constants/app_constants.dart';
import '../services/buddy_api_service.dart';
import '../services/notification_service.dart';
import '../utils/avatar_gender.dart';

// ── App state model ───────────────────────────────────────────────────────────
class AppState {
  final String? token;
  final UserModel? user;
  final bool isAuthenticated;
  final List<ObligationModel> obligations;
  final InsightsModel? insights;
  final MorningBriefModel? morningBrief;
  final String? lastBriefKey;
  final bool googleConnected;
  final String googleEmail;
  final List<String> googleAccounts;
  final List<String> outlookAccounts;
  final bool isLoading;
  // ── Buddy API state ───────────────────────────────────────────────────────
  final int? activeConversationId;   // last used chat conversation id from API
  final List<ActionItemModel> actionItems; // live inbox from /v1/action-items

  const AppState({
    this.token,
    this.user,
    this.isAuthenticated = false,
    this.obligations = const [],
    this.insights,
    this.morningBrief,
    this.lastBriefKey,
    this.googleConnected = false,
    this.googleEmail = '',
    this.googleAccounts = const [],
    this.outlookAccounts = const [],
    this.isLoading = false,
    this.activeConversationId,
    this.actionItems = const [],
  });

  AppState copyWith({
    String? token,
    UserModel? user,
    bool? isAuthenticated,
    List<ObligationModel>? obligations,
    InsightsModel? insights,
    MorningBriefModel? morningBrief,
    String? lastBriefKey,
    bool? googleConnected,
    String? googleEmail,
    List<String>? googleAccounts,
    List<String>? outlookAccounts,
    bool? isLoading,
    int? activeConversationId,
    List<ActionItemModel>? actionItems,
  }) {
    return AppState(
      token:                 token                 ?? this.token,
      user:                  user                  ?? this.user,
      isAuthenticated:       isAuthenticated       ?? this.isAuthenticated,
      obligations:           obligations           ?? this.obligations,
      insights:              insights              ?? this.insights,
      morningBrief:          morningBrief          ?? this.morningBrief,
      lastBriefKey:          lastBriefKey          ?? this.lastBriefKey,
      googleConnected:       googleConnected       ?? this.googleConnected,
      googleEmail:           googleEmail           ?? this.googleEmail,
      googleAccounts:        googleAccounts        ?? this.googleAccounts,
      outlookAccounts:       outlookAccounts       ?? this.outlookAccounts,
      isLoading:             isLoading             ?? this.isLoading,
      activeConversationId:  activeConversationId  ?? this.activeConversationId,
      actionItems:           actionItems           ?? this.actionItems,
    );
  }
}

// ── App state notifier ────────────────────────────────────────────────────────
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState()) {
    _loadPersistedState();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────
  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final token    = prefs.getString(AppConstants.keyAuthToken);
    final userJson = prefs.getString(AppConstants.keyUser);
    final googleAccountsJson = prefs.getString(AppConstants.keyGoogleAccounts);
    final outlookAccountsJson= prefs.getString(AppConstants.keyOutlookAccounts);
    final lastBriefKey        = prefs.getString(AppConstants.keyLastBriefKey);
    final activeConversation  = prefs.getInt(AppConstants.keyActiveConversation);

    UserModel? user;
    if (userJson != null) {
      try { user = UserModel.fromJson(jsonDecode(userJson)); } catch (_) {}
    }

    List<String> googleAccounts = [];
    if (googleAccountsJson != null) {
      try { googleAccounts = List<String>.from(jsonDecode(googleAccountsJson)); } catch (_) {}
    }

    List<String> outlookAccounts = [];
    if (outlookAccountsJson != null) {
      try { outlookAccounts = List<String>.from(jsonDecode(outlookAccountsJson)); } catch (_) {}
    }

    state = state.copyWith(
      token:           token,
      user:            user,
      isAuthenticated: token != null && user != null,
      googleAccounts:  googleAccounts,
      outlookAccounts: outlookAccounts,
      googleConnected:      googleAccounts.isNotEmpty,
      googleEmail:          googleAccounts.isNotEmpty ? googleAccounts.first : '',
      lastBriefKey:         lastBriefKey,
      activeConversationId: activeConversation,
    );

    // Re-hydrate tasks from the backend whenever we boot with a stored token.
    if (token != null) {
      loadObligationsFromApi();
      // Renew the Gmail push-notification watch on every app launch.
      // Gmail watches expire in ~7 days; calling this unconditionally is
      // idempotent (the backend upserts the subscription) and ensures we
      // never silently lose email push notifications after expiry.
      if (googleAccounts.isNotEmpty) _registerGmailWatch();
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────────
  Future<void> setAuth(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAuthToken, token);
    await prefs.setString(AppConstants.keyUser, jsonEncode(user.toJson()));
    state = state.copyWith(token: token, user: user, isAuthenticated: true);
    // Pull the user's persisted tasks from the backend right after login.
    loadObligationsFromApi();
    // Register this device's FCM token with the backend so the server can
    // send push notifications to this specific device.
    _registerFcmToken();
    // Register (or renew) the Gmail Pub/Sub watch so incoming emails trigger
    // FCM push notifications.  Called here so a fresh Google-linked login
    // always sets up the watch immediately.
    _registerGmailWatch();
  }

  /// Fetches the FCM token from Firebase and POSTs it to /v1/users/me/devices.
  /// Silent — never throws; push notifications are non-critical.
  /// No-op on web (Firebase not initialised on web build).
  Future<void> _registerFcmToken() async {
    if (kIsWeb) return; // push notifications are Android-only for now
    try {
      final fcmToken = await NotificationService.instance.getToken(
        onTokenRefresh: (newToken) {
          // Re-register whenever Firebase rotates the token
          debugPrint('[FCM] Token rotated — re-registering with backend');
          BuddyApiService.instance
              .registerDevice(fcmToken: newToken)
              .catchError((e) {
            debugPrint('[FCM] Re-register failed: $e');
          });
        },
      );
      if (fcmToken == null) {
        debugPrint('[FCM] No token available — skipping device registration');
        return;
      }
      await BuddyApiService.instance.registerDevice(fcmToken: fcmToken);
      debugPrint('[FCM] Device registered successfully');
    } catch (e) {
      // Non-fatal — app works fine without push notifications
      debugPrint('[FCM] Device registration failed: $e');
    }
  }

  /// POSTs to POST /v1/integrations/google/gmail/watch so that Gmail notifies
  /// the backend via Google Pub/Sub when new mail arrives, which then fans out
  /// an FCM push to this device.
  ///
  /// Silent — never throws; Gmail watch is non-critical (app works without it).
  /// No-op on web (push notifications are Android-only for now).
  Future<void> _registerGmailWatch() async {
    if (kIsWeb) return;
    try {
      await BuddyApiService.instance.registerGmailWatch();
    } catch (e) {
      debugPrint('[GmailWatch] Could not register watch from app_state: $e');
    }
  }

  /// Permanently deletes the account server-side then clears all local state.
  /// Throws if the API call fails (caller should show an error to the user).
  Future<void> deleteAccount() async {
    // Call the API while the token is still present so the request is auth'd.
    final result = await BuddyApiService.instance.deleteMyData(confirm: true);
    debugPrint('[DeleteAccount] server response: $result');

    // Clear all local state exactly like a logout.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAuthToken);
    await prefs.remove(AppConstants.keyUser);
    await prefs.remove(AppConstants.keyGoogleAccounts);
    await prefs.remove(AppConstants.keyOutlookAccounts);
    state = const AppState();
  }

  Future<void> logout() async {
    // ── 1. Notify the server FIRST (while we still have the token) ────────────
    // This removes server-side OAuth credentials, stops background sync, and
    // revokes stored Google / Microsoft refresh tokens.
    // The call is fire-and-forget — local sign-out proceeds even if it fails.
    final result = await BuddyApiService.instance.serverLogout();
    debugPrint('[Logout] server response: $result');

    // ── 2. Clear local state ──────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAuthToken);
    await prefs.remove(AppConstants.keyUser);
    await prefs.remove(AppConstants.keyGoogleAccounts);
    await prefs.remove(AppConstants.keyOutlookAccounts);
    state = const AppState();
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
    _persistUser(user);
  }

  Future<void> _persistUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUser, jsonEncode(user.toJson()));
  }

  void setOnboardingComplete() {
    if (state.user == null) return;
    final updated = state.user!.copyWith(onboardingComplete: true);
    updateUser(updated);
  }

  // ── Obligations ───────────────────────────────────────────────────────────────
  void setObligations(List<ObligationModel> obs) {
    state = state.copyWith(obligations: obs);
  }

  void addObligation(ObligationModel ob) {
    state = state.copyWith(obligations: [ob, ...state.obligations]);
  }

  void addObligations(List<ObligationModel> obs) {
    final completedIds = state.obligations
        .where((o) => o.status == 'completed')
        .map((o) => o.id)
        .toSet();
    final existingIds = state.obligations.map((o) => o.id).toSet();
    final toAdd = obs.where((o) =>
        !completedIds.contains(o.id) && !existingIds.contains(o.id)).toList();
    if (toAdd.isEmpty) return;
    state = state.copyWith(obligations: [...toAdd, ...state.obligations]);
  }

  void updateObligation(String id, ObligationModel Function(ObligationModel) updater) {
    state = state.copyWith(
      obligations: state.obligations.map((o) => o.id == id ? updater(o) : o).toList(),
    );
  }

  void resolveObligation(String id) {
    state = state.copyWith(
      obligations: state.obligations.map((o) =>
          o.id == id ? o.copyWith(status: 'completed') : o).toList(),
    );
  }

  /// Permanently removes an obligation from local state (after DELETE API call).
  void removeObligation(String id) {
    state = state.copyWith(
      obligations: state.obligations.where((o) => o.id != id).toList(),
    );
  }

  // ── Load from API ─────────────────────────────────────────────────────────────
  /// Fetches all of the user's action items from GET /v1/action-items and
  /// merges them into the obligations list.
  ///
  /// Strategy:
  ///   • All  buddy_action_*  obligations are replaced with fresh API data so
  ///     status changes (e.g. done) are always reflected after login.
  ///   • Silent fail: if the network call errors we just keep existing state.
  Future<void> loadObligationsFromApi() async {
    if (state.token == null) return;
    try {
      final items = await BuddyApiService.instance.getActionItems();
      final apiObs = items.map(_actionItemToObligation).toList();
      state = state.copyWith(obligations: apiObs);
    } catch (_) {
      // Network error — keep current state, don't show an error to the user
    }
  }

  /// Converts a backend ActionItemModel → UI ObligationModel.
  static ObligationModel _actionItemToObligation(ActionItemModel item) {
    int daysUntil = 1;
    String? noteText;

    final dateStr = item.startsAt ?? item.remindAt;
    if (dateStr != null) {
      try {
        final cleanIso = dateStr.length > 19 ? dateStr.substring(0, 19) : dateStr;
        final parsed = DateTime.parse(cleanIso);
        final date = DateTime(parsed.year, parsed.month, parsed.day,
            parsed.hour, parsed.minute);
        final today = DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day);
        final itemDay = DateTime(date.year, date.month, date.day);
        daysUntil = itemDay.difference(today).inDays;

        const months = [
          'Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec',
        ];
        final day   = date.day;
        final month = months[date.month - 1];
        final year  = date.year != DateTime.now().year ? ' ${date.year}' : '';

        // Always show the exact date — never vague labels like "Today"/"Tomorrow"
        final hasTime = date.hour != 0 || date.minute != 0;
        final h    = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final min  = date.minute.toString().padLeft(2, '0');
        final ampm = date.hour < 12 ? 'AM' : 'PM';
        final time = hasTime ? ' at $h:$min $ampm' : '';

        noteText = '$month $day$year$time';    // e.g. "Mar 22 2026, 8:30 AM"
      } catch (_) {}
    }

    final risk = daysUntil <= 0 ? 'high'
               : daysUntil < 7  ? 'high'
               : daysUntil < 30 ? 'medium'
               : 'low';

    final emoji = (item.kind == 'event' || item.kind == 'meeting') ? '📅' : '✅';

    return ObligationModel(
      id:            'buddy_action_${item.id}',
      emoji:         emoji,
      title:         item.title,
      type:          'custom',
      daysUntil:     daysUntil,
      risk:          risk,
      status:        item.status == 'done' ? 'completed' : 'active',
      executionPath: 'Scheduled by Buddy',
      notes:         noteText,
      source:        item.source,
      startsAt:      dateStr,
    );
  }

  // ── Brief ─────────────────────────────────────────────────────────────────────
  void setMorningBrief(MorningBriefModel brief) {
    state = state.copyWith(morningBrief: brief);
  }

  Future<void> setLastBriefKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLastBriefKey, key);
    state = state.copyWith(lastBriefKey: key);
  }

  // ── Google accounts ───────────────────────────────────────────────────────────
  void setGoogleConnected(bool connected) {
    state = state.copyWith(googleConnected: connected);
  }

  void setGoogleEmail(String email) {
    state = state.copyWith(googleEmail: email);
  }

  Future<void> addGoogleAccount(String email) async {
    final updated = {...state.googleAccounts, email}.toList();
    await _persistGoogleAccounts(updated);
    state = state.copyWith(
      googleAccounts:  updated,
      googleConnected: true,
      googleEmail:     state.googleEmail.isEmpty ? email : state.googleEmail,
    );
  }

  Future<void> removeGoogleAccount(String email) async {
    final updated = state.googleAccounts.where((e) => e != email).toList();
    await _persistGoogleAccounts(updated);
    state = state.copyWith(
      googleAccounts:  updated,
      googleConnected: updated.isNotEmpty,
      googleEmail:     updated.isNotEmpty ? updated.first : '',
    );
  }

  Future<void> setGoogleAccounts(List<String> accounts) async {
    await _persistGoogleAccounts(accounts);
    state = state.copyWith(
      googleAccounts:  accounts,
      googleConnected: accounts.isNotEmpty,
      googleEmail:     accounts.isNotEmpty ? accounts.first : state.googleEmail,
    );
  }

  /// Calls GET /v1/users/me and syncs the server's linked_accounts into
  /// local state + SharedPreferences.
  ///
  /// Call this whenever the Calendar & Email screen opens so that
  /// googleConnected / outlookConnected stay accurate even after a page
  /// refresh (web) or app restart where SharedPreferences was cleared.
  Future<void> refreshLinkedAccountsFromServer() async {
    if (state.token == null) return;
    try {
      final me = await BuddyApiService.instance.getMe();
      final linked = me['linked_accounts'] as List? ?? [];

      final googleEmails  = <String>[];
      final outlookEmails = <String>[];

      for (final acct in linked) {
        final m        = acct as Map<String, dynamic>;
        final provider = (m['provider'] as String? ?? '').toLowerCase();
        final email    = (m['email']    as String? ??
                          m['account_email'] as String? ?? '');
        if (email.isEmpty) continue;
        if (provider == 'google')                           googleEmails.add(email);
        if (provider == 'microsoft' || provider == 'outlook') outlookEmails.add(email);
      }

      // Update Google accounts if server has more/different data
      if (googleEmails.isNotEmpty || state.googleAccounts.isEmpty) {
        await setGoogleAccounts(googleEmails);
      }
      // Update Outlook accounts
      if (outlookEmails.isNotEmpty || state.outlookAccounts.isEmpty) {
        await _persistOutlookAccounts(outlookEmails);
        state = state.copyWith(outlookAccounts: outlookEmails);
      }

      debugPrint('[AccountRefresh] google: $googleEmails  outlook: $outlookEmails');
    } catch (e) {
      debugPrint('[AccountRefresh] getMe() failed — keeping cached state: $e');
      // Silent fail — cached state from SharedPreferences is still shown
    }
  }

  Future<void> _persistGoogleAccounts(List<String> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyGoogleAccounts, jsonEncode(accounts));
  }

  // ── Outlook accounts ──────────────────────────────────────────────────────────
  Future<void> addOutlookAccount(String email) async {
    final updated = {...state.outlookAccounts, email}.toList();
    await _persistOutlookAccounts(updated);
    state = state.copyWith(outlookAccounts: updated);
  }

  Future<void> removeOutlookAccount(String email) async {
    final updated = state.outlookAccounts.where((e) => e != email).toList();
    await _persistOutlookAccounts(updated);
    state = state.copyWith(outlookAccounts: updated);
  }

  Future<void> _persistOutlookAccounts(List<String> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyOutlookAccounts, jsonEncode(accounts));
  }

  // ── Insights ──────────────────────────────────────────────────────────────────
  void setInsights(InsightsModel insights) {
    state = state.copyWith(insights: insights);
  }

  // ── Loading ───────────────────────────────────────────────────────────────────
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  // ── Active conversation ───────────────────────────────────────────────────────
  Future<void> setActiveConversation(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyActiveConversation, conversationId);
    state = state.copyWith(activeConversationId: conversationId);
  }

  // ── Action items (from /v1/action-items) ──────────────────────────────────────
  void setActionItems(List<ActionItemModel> items) {
    state = state.copyWith(actionItems: items);
  }

  void addActionItem(ActionItemModel item) {
    state = state.copyWith(actionItems: [item, ...state.actionItems]);
  }

  void markActionItemDone(int itemId) {
    state = state.copyWith(
      actionItems: state.actionItems
          .map((i) => i.id == itemId ? i.copyWith(status: 'done') : i)
          .toList(),
    );
  }

  void removeActionItem(int itemId) {
    state = state.copyWith(
      actionItems: state.actionItems.where((i) => i.id != itemId).toList(),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(),
);

// ── Convenience selectors ─────────────────────────────────────────────────────
final activeObligationsProvider = Provider<List<ObligationModel>>((ref) {
  final obs = ref.watch(appStateProvider).obligations;
  return obs
      .where((o) => o.status != 'completed')
      .toList()
      ..sort((a, b) {
        final cmp = a.daysUntil.compareTo(b.daysUntil);
        if (cmp != 0) return cmp;
        const rw = {'high': 0, 'medium': 1, 'low': 2};
        return (rw[a.risk] ?? 2).compareTo(rw[b.risk] ?? 2);
      });
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(appStateProvider).isAuthenticated;
});

final buddyAvatarGenderProvider = Provider<String>((ref) {
  final user = ref.watch(appStateProvider).user;
  // Prefer the explicit gender field from /v1/users/me; fall back to inference.
  final apiGender = user?.gender?.toLowerCase();
  if (apiGender == 'male' || apiGender == 'female') return apiGender!;
  return inferAvatarGender(name: user?.name, email: user?.email);
});
