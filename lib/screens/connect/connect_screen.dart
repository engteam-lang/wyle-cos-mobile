import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state.dart';
import '../../services/google_auth_service.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);
const _crimson   = Color(0xFFFF3B30);

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  bool _googleConnecting = false;

  Future<void> _connectGoogle() async {
    setState(() => _googleConnecting = true);
    try {
      final result = await GoogleAuthService.instance.signIn();
      if (result.success) {
        ref.read(appStateProvider.notifier).addGoogleAccount(result.email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Connected as ${result.email}'),
            backgroundColor: _verdigris,
          ));
        }
      } else if (result.error != null && result.error != 'Cancelled') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sign-in failed: ${result.error}'),
            backgroundColor: _crimson,
          ));
        }
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
        title: Text('Disconnect Google', style: GoogleFonts.poppins(color: _white)),
        content: Text('Remove $email from Wyle?',
            style: GoogleFonts.inter(color: _textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Disconnect', style: TextStyle(color: _crimson))),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(appStateProvider.notifier).removeGoogleAccount(email);
    }
  }

  Future<void> _disconnectOutlook(String email) async {
    ref.read(appStateProvider.notifier).removeOutlookAccount(email);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: GoogleFonts.poppins(color: _white)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.inter(color: _textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text('Sign Out', style: TextStyle(color: _crimson))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(appStateProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final user  = state.user;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildUserCard(user?.name ?? 'User', user?.email ?? ''),
              _buildStatsRow(state),
              _buildSectionLabel('CONNECTED ACCOUNTS'),
              _buildGoogleSection(state),
              _buildOutlookSection(state),
              _buildSectionLabel('APP SETTINGS'),
              _buildSettingsTile(Icons.tune_rounded, 'Preferences', () {}),
              _buildSettingsTile(Icons.shield_outlined, 'Privacy & Security', () {}),
              _buildSettingsTile(Icons.help_outline_rounded, 'Help & Support', () {}),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _crimson.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _crimson.withOpacity(0.3)),
                    ),
                    child: Center(child: Text('Sign Out',
                        style: GoogleFonts.inter(
                            color: _crimson, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Profile', style: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w700, color: _white)),
      Text('Manage accounts & settings',
          style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
    ]),
  );

  Widget _buildUserCard(String name, String email) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_verdigris.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _verdigris.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_verdigris, Color(0xFFD5FF3F)]),
          ),
          child: Center(child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'W',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: _white),
          )),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
            Text(email, style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _verdigris.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _verdigris.withOpacity(0.3))),
          child: Text('PRO', style: GoogleFonts.inter(
              fontSize: 10, color: _verdigris, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _buildStatsRow(AppState state) {
    final active   = state.obligations.where((o) => o.status != 'completed').length;
    final gAccounts= state.googleAccounts.length;
    final olAccounts= state.outlookAccounts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(children: [
        Expanded(child: _statCell('${active}', 'Tasks Active')),
        _vDivider(),
        Expanded(child: _statCell('$gAccounts', 'Google Accts')),
        _vDivider(),
        Expanded(child: _statCell('$olAccounts', 'Outlook Accts')),
      ]),
    );
  }

  Widget _statCell(String val, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
        color: _surface, border: Border.all(color: _border)),
    child: Column(children: [
      Text(val, style: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w700, color: _white)),
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textSec)),
    ]),
  );

  Widget _vDivider() => Container(width: 1, height: 50, color: _border);

  Widget _buildSectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
    child: Text(label, style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: _textTer, letterSpacing: 1.5)),
  );

  Widget _buildGoogleSection(AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: Column(
        children: [
          ...state.googleAccounts.map((email) => _connectedAccountTile(
            email: email,
            icon: '🔵',
            label: 'Google',
            onDisconnect: () => _disconnectGoogle(email),
          )),
          if (state.googleAccounts.isEmpty || true)
            _addAccountTile(
              label: _googleConnecting ? 'Connecting…' : 'Add Google Account',
              icon: Icons.add_circle_outline,
              color: const Color(0xFF4285F4),
              loading: _googleConnecting,
              onTap: _googleConnecting ? null : _connectGoogle,
            ),
        ],
      ),
    );
  }

  Widget _buildOutlookSection(AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: Column(
        children: [
          ...state.outlookAccounts.map((email) => _connectedAccountTile(
            email: email,
            icon: '🟦',
            label: 'Outlook',
            onDisconnect: () => _disconnectOutlook(email),
          )),
          _addAccountTile(
            label: 'Add Outlook Account',
            icon: Icons.add_circle_outline,
            color: const Color(0xFF0078D4),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _connectedAccountTile({
    required String email,
    required String icon,
    required String label,
    required VoidCallback onDisconnect,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(
                fontSize: 11, color: _textTer, fontWeight: FontWeight.w600)),
            Text(email, style: GoogleFonts.inter(fontSize: 13, color: _white)),
          ],
        )),
        Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(color: _verdigris, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onDisconnect,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: _crimson.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _crimson.withOpacity(0.25))),
            child: Text('Remove', style: GoogleFonts.inter(
                fontSize: 11, color: _crimson, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _addAccountTile({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(
              fontSize: 14, color: color, fontWeight: FontWeight.w500)),
          if (loading) ...[
            const Spacer(),
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _verdigris)),
          ],
        ]),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
        child: Row(children: [
          Icon(icon, color: _textSec, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.inter(fontSize: 14, color: _white))),
          const Icon(Icons.chevron_right, color: _textTer, size: 18),
        ]),
      ),
    );
  }
}
