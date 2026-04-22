import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state.dart';
import 'connect_screen.dart' show kProfileBg, kProfileCard, kProfileBorder, kProfileGradient;

// ─────────────────────────────────────────────────────────────────────────────
// Buddy Settings screen — avatar selection + preferences
// ─────────────────────────────────────────────────────────────────────────────
class BuddySettingsScreen extends ConsumerStatefulWidget {
  const BuddySettingsScreen({super.key});

  @override
  ConsumerState<BuddySettingsScreen> createState() =>
      _BuddySettingsScreenState();
}

class _BuddySettingsScreenState extends ConsumerState<BuddySettingsScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  String _selectedAvatar = 'Male';

  @override
  void initState() {
    super.initState();
    _selectedAvatar =
        ref.read(buddyAvatarGenderProvider) == 'female' ? 'Female' : 'Male';
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: kProfileGradient,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                children: [
                  _header(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Select Avatar'),
                          const SizedBox(height: 14),
                          _avatarGrid(),
                          const SizedBox(height: 28),
                          _sectionLabel('Voice & Personality'),
                          const SizedBox(height: 12),
                          _prefRow('Voice Style',   'Calm'),
                          const SizedBox(height: 10),
                          _prefRow('Response Mode', 'Concise'),
                          const SizedBox(height: 10),
                          _prefRow('Language',      'English'),
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
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          _backBtn(context),
          const SizedBox(width: 12),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A28),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.settings_rounded, color: Color(0xFF90A4AE), size: 18),
          ),
          const SizedBox(width: 10),
          Text('Buddy Settings',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  // ── Avatar grid (Male / Female) ────────────────────────────────────────────
  Widget _avatarGrid() {
    return Row(
      children: [
        Expanded(child: _avatarCard('Male',   _maleAvatar(),   const Color(0xFF7EC8E3))),
        const SizedBox(width: 14),
        Expanded(child: _avatarCard('Female', _femaleAvatar(), const Color(0xFFE8A5C8))),
      ],
    );
  }

  Widget _avatarCard(String label, Widget avatar, Color accent) {
    final selected = _selectedAvatar == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedAvatar = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1B998B).withOpacity(0.12)
              : kProfileCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF1B998B)
                : kProfileBorder,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            // Avatar illustration placeholder
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: kProfileBg,
              ),
              child: Center(child: avatar),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 8),
            if (selected)
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B998B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              )
            else
              const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // Male avatar — real buddy image
  Widget _maleAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/avatars/buddy_male.png',
        width: 74,
        height: 74,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.face_rounded,
          color: Color(0xFF7EC8E3),
          size: 42,
        ),
      ),
    );
  }

  // Female avatar — real buddy image
  Widget _femaleAvatar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/avatars/buddy_female.png',
        width: 74,
        height: 74,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.face_3_rounded,
          color: Color(0xFFE8A5C8),
          size: 42,
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(text.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: const Color(0xFF5A7A78), letterSpacing: 1.0));
  }

  // ── Preference row ─────────────────────────────────────────────────────────
  Widget _prefRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kProfileCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kProfileBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white))),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF1B998B),
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCB9A2D), size: 20),
        ],
      ),
    );
  }

  Widget _backBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF1A3530),
          shape: BoxShape.circle,
          border: Border.all(color: kProfileBorder),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
      ),
    );
  }
}
