import 'package:flutter/material.dart';

/// Wyle Brand Color Palette — from brand guidelines PDF
class AppColors {
  AppColors._();

  // ── Core backgrounds ────────────────────────────────────────────────────────
  static const Color background     = Color(0xFF002F3A); // Jet Black (primary)
  static const Color backgroundPure = Color(0xFF000000); // Pure black
  static const Color surface        = Color(0xFF0A3D4A); // Slightly lighter
  static const Color surfaceElevated= Color(0xFF0F4A5A); // Cards, elevated
  static const Color surfaceHigh    = Color(0xFF155060); // Active states

  // ── Dark variant (HomeScreen uses slightly darker palette) ──────────────────
  static const Color bgDark         = Color(0xFF0D0D0D);
  static const Color surfaceDark    = Color(0xFF161616);
  static const Color surfaceElDark  = Color(0xFF1E1E1E);
  static const Color borderDark     = Color(0xFF2A2A2A);

  // ── Primary brand ───────────────────────────────────────────────────────────
  static const Color verdigris      = Color(0xFF1B998B); // Trust, balance
  static const Color verdigrisDark  = Color(0xFF157A6E); // Pressed

  // ── Secondary palette ───────────────────────────────────────────────────────
  static const Color chartreuse     = Color(0xFFD5FF3F); // CTA / action
  static const Color chartreuseB    = Color(0xFFA8CC00); // Pressed chartreuse
  static const Color sweetSalmon    = Color(0xFFFF9F8A); // Warmth / buddy
  static const Color crimson        = Color(0xFFD7263D); // Urgency / high risk
  static const Color crimsonDark    = Color(0xFFFF3B30); // HomeScreen variant
  static const Color orange         = Color(0xFFFF9500); // Medium urgency
  static const Color white          = Color(0xFFFEFFFE); // Clarity

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFFEFFFE);
  static const Color textSecondary  = Color(0xFF8FB8BF);
  static const Color textTertiary   = Color(0xFF4A7A85);
  static const Color textInverse    = Color(0xFF002F3A); // On bright bg

  // ── Text (dark variant) ─────────────────────────────────────────────────────
  static const Color textSecDark    = Color(0xFF9A9A9A);
  static const Color textTerDark    = Color(0xFF555555);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color riskHigh       = Color(0xFFD7263D);
  static const Color riskMedium     = Color(0xFFD5FF3F);
  static const Color riskLow        = Color(0xFF1B998B);
  static const Color success        = Color(0xFF1B998B);
  static const Color warning        = Color(0xFFD5FF3F);
  static const Color error          = Color(0xFFD7263D);

  // ── UI ──────────────────────────────────────────────────────────────────────
  static const Color border         = Color(0xFF1A5060);
  static const Color divider        = Color(0xFF0F3D4A);
  static const Color overlay        = Color(0xD9002F3A); // rgba(0,47,58,0.85)
  static const Color transparent    = Colors.transparent;

  // ── Google Brand ────────────────────────────────────────────────────────────
  static const Color googleBlue     = Color(0xFF4285F4);
  static const Color googleRed      = Color(0xFFEA4335);
  static const Color googleYellow   = Color(0xFFFBBC05);
  static const Color googleGreen    = Color(0xFF34A853);

  // ── Gradient helpers ────────────────────────────────────────────────────────
  static const List<Color> brandGradient = [
    Color(0xFF1B998B),
    Color(0xFFD5FF3F),
  ];

  static const List<Color> backgroundGradient = [
    Color(0xFF002F3A),
    Color(0xFF001820),
    Color(0xFF000000),
  ];

  static const List<Color> hologramGradient = [
    Color(0xFF00C8FF),
    Color(0xFF1B998B),
    Color(0xFFA8FF3E),
    Color(0xFFFF6B35),
  ];

  static const List<Color> urgentGradient = [
    Color(0xFFFF9F8A),
    Color(0xFFD7263D),
  ];

  static const List<Color> executeGradient = [
    Color(0xFFD5FF3F),
    Color(0xFFA8CC00),
  ];

  /// Returns color for a given risk level
  static Color forRisk(String risk) {
    switch (risk) {
      case 'high':   return riskHigh;
      case 'medium': return riskMedium;
      case 'low':    return riskLow;
      default:       return riskLow;
    }
  }

  /// Returns risk color based on days until due
  static Color forDays(String risk, int days) {
    if (risk == 'high'   || days <= 7)  return crimsonDark;
    if (risk == 'medium' || days <= 21) return orange;
    return verdigris;
  }
}
