import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';
import '../../services/google_auth_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg         = Color(0xFF0D0D0D);
const _surface    = Color(0xFF161616);
const _surfaceEl  = Color(0xFF1E1E1E);
const _border     = Color(0xFF2A2A2A);
const _verdigris  = Color(0xFF1B998B);
const _chartreuse = Color(0xFFD5FF3F);
const _white      = Color(0xFFFFFFFF);
const _textSec    = Color(0xFF9A9A9A);
const _textTer    = Color(0xFF555555);
const _crimson    = Color(0xFFFF3B30);
const _salmon     = Color(0xFFFF6B6B);

// ─────────────────────────────────────────────────────────────────────────────
// Profile / Connect Screen — full Figma design
// ─────────────────────────────────────────────────────────────────────────────
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen>
    with SingleTickerProviderStateMixin {

  bool _googleConnecting = false;

  late AnimationController _enterCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Google connect ────────────────────────────────────────────────────────
  Future<void> _connectGoogle() async {
    setState(() => _googleConnecting = true);
    try {
      final result = await GoogleAuthService.instance.signIn();
      if (!mounted) return;
      if (result.success) {
        ref.read(appStateProvider.notifier).addGoogleAccount(result.email);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connected as ${result.email}'),
          backgroundColor: _verdigris,
        ));
      } else if (result.error != null && result.error != 'Cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign-in failed: ${result.error}'),
          backgroundColor: _crimson,
        ));
      }
    } finally {
      if (mounted) setState(() => _googleConnecting = false);
    }
  }

  Future<void> _disconnectGoogle(String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Disconnect Google',
            style: GoogleFonts.poppins(color: _white)),
        content: Text('Remove $email from Wyle?',
            style: GoogleFonts.poppins(color: _textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Disconnect', style: TextStyle(color: _crimson))),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(appStateProvider.notifier).removeGoogleAccount(email);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(color: _white)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins(color: _textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Sign Out',
                  style: TextStyle(color: _crimson, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(appStateProvider.notifier).logout();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final user  = state.user;
    final name  = user?.name  ?? 'User';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ───────────────────────────────────────────────
                  _buildTopBar(context),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── User card ─────────────────────────────────────
                        _buildUserCard(name, email),
                        const SizedBox(height: 24),

                        // ── Membership ────────────────────────────────────
                        _sectionLabel('MEMBERSHIP'),
                        _buildMembershipCard(),
                        const SizedBox(height: 22),

                        // ── Personal Information ──────────────────────────
                        _sectionLabel('PERSONAL INFORMATION'),
                        _buildListCard([
                          _RowData('✉',  'EMAIL',        email.isNotEmpty ? email : 'Not set'),
                          _RowData('📞', 'PHONE',        '+971 50 123 4567'),
                          _RowData('📍', 'LOCATION',     'Dubai, UAE'),
                          _RowData('📅', 'MEMBER SINCE', 'December 2025',  isLast: true),
                        ]),
                        const SizedBox(height: 22),

                        // ── Preferences ───────────────────────────────────
                        _sectionLabel('PREFERENCES'),
                        _buildListCard([
                          _RowData('🔔', 'NOTIFICATIONS',     'All enabled'),
                          _RowData('🌐', 'LANGUAGE',          'English'),
                          _RowData('🔒', 'PRIVACY & SECURITY','High protection'),
                          _RowData('💳', 'PAYMENT METHODS',   '2 cards linked', isLast: true),
                        ]),
                        const SizedBox(height: 22),

                        // ── Your Performance ──────────────────────────────
                        _sectionLabel('YOUR PERFORMANCE'),
                        _buildPerfGrid(state),
                        const SizedBox(height: 22),

                        // ── Account ───────────────────────────────────────
                        _sectionLabel('ACCOUNT'),
                        _buildAccountSection(state),
                        const SizedBox(height: 16),

                        // Version
                        Center(
                          child: Text(
                            'Wyle v1.0.0 · Built for Dubai professionals',
                            style: GoogleFonts.poppins(
                                color: _textTer, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 18),
      child: Row(
        children: [
          Text('Profile',
              style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.w700, color: _white)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(AppRoutes.settings),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.settings_outlined,
                  color: _textSec, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── User card ─────────────────────────────────────────────────────────────
  Widget _buildUserCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _UserAvatar(name: name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _white)),
                const SizedBox(height: 3),
                Text('Premium Member',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: _textSec)),
                const SizedBox(height: 8),
                // Elite badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _chartreuse.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _chartreuse.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text('Elite Status',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _chartreuse)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Membership card ───────────────────────────────────────────────────────
  Widget _buildMembershipCard() {
    final stats = [
      _PerfStat('DAYS ACTIVE', '86',   _verdigris),
      _PerfStat('OPT. SCORE',  '742',  _chartreuse),
      _PerfStat('TIME SAVED',  '64h',  _salmon),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Stats row
          IntrinsicHeight(
            child: Row(
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          Text(stats[i].value,
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: stats[i].color)),
                          const SizedBox(height: 4),
                          Text(stats[i].label,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _textTer,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  if (i < stats.length - 1)
                    Container(width: 1, color: _border),
                ],
              ],
            ),
          ),
          // Plan row
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Premium Annual',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _white)),
                      const SizedBox(height: 3),
                      Text('Renews Mar 15, 2026',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _textTer)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('AED 500',
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _verdigris)),
                    Text('/month',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: _textTer)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── List card (Personal Info + Preferences) ───────────────────────────────
  Widget _buildListCard(List<_RowData> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: rows.map((r) => _buildRowItem(r)).toList(),
      ),
    );
  }

  Widget _buildRowItem(_RowData row) {
    return Container(
      decoration: row.isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _surfaceEl,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(row.icon,
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textTer,
                        letterSpacing: 1.0)),
                const SizedBox(height: 3),
                Text(row.value,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _white)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _textTer, size: 20),
        ],
      ),
    );
  }

  // ── Performance 2×2 grid ──────────────────────────────────────────────────
  Widget _buildPerfGrid(AppState state) {
    final active    = state.obligations.where((o) => o.status != 'completed').length;
    final completed = state.obligations.where((o) => o.status == 'completed').length;

    final items = [
      _PerfCard('⚡', 'AUTOMATIONS',  '$active',       '+2 this week',  true,  _verdigris),
      _PerfCard('⏱', 'AVG RESPONSE', '12m',            '-4m this week', false, _chartreuse),
      _PerfCard('📈', 'EFFICIENCY',   '94%',            '+6% this week', true,  _verdigris),
      _PerfCard('✓',  'COMPLETED',    '$completed',     '+18 this week', true,  _chartreuse),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => _buildPerfCard(item, cardW))
              .toList(),
        );
      },
    );
  }

  Widget _buildPerfCard(_PerfCard item, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(item.value,
              style: GoogleFonts.poppins(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: item.color, height: 1.1)),
          const SizedBox(height: 3),
          Text(item.label,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _textSec, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.trendUp ? _verdigris : _crimson,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(item.trend,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.trendUp ? _verdigris : _crimson)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Account section ───────────────────────────────────────────────────────
  Widget _buildAccountSection(AppState state) {
    final isConnected = state.googleAccounts.isNotEmpty;
    final connectedEmail = isConnected ? state.googleAccounts.first : null;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Gmail / Google connect row
          _buildAccountRow(
            iconBg: _verdigris.withOpacity(0.1),
            icon: '📧',
            loading: _googleConnecting,
            label: isConnected ? 'Gmail Connected' : 'Connect Gmail & Calendar',
            sub: isConnected
                ? connectedEmail!
                : 'Auto-detect obligations from inbox',
            trailing: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? _verdigris : _textTer,
              ),
            ),
            onTap: isConnected
                ? () => _disconnectGoogle(connectedEmail!)
                : _connectGoogle,
            hasBorder: true,
          ),

          // Manage subscription
          _buildAccountRow(
            iconBg: _verdigris.withOpacity(0.1),
            icon: '🛡',
            label: 'Manage Subscription',
            sub: null,
            trailing: const Icon(Icons.chevron_right, color: _textTer, size: 20),
            onTap: () {},
            hasBorder: true,
          ),

          // Sign out
          _buildAccountRow(
            iconBg: _crimson.withOpacity(0.1),
            icon: '↪',
            label: 'Sign Out',
            sub: null,
            labelColor: _crimson,
            trailing: Icon(Icons.chevron_right, color: _crimson.withOpacity(0.6), size: 20),
            onTap: _logout,
            hasBorder: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required Color iconBg,
    required String icon,
    required String label,
    required String? sub,
    required Widget trailing,
    required VoidCallback onTap,
    required bool hasBorder,
    Color? labelColor,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: hasBorder
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)))
            : null,
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: loading
                  ? const Center(
                      child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _verdigris)))
                  : Center(
                      child: Text(icon,
                          style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: labelColor ?? _white)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _textSec)),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _textTer,
            letterSpacing: 2.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Avatar — square with gradient border + edit badge
// ─────────────────────────────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String name;
  const _UserAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72, height: 72,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [_verdigris, _chartreuse],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _surfaceEl,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'W',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _white),
              ),
            ),
          ),
        ),
        // Edit badge
        Positioned(
          bottom: -4, left: -4,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _verdigris,
              shape: BoxShape.circle,
              border: Border.all(color: _bg, width: 2),
            ),
            child: const Icon(Icons.edit_rounded,
                color: _white, size: 11),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models for list items
// ─────────────────────────────────────────────────────────────────────────────
class _RowData {
  final String icon;
  final String label;
  final String value;
  final bool isLast;
  const _RowData(this.icon, this.label, this.value, {this.isLast = false});
}

class _PerfStat {
  final String label;
  final String value;
  final Color  color;
  const _PerfStat(this.label, this.value, this.color);
}

class _PerfCard {
  final String icon;
  final String label;
  final String value;
  final String trend;
  final bool   trendUp;
  final Color  color;
  const _PerfCard(this.icon, this.label, this.value,
      this.trend, this.trendUp, this.color);
}
