import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/app_router.dart';
import '../../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Screen — connections hub (matches Figma design)
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
    final name  = user?.name  ?? 'User';
    final role  = 'Founder & CEO';   // TODO: pull from user profile

    return Scaffold(
      backgroundColor: const Color(0xFF0B1C1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                _buildHeader(context),
                // ── Scrollable body ─────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      children: [
                        // ── User card ──────────────────────────────────────
                        _buildUserCard(name, role),
                        const SizedBox(height: 24),
                        // ── Connection rows ────────────────────────────────
                        ..._sections.map(_buildRow).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header with title + close ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          Text(
            'Profile',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go(AppRoutes.buddy),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E2B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2A3E3B)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── User card — avatar circle + name + role ───────────────────────────────
  Widget _buildUserCard(String name, String role) {
    return Column(
      children: [
        // Avatar circle
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1B998B), Color(0xFF0A4A44)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B998B).withOpacity(0.30),
                blurRadius: 20, spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'W',
              style: GoogleFonts.poppins(
                fontSize: 30, fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role,
          style: GoogleFonts.poppins(
            fontSize: 13, color: const Color(0xFF7AACB8),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Route map: label → destination ───────────────────────────────────────
  void _handleRowTap(BuildContext context, String label) {
    switch (label) {
      case 'Calendar & Email':
        context.push(AppRoutes.calendarEmail);
        break;
      default:
        if (true) {} // coming soon
    }
  }

  // ── Single connection row ─────────────────────────────────────────────────
  Widget _buildRow(_ProfileSection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: s.onTap ?? () => _handleRowTap(context, s.label),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF132E2A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E3E3A), width: 1),
          ),
          child: Row(
            children: [
              // Icon tile
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: s.iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(child: s.icon),
              ),
              const SizedBox(width: 14),
              // Label
              Expanded(
                child: Text(
                  s.label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              // Amber chevron
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFCB9A2D), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section data ──────────────────────────────────────────────────────────
  static final List<_ProfileSection> _sections = [
    _ProfileSection(
      label:  'Calendar & Email',
      iconBg: const Color(0xFF0D3A5C),
      icon:   const Icon(Icons.calendar_today_rounded,
                  color: Color(0xFF4FC3F7), size: 22),
    ),
    _ProfileSection(
      label:  'Payments',
      iconBg: const Color(0xFF0A2E4A),
      icon:   const Icon(Icons.credit_card_rounded,
                  color: Color(0xFF29B6F6), size: 22),
    ),
    _ProfileSection(
      label:  'Government',
      iconBg: const Color(0xFF0D2B4A),
      icon:   const Icon(Icons.shield_rounded,
                  color: Color(0xFF5C9DE8), size: 22),
    ),
    _ProfileSection(
      label:  'Social Accounts',
      iconBg: const Color(0xFF0A2A46),
      icon:   const Icon(Icons.language_rounded,
                  color: Color(0xFF42A5F5), size: 22),
    ),
    _ProfileSection(
      label:  'WhatsApp',
      iconBg: const Color(0xFF0A2E1E),
      icon:   const Icon(Icons.chat_rounded,
                  color: Color(0xFF4CAF50), size: 22),
    ),
    _ProfileSection(
      label:  'Commercial Apps',
      iconBg: const Color(0xFF2E1A08),
      icon:   const Icon(Icons.shopping_bag_rounded,
                  color: Color(0xFFFFA726), size: 22),
    ),
    _ProfileSection(
      label:  'Devices & Health',
      iconBg: const Color(0xFF1E0A38),
      icon:   const Icon(Icons.watch_rounded,
                  color: Color(0xFFAB47BC), size: 22),
    ),
    _ProfileSection(
      label:  'Buddy Settings',
      iconBg: const Color(0xFF1A2A28),
      icon:   const Icon(Icons.settings_rounded,
                  color: Color(0xFF90A4AE), size: 22),
    ),
    _ProfileSection(
      label:  'Automation',
      iconBg: const Color(0xFF0A2A28),
      icon:   const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF26C6DA), size: 22),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSection {
  final String    label;
  final Color     iconBg;
  final Widget    icon;
  final VoidCallback? onTap;

  const _ProfileSection({
    required this.label,
    required this.iconBg,
    required this.icon,
    this.onTap,
  });
}
