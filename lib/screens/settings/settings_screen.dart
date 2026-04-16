import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state.dart';

const _bg      = Color(0xFF0D0D0D);
const _surface = Color(0xFF161616);
const _border  = Color(0xFF2A2A2A);
const _verdigris= Color(0xFF1B998B);
const _white   = Color(0xFFFFFFFF);
const _textSec = Color(0xFF9A9A9A);
const _textTer = Color(0xFF555555);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: _surface, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Settings', style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
              ]),
            ),
            Expanded(
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _verdigris.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.settings_outlined, color: _verdigris, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Settings', style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
                  const SizedBox(height: 8),
                  Text('Coming soon — manage your preferences\nand app configuration here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: _textSec, height: 1.5)),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }
}
