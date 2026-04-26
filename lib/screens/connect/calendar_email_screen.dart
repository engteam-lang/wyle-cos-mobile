import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../models/email_sync_model.dart';
import '../../providers/app_state.dart';
import '../../services/buddy_api_service.dart';
import 'connect_screen.dart' show kProfileBg, kProfileCard, kProfileBorder, kProfileGradient;

// ── Palette ───────────────────────────────────────────────────────────────────
const _verdigris = Color(0xFF1B998B);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF7AACB8);
const _border    = Color(0xFF1E3E3A);
const _surface   = Color(0xFF132E2A);
const _amber     = Color(0xFFCB9A2D);
const _green     = Color(0xFF22C55E);
const _blue      = Color(0xFF3B82F6);
const _crimson   = Color(0xFFFF3B30);

// ─────────────────────────────────────────────────────────────────────────────
// Sync status enum
// ─────────────────────────────────────────────────────────────────────────────
enum _SyncState { idle, syncing, done, failed }

// ─────────────────────────────────────────────────────────────────────────────
class CalendarEmailScreen extends ConsumerStatefulWidget {
  const CalendarEmailScreen({super.key});

  @override
  ConsumerState<CalendarEmailScreen> createState() =>
      _CalendarEmailScreenState();
}

class _CalendarEmailScreenState extends ConsumerState<CalendarEmailScreen>
    with SingleTickerProviderStateMixin {

  // ── Enter animation ────────────────────────────────────────────────────────
  late AnimationController _enterCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Gmail sync state ───────────────────────────────────────────────────────
  _SyncState _gmailSyncState    = _SyncState.idle;
  _SyncState _calendarSyncState = _SyncState.idle;
  String?    _gmailSyncStatus;       // human-readable status text
  String?    _gmailSyncError;
  String?    _calendarSyncError;
  Timer?     _pollTimer;
  int?       _activeJobId;

  // ── Outlook sync state ─────────────────────────────────────────────────────
  _SyncState _outlookSyncState = _SyncState.idle;
  String?    _outlookSyncError;

  // ── Web-only manual token entry ────────────────────────────────────────────
  // These are ONLY shown when kIsWeb == true and never appear in APK/IPA builds.
  bool _showGoogleTokenEntry  = false;
  bool _showOutlookTokenEntry = false;
  bool _applyingGoogleToken   = false;
  bool _applyingOutlookToken  = false;
  final TextEditingController _googleTokenCtrl  = TextEditingController();
  final TextEditingController _outlookTokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pollTimer?.cancel();
    _googleTokenCtrl.dispose();
    _outlookTokenCtrl.dispose();
    super.dispose();
  }

  // ── OAuth ──────────────────────────────────────────────────────────────────

  Future<void> _connectGoogle() async {
    try {
      final result = await BuddyApiService.instance.startOAuth('google');
      final authUrl = result['auth_url'] as String?;
      if (authUrl == null || authUrl.isEmpty) return;
      await launchUrl(Uri.parse(authUrl),
          mode: LaunchMode.externalApplication);
      // On web the deep-link (com.wyle.buddy://...) won't fire automatically.
      // Reveal the manual token entry so the user can paste the auth_token
      // from the browser's callback URL.
      if (kIsWeb && mounted) {
        setState(() => _showGoogleTokenEntry = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Could not start Google sign-in. Please try again.',
              isError: true),
        );
      }
    }
  }

  Future<void> _connectOutlook() async {
    try {
      final result = await BuddyApiService.instance.startOAuth('microsoft');
      final authUrl = result['auth_url'] as String?;
      if (authUrl == null || authUrl.isEmpty) return;
      await launchUrl(Uri.parse(authUrl),
          mode: LaunchMode.externalApplication);
      // Same web workaround as Google.
      if (kIsWeb && mounted) {
        setState(() => _showOutlookTokenEntry = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Could not start Microsoft sign-in. Please try again.',
              isError: true),
        );
      }
    }
  }

  // ── Web-only token application ─────────────────────────────────────────────

  /// Accepts either a bare JWT string or a full callback URL containing
  /// auth_token / token / access_token as a query parameter.
  /// Saves to SharedPreferences, calls getMe() to read linked accounts,
  /// then updates appStateProvider accordingly.
  Future<void> _applyToken({
    required String          rawInput,
    required String          provider,   // 'google' | 'microsoft'
    required void Function(bool) setApplying,
    required VoidCallback    onSuccess,
  }) async {
    // ── 1. Extract token from raw input ───────────────────────────────────────
    String token = rawInput.trim();
    try {
      final uri = Uri.tryParse(token);
      if (uri != null) {
        // Standard query params
        final q = uri.queryParameters['auth_token'] ??
            uri.queryParameters['token'] ??
            uri.queryParameters['access_token'];
        if (q != null && q.isNotEmpty) {
          token = q;
        } else if (uri.fragment.contains('?')) {
          // Hash-based routing: /#/auth-callback?auth_token=...
          final qPart = uri.fragment.substring(uri.fragment.indexOf('?') + 1);
          final fromFrag = Uri.splitQueryString(qPart);
          final t = fromFrag['auth_token'] ??
              fromFrag['token'] ??
              fromFrag['access_token'];
          if (t != null && t.isNotEmpty) token = t;
        }
      }
    } catch (_) {}

    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snackBar(
          'Token is empty. Copy the auth_token value from the browser URL.',
          isError: true,
        ));
      }
      return;
    }

    setApplying(true);
    try {
      // ── 2. Persist the new token ─────────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAuthToken, token);

      // ── 3. Fetch updated profile (Dio interceptor will use the new token) ────
      Map<String, dynamic>? profile;
      try {
        profile = await BuddyApiService.instance.getMe();
      } catch (_) {}

      if (profile != null) {
        final email    = profile['email']     as String? ?? '';
        final fullName = profile['full_name'] as String? ?? '';

        // Parse linked_accounts list if present
        final linkedAccounts = profile['linked_accounts'] as List? ?? [];
        String? googleEmail;
        String? outlookEmail;
        for (final acct in linkedAccounts) {
          final m = acct as Map<String, dynamic>;
          final p = (m['provider'] as String? ?? '').toLowerCase();
          final e = (m['email'] as String? ?? m['account_email'] as String? ?? '');
          if (p == 'google'     && e.isNotEmpty) googleEmail  = e;
          if ((p == 'microsoft' || p == 'outlook') && e.isNotEmpty) outlookEmail = e;
        }

        if (provider == 'google') {
          final acctEmail = googleEmail ?? email;
          if (acctEmail.isNotEmpty) {
            await ref.read(appStateProvider.notifier).addGoogleAccount(acctEmail);
          }
        } else {
          final acctEmail = outlookEmail ?? email;
          if (acctEmail.isNotEmpty) {
            await ref.read(appStateProvider.notifier).addOutlookAccount(acctEmail);
          }
        }

        // Re-save updated token + user into app state
        final currentUser = ref.read(appStateProvider).user;
        if (currentUser != null) {
          await ref.read(appStateProvider.notifier).setAuth(token, currentUser);
        }
      } else {
        // getMe() failed — token saved but couldn't confirm account; mark connected
        if (provider == 'google') {
          await ref.read(appStateProvider.notifier)
              .addGoogleAccount('connected@google.com');
        } else {
          await ref.read(appStateProvider.notifier)
              .addOutlookAccount('connected@outlook.com');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(_snackBar('Account connected successfully ✓'));
        onSuccess();
      }
    } catch (e) {
      setApplying(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Failed to apply token. Please try again.', isError: true),
        );
      }
    }
  }

  void _applyGoogleToken() => _applyToken(
    rawInput:    _googleTokenCtrl.text,
    provider:    'google',
    setApplying: (v) => setState(() => _applyingGoogleToken = v),
    onSuccess:   () => setState(() {
      _showGoogleTokenEntry  = false;
      _applyingGoogleToken   = false;
      _googleTokenCtrl.clear();
    }),
  );

  void _applyOutlookToken() => _applyToken(
    rawInput:    _outlookTokenCtrl.text,
    provider:    'microsoft',
    setApplying: (v) => setState(() => _applyingOutlookToken = v),
    onSuccess:   () => setState(() {
      _showOutlookTokenEntry  = false;
      _applyingOutlookToken   = false;
      _outlookTokenCtrl.clear();
    }),
  );

  // ── Gmail email sync ───────────────────────────────────────────────────────

  Future<void> _syncGmail({bool useStub = false}) async {
    _pollTimer?.cancel();
    setState(() {
      _gmailSyncState  = _SyncState.syncing;
      _gmailSyncStatus = 'Starting sync…';
      _gmailSyncError  = null;
    });

    try {
      if (useStub) {
        // Demo sync — no OAuth required
        final result = await BuddyApiService.instance.triggerEmailSyncStub(
            provider: 'gmail');
        if (!mounted) return;
        setState(() {
          _gmailSyncState  = _SyncState.done;
          _gmailSyncStatus =
              'Demo sync complete — ${result.ingested} item'
              '${result.ingested == 1 ? '' : 's'} ingested.';
        });
        // Auto-trigger calendar sync after stub
        _syncCalendar(silent: true);
        return;
      }

      // Real sync
      final job = await BuddyApiService.instance.triggerEmailSync(
          provider: 'gmail');
      _activeJobId = job.id;
      if (!mounted) return;
      setState(() => _gmailSyncStatus = _jobStatusLabel(job.status));

      if (job.isDone) {
        _onGmailSyncDone();
        return;
      }
      if (job.isDead) {
        _onGmailSyncFailed(job.errorMessage);
        return;
      }

      // Poll every 2.5 s until done / dead (max ~90 s)
      var attempts = 0;
      _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
        if (!mounted) { _pollTimer?.cancel(); return; }
        if (attempts++ > 36) {
          _pollTimer?.cancel();
          _onGmailSyncFailed('Sync timed out. Please try again.');
          return;
        }
        try {
          final updated = await BuddyApiService.instance
              .getEmailSyncJob(_activeJobId!);
          if (!mounted) { _pollTimer?.cancel(); return; }
          setState(() => _gmailSyncStatus = _jobStatusLabel(updated.status));
          if (updated.isDone) {
            _pollTimer?.cancel();
            _onGmailSyncDone();
          } else if (updated.isDead) {
            _pollTimer?.cancel();
            _onGmailSyncFailed(updated.errorMessage);
          }
        } catch (_) { /* network hiccup — keep polling */ }
      });
    } catch (e) {
      // Real sync failed (likely no mail scope) — offer stub
      if (!mounted) return;
      _onGmailSyncFailed(null, offerStub: true);
    }
  }

  void _onGmailSyncDone() {
    if (!mounted) return;
    setState(() {
      _gmailSyncState  = _SyncState.done;
      _gmailSyncStatus = 'Email sync complete ✓';
    });
    ref.read(appStateProvider.notifier).loadObligationsFromApi();
    // Auto-trigger calendar sync silently
    _syncCalendar(silent: true);
  }

  void _onGmailSyncFailed(String? msg, {bool offerStub = false}) {
    if (!mounted) return;
    setState(() {
      _gmailSyncState = _SyncState.failed;
      _gmailSyncError = offerStub
          ? 'Mail scope not granted. Try "Demo Sync" to preview without real email access.'
          : (msg ?? 'Sync failed. Please try again.');
    });
  }

  // ── Calendar sync ──────────────────────────────────────────────────────────

  Future<void> _syncCalendar({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _calendarSyncState = _SyncState.syncing;
        _calendarSyncError = null;
      });
    }
    try {
      await BuddyApiService.instance.triggerGoogleCalendarSync();
      if (!mounted) return;
      if (!silent) {
        setState(() => _calendarSyncState = _SyncState.done);
        ref.read(appStateProvider.notifier).loadObligationsFromApi();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _calendarSyncState = _SyncState.failed;
          _calendarSyncError = 'Calendar sync failed. Please try again.';
        });
      }
    }
  }

  // ── Outlook sync ───────────────────────────────────────────────────────────

  Future<void> _syncOutlook() async {
    setState(() {
      _outlookSyncState = _SyncState.syncing;
      _outlookSyncError = null;
    });
    try {
      final job = await BuddyApiService.instance
          .triggerEmailSync(provider: 'microsoft');
      if (!mounted) return;

      // Simple poll
      var attempts = 0;
      Timer.periodic(const Duration(milliseconds: 2500), (t) async {
        if (!mounted || attempts++ > 36) { t.cancel(); return; }
        try {
          final updated =
              await BuddyApiService.instance.getEmailSyncJob(job.id);
          if (!mounted) { t.cancel(); return; }
          if (updated.isDone) {
            t.cancel();
            setState(() => _outlookSyncState = _SyncState.done);
            ref.read(appStateProvider.notifier).loadObligationsFromApi();
          } else if (updated.isDead) {
            t.cancel();
            setState(() {
              _outlookSyncState = _SyncState.failed;
              _outlookSyncError = updated.errorMessage ?? 'Sync failed.';
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outlookSyncState = _SyncState.failed;
        _outlookSyncError = 'Could not start Outlook sync. Please try again.';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state          = ref.watch(appStateProvider);
    final googleAccounts = state.googleAccounts;
    final outlookAccounts= state.outlookAccounts;
    final googleConnected= state.googleConnected;
    final outlookConnected = outlookAccounts.isNotEmpty;

    return Scaffold(
      backgroundColor: kProfileBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: kProfileGradient,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Email Providers'),
                          const SizedBox(height: 12),
                          _buildGmailCard(
                            connected: googleConnected,
                            accounts:  googleAccounts,
                          ),
                          const SizedBox(height: 14),
                          _buildOutlookCard(
                            connected: outlookConnected,
                            accounts:  outlookAccounts,
                          ),
                          const SizedBox(height: 28),
                          _buildInfoNote(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3530),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF254540)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Text('Calendar & Email',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: _white)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(label.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: const Color(0xFF5A7A78), letterSpacing: 1.0)),
  );

  // ── Gmail card ─────────────────────────────────────────────────────────────
  Widget _buildGmailCard({
    required bool connected,
    required List<String> accounts,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFF0A2A1A) : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? const Color(0xFF1B8B5A) : _border,
          width: connected ? 1.5 : 1.0,
        ),
        boxShadow: connected
            ? [BoxShadow(color: _green.withOpacity(0.15),
                blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ────────────────────────────────────────────────────────
          Row(children: [
            _providerIcon(
              child: CustomPaint(
                  size: const Size(26, 26), painter: const _GoogleGPainter()),
              bg: connected
                  ? const Color(0xFF0D3020)
                  : const Color(0xFF1A3530),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gmail',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          color: _white)),
                  Text(
                    connected && accounts.isNotEmpty
                        ? accounts.first
                        : 'Google Mail & Calendar',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: connected ? _green : _textSec),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (connected)
              _connectedBadge(_green, const Color(0xFF14532D)),
          ]),

          // ── Not connected ──────────────────────────────────────────────────
          if (!connected) ...[
            const SizedBox(height: 16),
            _actionBtn(
              label: 'Connect Gmail',
              icon: Icons.login_rounded,
              color: _green,
              onTap: _connectGoogle,
            ),
            const SizedBox(height: 10),
            _demoSyncBtn(),
            // ── Web-only: manual token paste panel ────────────────────────────
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              if (!_showGoogleTokenEntry)
                _webTokenHint(
                  onTap: () => setState(() => _showGoogleTokenEntry = true),
                )
              else
                _buildTokenEntry(
                  ctrl:     _googleTokenCtrl,
                  applying: _applyingGoogleToken,
                  onApply:  _applyGoogleToken,
                  onDismiss: () => setState(() {
                    _showGoogleTokenEntry = false;
                    _googleTokenCtrl.clear();
                  }),
                ),
            ],
          ],

          // ── Connected ──────────────────────────────────────────────────────
          if (connected) ...[
            const SizedBox(height: 14),
            _permissionChips(
              ['Read Mail', 'Send Mail', 'Calendar', 'Drive'],
              _green, const Color(0xFF0D3020),
            ),
            const SizedBox(height: 16),

            // Email sync section
            _syncSection(
              label:     'Email Sync',
              icon:      Icons.mail_outline_rounded,
              iconColor: _green,
              syncState: _gmailSyncState,
              statusMsg: _gmailSyncStatus,
              errorMsg:  _gmailSyncError,
              onSync: () => _syncGmail(),
              onStub: () => _syncGmail(useStub: true),
              showStubFallback: _gmailSyncState == _SyncState.failed &&
                  (_gmailSyncError?.contains('Demo') ?? false),
            ),

            const SizedBox(height: 12),

            // Calendar sync section
            _syncSection(
              label:     'Calendar Sync',
              icon:      Icons.calendar_month_rounded,
              iconColor: const Color(0xFF4FC3F7),
              syncState: _calendarSyncState,
              statusMsg: _calendarSyncState == _SyncState.done
                  ? 'Calendar synced ✓'
                  : null,
              errorMsg:  _calendarSyncError,
              onSync: () => _syncCalendar(),
            ),

            const SizedBox(height: 14),
            _disconnectBtn(
              label: 'Disconnect Gmail',
              onTap: () async {
                await ref.read(appStateProvider.notifier)
                    .removeGoogleAccount(accounts.first);
                setState(() {
                  _gmailSyncState    = _SyncState.idle;
                  _calendarSyncState = _SyncState.idle;
                  _gmailSyncError    = null;
                  _calendarSyncError = null;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Outlook card ───────────────────────────────────────────────────────────
  Widget _buildOutlookCard({
    required bool connected,
    required List<String> accounts,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFF0A1A2E) : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? const Color(0xFF1E6FBF) : _border,
          width: connected ? 1.5 : 1.0,
        ),
        boxShadow: connected
            ? [BoxShadow(color: _blue.withOpacity(0.15),
                blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ────────────────────────────────────────────────────────
          Row(children: [
            _providerIcon(
              child: CustomPaint(
                size: const Size(26, 26),
                painter: _OutlookLogoPainter(
                  holeBg: connected
                      ? const Color(0xFF0D1E38)
                      : const Color(0xFF1A3530),
                ),
              ),
              bg: connected
                  ? const Color(0xFF0D1E38)
                  : const Color(0xFF1A3530),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outlook',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          color: _white)),
                  Text(
                    connected && accounts.isNotEmpty
                        ? accounts.first
                        : 'Microsoft Mail & Calendar',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: connected
                            ? const Color(0xFF60A5FA)
                            : _textSec),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (connected)
              _connectedBadge(const Color(0xFF60A5FA),
                  const Color(0xFF1E3A5F)),
          ]),

          // ── Not connected ──────────────────────────────────────────────────
          if (!connected) ...[
            const SizedBox(height: 16),
            _actionBtn(
              label: 'Connect Outlook',
              icon:  Icons.login_rounded,
              color: _blue,
              onTap: _connectOutlook,
            ),
            const SizedBox(height: 10),
            _demoSyncBtn(provider: 'microsoft'),
            // ── Web-only: manual token paste panel ────────────────────────────
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              if (!_showOutlookTokenEntry)
                _webTokenHint(
                  color: _blue,
                  onTap: () => setState(() => _showOutlookTokenEntry = true),
                )
              else
                _buildTokenEntry(
                  ctrl:     _outlookTokenCtrl,
                  applying: _applyingOutlookToken,
                  onApply:  _applyOutlookToken,
                  onDismiss: () => setState(() {
                    _showOutlookTokenEntry = false;
                    _outlookTokenCtrl.clear();
                  }),
                ),
            ],
          ],

          // ── Connected ──────────────────────────────────────────────────────
          if (connected) ...[
            const SizedBox(height: 14),
            _permissionChips(
              ['Read Mail', 'Send Mail', 'Calendar'],
              _blue, const Color(0xFF0D1E38),
            ),
            const SizedBox(height: 16),

            _syncSection(
              label:     'Email Sync',
              icon:      Icons.mail_outline_rounded,
              iconColor: _blue,
              syncState: _outlookSyncState,
              statusMsg: _outlookSyncState == _SyncState.done
                  ? 'Outlook email synced ✓'
                  : null,
              errorMsg:  _outlookSyncError,
              onSync: _syncOutlook,
            ),

            const SizedBox(height: 14),
            _disconnectBtn(
              label: 'Disconnect Outlook',
              onTap: () async {
                await ref.read(appStateProvider.notifier)
                    .removeOutlookAccount(accounts.first);
                setState(() {
                  _outlookSyncState = _SyncState.idle;
                  _outlookSyncError = null;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Sync section widget ────────────────────────────────────────────────────
  Widget _syncSection({
    required String      label,
    required IconData    icon,
    required Color       iconColor,
    required _SyncState  syncState,
    String?              statusMsg,
    String?              errorMsg,
    required VoidCallback onSync,
    VoidCallback?         onStub,
    bool                  showStubFallback = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _white)),
            const Spacer(),
            // Status badge
            if (syncState == _SyncState.done)
              _statusBadge('Done', _green),
            if (syncState == _SyncState.failed)
              _statusBadge('Failed', _crimson),
            if (syncState == _SyncState.syncing)
              _statusBadge('Syncing', _amber),
          ]),

          // Status / error text
          if (statusMsg != null) ...[
            const SizedBox(height: 6),
            Text(statusMsg,
                style: GoogleFonts.inter(
                    fontSize: 11, color: _green.withOpacity(0.85))),
          ],
          if (errorMsg != null) ...[
            const SizedBox(height: 6),
            Text(errorMsg,
                style: GoogleFonts.inter(
                    fontSize: 11, color: _crimson.withOpacity(0.9),
                    height: 1.4)),
          ],

          // Spinner while syncing
          if (syncState == _SyncState.syncing) ...[
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: iconColor, strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Please wait…',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _textSec)),
            ]),
          ],

          const SizedBox(height: 10),

          // Action buttons
          Row(children: [
            if (syncState != _SyncState.syncing)
              Expanded(
                child: _actionBtn(
                  label: syncState == _SyncState.done ? 'Sync Again' : 'Sync Now',
                  icon:  Icons.sync_rounded,
                  color: iconColor,
                  onTap: onSync,
                  compact: true,
                ),
              ),
            if (showStubFallback && onStub != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  label: 'Demo Sync',
                  icon:  Icons.science_outlined,
                  color: _amber,
                  onTap: onStub,
                  compact: true,
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  // ── Demo sync button (shown when not connected) ────────────────────────────
  Widget _demoSyncBtn({String provider = 'gmail'}) {
    return GestureDetector(
      onTap: () => _syncGmail(useStub: true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _amber.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.science_outlined, color: _amber, size: 15),
          const SizedBox(width: 7),
          Text('Demo Sync (no sign-in needed)',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: _amber)),
        ]),
      ),
    );
  }

  // ── Web-only: "Already have a token?" hint link ────────────────────────────
  /// Shown only on kIsWeb when the token panel is hidden.
  Widget _webTokenHint({Color color = _green, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.key_outlined, color: color.withOpacity(0.6), size: 13),
            const SizedBox(width: 5),
            Text(
              'Already completed sign-in? Paste your token here',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: color.withOpacity(0.7),
                  decoration: TextDecoration.underline,
                  decorationColor: color.withOpacity(0.4)),
            ),
          ]),
        ),
      );

  // ── Web-only: collapsible token paste panel ────────────────────────────────
  /// Never rendered on Android/iOS — guarded by `if (kIsWeb)` at call-sites.
  Widget _buildTokenEntry({
    required TextEditingController ctrl,
    required bool                  applying,
    required VoidCallback          onApply,
    required VoidCallback          onDismiss,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF071E28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            const Icon(Icons.key_rounded, color: _amber, size: 14),
            const SizedBox(width: 7),
            Text('Paste Auth Token',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
            const Spacer(),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded, color: _textSec, size: 15),
            ),
          ]),
          const SizedBox(height: 6),
          // Instruction text
          Text(
            'After the browser login completes, copy the full callback URL '
            '(or just the auth_token= value) from the address bar and paste it below.',
            style: GoogleFonts.inter(
                fontSize: 11, color: _textSec, height: 1.45),
          ),
          const SizedBox(height: 10),
          // Token text field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D2028),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: ctrl,
              enabled: !applying,
              style: GoogleFonts.sourceCodePro(
                  fontSize: 11, color: _white, height: 1.5),
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(12),
                hintText: 'https://…?auth_token=eyJ…   or just the token',
                hintStyle: GoogleFonts.inter(
                    fontSize: 10,
                    color: _textSec.withOpacity(0.45)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Apply button / spinner
          applying
              ? const Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: _amber, strokeWidth: 2),
                  ),
                )
              : GestureDetector(
                  onTap: onApply,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _amber.withOpacity(0.45)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: _amber, size: 14),
                          const SizedBox(width: 7),
                          Text('Apply Token',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _amber)),
                        ]),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Info note ──────────────────────────────────────────────────────────────
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF4FC3F7), size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Connecting your accounts lets Wyle read your schedule, '
                'draft replies, and surface what matters — privately and securely.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: _textSec, height: 1.5),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.drive_file_move_outlined,
                color: Color(0xFF4CAF50), size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Google Drive scope is also requested so Buddy can save '
                'documents you upload in chat.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: _textSec, height: 1.5),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _providerIcon({required Widget child, required Color bg}) =>
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12)),
        child: Center(child: child),
      );

  Widget _connectedBadge(Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg.withOpacity(0.8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withOpacity(0.5)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('Connected',
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    ]),
  );

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _actionBtn({
    required String     label,
    required IconData   icon,
    required Color      color,
    required VoidCallback onTap,
    bool compact = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: compact ? null : double.infinity,
          padding: EdgeInsets.symmetric(
              vertical: compact ? 10 : 13,
              horizontal: compact ? 14 : 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withOpacity(0.80),
              color.withOpacity(0.55),
            ]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.22),
                  blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: _white, size: 15),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: _white)),
          ]),
        ),
      );

  Widget _disconnectBtn({
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A3A)),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF))),
          ),
        ),
      );

  Widget _permissionChips(
      List<String> chips, Color color, Color bg) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips
            .map((c) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Text(c,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: color.withOpacity(0.85),
                          fontWeight: FontWeight.w500)),
                ))
            .toList(),
      );

  String _jobStatusLabel(String status) {
    switch (status) {
      case 'queued':  return 'Job queued, waiting to start…';
      case 'running': return 'Sync running — reading your inbox…';
      case 'done':    return 'Email sync complete ✓';
      case 'dead':    return 'Sync failed after retries.';
      default:        return status;
    }
  }

  SnackBar _snackBar(String msg, {bool isError = false}) => SnackBar(
    backgroundColor:
        isError ? _crimson.withOpacity(0.9) : const Color(0xFF0F3D35),
    behavior: SnackBarBehavior.floating,
    shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    content: Text(msg,
        style: GoogleFonts.inter(fontSize: 13, color: _white)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Google G — 4-colour ring + horizontal bar
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue   = Color(0xFF4285F4);
  static const _red    = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green  = Color(0xFF34A853);

  void _slice(Canvas canvas, double cx, double cy,
      double outerR, double innerR,
      double startDeg, double sweepDeg, Color color) {
    final startRad = startDeg * math.pi / 180;
    final sweepRad = sweepDeg * math.pi / 180;
    final path = Path()
      ..moveTo(cx + innerR * math.cos(startRad),
               cy + innerR * math.sin(startRad))
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
              startRad, sweepRad, false)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
              startRad + sweepRad, -sweepRad, false)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final outerR = size.width / 2 * 0.90;
    final innerR = size.width / 2 * 0.54;
    _slice(canvas, cx, cy, outerR, innerR,  18,  72, _green);
    _slice(canvas, cx, cy, outerR, innerR,  90,  90, _yellow);
    _slice(canvas, cx, cy, outerR, innerR, 180,  90, _red);
    _slice(canvas, cx, cy, outerR, innerR, 270,  72, _blue);
    final barHalf = outerR * 0.175;
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - barHalf, cx + outerR, cy + barHalf),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Outlook logo painter
// ─────────────────────────────────────────────────────────────────────────────
class _OutlookLogoPainter extends CustomPainter {
  final Color holeBg;
  const _OutlookLogoPainter({required this.holeBg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final envRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width:  size.width  * 0.90,
        height: size.height * 0.68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(envRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF0078D4),
    );
    final oCx = cx - size.width * 0.07;
    canvas.drawCircle(
        Offset(oCx, cy), size.width * 0.21, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(oCx, cy), size.width * 0.13, Paint()..color = holeBg);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(envRect.left,  envRect.top), Offset(cx, cy - 1), line);
    canvas.drawLine(Offset(envRect.right, envRect.top), Offset(cx, cy - 1), line);
  }

  @override
  bool shouldRepaint(covariant _OutlookLogoPainter old) =>
      old.holeBg != holeBg;
}
