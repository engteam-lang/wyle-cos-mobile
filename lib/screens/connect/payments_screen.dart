import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'connect_screen.dart' show kProfileBg, kProfileCard, kProfileBorder;

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  final Map<String, bool> _connected = {
    'Stripe':  false,
    'PayPal':  false,
    'Apple Pay': false,
    'Tabby':   false,
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

  static const _meta = {
    'Stripe':    (Color(0xFF6772E5), Color(0xFF0D0A2E), Icons.credit_card_rounded,    'Online Payment Gateway'),
    'PayPal':    (Color(0xFF009CDE), Color(0xFF0A1A2E), Icons.account_balance_wallet_rounded, 'Digital Wallet'),
    'Apple Pay': (Color(0xFFAAAAAA), Color(0xFF1A1A1A), Icons.phone_iphone_rounded,   'NFC & Online Payments'),
    'Tabby':     (Color(0xFF3DD598), Color(0xFF0A2A1E), Icons.splitscreen_rounded,    'Buy Now, Pay Later'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileBg,
      body: Container(
        color: kProfileBg,
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
                        children: _connected.entries.map((e) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _card(e.key, e.value),
                          )).toList(),
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

  Widget _card(String name, bool connected) {
    final m         = _meta[name]!;
    final accent    = m.$1;
    final iconBg    = m.$2;
    final iconData  = m.$3;
    final subtitle  = m.$4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected ? Color.lerp(iconBg, kProfileCard, 0.4)! : kProfileCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected ? accent.withOpacity(0.5) : kProfileBorder,
          width: connected ? 1.5 : 1.0,
        ),
        boxShadow: connected
            ? [BoxShadow(color: accent.withOpacity(0.14), blurRadius: 16)]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(iconData, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(connected ? 'Connected' : subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: connected ? accent : const Color(0xFF6A8E8C))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _connected[name] = !connected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: connected
                    ? accent.withOpacity(0.12)
                    : const Color(0xFF1B998B).withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: connected
                      ? accent.withOpacity(0.4)
                      : const Color(0xFF1B998B).withOpacity(0.4),
                ),
              ),
              child: Text(
                connected ? 'Disconnect' : 'Connect',
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: connected ? accent : const Color(0xFF1B998B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            color: const Color(0xFF0A2E4A), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.credit_card_rounded, color: Color(0xFF29B6F6), size: 18),
        ),
        const SizedBox(width: 10),
        Text('Payments',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    ),
  );
}
