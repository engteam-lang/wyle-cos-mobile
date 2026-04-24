import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared palette used by every profile sub-screen
// Gradient matches the login screen exactly.
// ─────────────────────────────────────────────────────────────────────────────
const kProfileBg     = Color(0xFF000D12);   // darkest stop — Scaffold bg
const kProfileCard   = Color(0xFF0A2A38);   // card bg
const kProfileBorder = Color(0xFF1C4A56);   // card border

const kProfileGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF002F3A),
      Color(0xFF001E29),
      Color(0xFF000D12),
    ],
    stops: [0.0, 0.6, 1.0],
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Profile Screen — connections hub
// ─────────────────────────────────────────────────────────────────────────────
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _enterCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // Morning brief time (stub — persisted via provider later)
  TimeOfDay _briefTime = const TimeOfDay(hour: 6, minute: 0);

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420))
      ..forward();
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final user  = state.user;
    final name        = user?.name ?? 'User';
    final gender      = ref.watch(buddyAvatarGenderProvider);
    final role        = user?.designation ?? '';

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
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserCard(name, role, gender),
                          const SizedBox(height: 24),

                          // ── Connection category rows ───────────────────────
                          ..._sections.map(_buildRow).toList(),

                          const SizedBox(height: 10),
                          _buildDivider(),
                          const SizedBox(height: 10),

                          // ── Settings rows ──────────────────────────────────
                          _buildSettingsRow(
                            label: 'Morning Brief Time',
                            value: _briefTime.format(context),
                            onTap: _pickBriefTime,
                          ),
                          const SizedBox(height: 10),
                          _buildSettingsRow(
                            label: 'Theme',
                            value: 'Dark',
                            onTap: () {},   // TODO: theme toggle
                          ),

                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 20),

                          // ── Sign out ───────────────────────────────────────
                          _buildSignOut(context),
                          const SizedBox(height: 8),
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
          Text('Profile',
              style: GoogleFonts.poppins(
                fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go(AppRoutes.buddy),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3530),
                shape: BoxShape.circle,
                border: Border.all(color: kProfileBorder),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar + name ──────────────────────────────────────────────────────────
  Widget _buildUserCard(String name, String role, String gender) {
    final isMale = gender != 'female';
    final assetPath = isMale
        ? 'assets/avatars/buddy_male.png'
        : 'assets/avatars/buddy_female.png';
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A2A38),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B998B).withOpacity(0.28),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                assetPath,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'W',
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(name,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          if (role.isNotEmpty)
            Text(role,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF7AACB8))),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Single category row ────────────────────────────────────────────────────
  Widget _buildRow(_ProfileSection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: s.onTap ?? () => _navigate(context, s.label),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: kProfileCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kProfileBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: s.iconBg, borderRadius: BorderRadius.circular(11)),
                child: Center(child: s.icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(s.label,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w500,
                        color: Colors.white)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFCB9A2D), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings row (Morning Brief Time / Theme) ──────────────────────────────
  Widget _buildSettingsRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: kProfileCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kProfileBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: Colors.white)),
            ),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B998B))),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCB9A2D), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────
  Widget _buildSignOut(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmSignOut(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF2A0E0E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF5C1A1A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded,
                color: Color(0xFFFF6B6B), size: 20),
            const SizedBox(width: 10),
            Text('Sign Out',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF6B6B))),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
        height: 1, color: kProfileBorder.withOpacity(0.5));
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _pickBriefTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _briefTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1B998B),
            surface: Color(0xFF132E2A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _briefTime = picked);
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF132E2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins(color: const Color(0xFF7AACB8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF7AACB8))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(appStateProvider.notifier).logout();
              if (mounted) context.go(AppRoutes.login);
            },
            child: Text('Sign Out',
                style: GoogleFonts.poppins(
                    color: const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String label) {
    switch (label) {
      case 'Calendar & Email':
        context.push(AppRoutes.calendarEmail);
      case 'Payments':
        context.push(AppRoutes.profilePayments);
      case 'Government':
        context.push(AppRoutes.profileGovernment);
      case 'Social Accounts':
        context.push(AppRoutes.profileSocial);
      case 'WhatsApp':
        context.push(AppRoutes.profileWhatsapp);
      case 'Commercial Apps':
        context.push(AppRoutes.profileCommercial);
      case 'Devices & Health':
        context.push(AppRoutes.profileDevices);
      case 'Buddy Settings':
        context.push(AppRoutes.profileBuddySettings);
      case 'Automation':
        context.push(AppRoutes.profileAutomation);
    }
  }

  // ── Section data ──────────────────────────────────────────────────────────
  static final List<_ProfileSection> _sections = [
    _ProfileSection(label: 'Calendar & Email',
      iconBg: const Color(0xFF0D3A5C),
      icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF4FC3F7), size: 22)),
    _ProfileSection(label: 'Payments',
      iconBg: const Color(0xFF0A2E4A),
      icon: const Icon(Icons.credit_card_rounded, color: Color(0xFF29B6F6), size: 22)),
    _ProfileSection(label: 'Government',
      iconBg: const Color(0xFF0D2B4A),
      icon: const Icon(Icons.shield_rounded, color: Color(0xFF5C9DE8), size: 22)),
    _ProfileSection(label: 'Social Accounts',
      iconBg: const Color(0xFF0A2A46),
      icon: const Icon(Icons.language_rounded, color: Color(0xFF42A5F5), size: 22)),
    _ProfileSection(label: 'WhatsApp',
      iconBg: const Color(0xFF0A2E1E),
      icon: const Icon(Icons.chat_rounded, color: Color(0xFF4CAF50), size: 22)),
    _ProfileSection(label: 'Commercial Apps',
      iconBg: const Color(0xFF2E1A08),
      icon: const Icon(Icons.shopping_bag_rounded, color: Color(0xFFFFA726), size: 22)),
    _ProfileSection(label: 'Devices & Health',
      iconBg: const Color(0xFF1E0A38),
      icon: const Icon(Icons.watch_rounded, color: Color(0xFFAB47BC), size: 22)),
    _ProfileSection(label: 'Buddy Settings',
      iconBg: const Color(0xFF1A2A28),
      icon: const Icon(Icons.settings_rounded, color: Color(0xFF90A4AE), size: 22)),
    _ProfileSection(label: 'Automation',
      iconBg: const Color(0xFF0A2A28),
      icon: const Icon(Icons.smart_toy_rounded, color: Color(0xFF26C6DA), size: 22)),
  ];
}

class _ProfileSection {
  final String label;
  final Color  iconBg;
  final Widget icon;
  final VoidCallback? onTap;
  const _ProfileSection({
    required this.label, required this.iconBg, required this.icon, this.onTap});
}
