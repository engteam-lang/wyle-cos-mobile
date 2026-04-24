import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reusable coming-soon overlay mixin.
//
// Usage in any ConsumerStatefulWidget:
//   1. mixin ComingSoonMixin<T extends StatefulWidget> on State<T>
//      → already done: just `with ComingSoonMixin` on your State class.
//   2. Call `showComingSoon(label)` on Connect button tap.
//   3. Wrap your Scaffold in a Stack and add `if (csVisible) buildComingSoonOverlay()`.
//   4. Call `disposeComingSoon()` inside your dispose().
// ─────────────────────────────────────────────────────────────────────────────
mixin ComingSoonMixin<T extends StatefulWidget> on State<T> {
  bool   csVisible  = false;
  String csProvider = '';
  Timer? _csTimer;

  void showComingSoon(String providerLabel) {
    _csTimer?.cancel();
    setState(() {
      csProvider = providerLabel;
      csVisible  = true;
    });
    _csTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => csVisible = false);
    });
  }

  void disposeComingSoon() {
    _csTimer?.cancel();
  }

  Widget buildComingSoonOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          _csTimer?.cancel();
          setState(() => csVisible = false);
        },
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent tap-through
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF001A24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFCB9A2D), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCB9A2D).withOpacity(0.18),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A10),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFCB9A2D).withOpacity(0.4)),
                      ),
                      child: const Center(
                        child: Text('🚀',
                            style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Coming Soon',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      '$csProvider integration\nis on its way!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFFCB9A2D),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
