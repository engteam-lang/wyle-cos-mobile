import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'connect_screen.dart' show kProfileBg, kProfileCard, kProfileBorder, kProfileGradient;

class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});
  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  final Map<String, bool> _enabled = {
    'Morning Brief Auto-Send':  true,
    'Smart Reply Suggestions':  true,
    'Task Auto-Priority':       false,
    'Calendar Block Scheduling':false,
    'Invoice Auto-Drafting':    false,
  };

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  static const _subtitles = {
    'Morning Brief Auto-Send':   'Send brief to your email at 6:00 AM',
    'Smart Reply Suggestions':   'AI-suggested message replies',
    'Task Auto-Priority':        'Re-rank tasks as deadlines approach',
    'Calendar Block Scheduling': 'Block focus time automatically',
    'Invoice Auto-Drafting':     'Draft invoices from chat context',
  };

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
                          _sectionLabel('Active Automations'),
                          const SizedBox(height: 12),
                          ..._enabled.entries.map((e) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _toggleCard(e.key, e.value),
                            )).toList(),
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

  Widget _toggleCard(String name, bool enabled) {
    const teal = Color(0xFF26C6DA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF0A2A2E)
            : kProfileCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? teal.withOpacity(0.4) : kProfileBorder,
          width: enabled ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A28),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              enabled ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
              color: teal, size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(_subtitles[name]!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF6A8E8C))),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => setState(() => _enabled[name] = v),
            activeColor: teal,
            activeTrackColor: teal.withOpacity(0.3),
            inactiveThumbColor: const Color(0xFF5A7A78),
            inactiveTrackColor: kProfileBorder,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text.toUpperCase(),
      style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF5A7A78), letterSpacing: 1.0));

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3530), shape: BoxShape.circle,
              border: Border.all(color: kProfileBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF0A2A28), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF26C6DA), size: 18),
        ),
        const SizedBox(width: 10),
        Text('Automation',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    ),
  );
}
