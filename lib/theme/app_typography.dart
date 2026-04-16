import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Wyle Typography — Poppins (headline), Montserrat (subtitle), Inter (body)
class AppTypography {
  AppTypography._();

  // ── Font size scale ──────────────────────────────────────────────────────────
  static const double xs      = 11;
  static const double sm      = 13;
  static const double base    = 15;
  static const double md      = 17;
  static const double lg      = 20;
  static const double xl      = 24;
  static const double xxl     = 30;
  static const double display = 42;
  static const double hero    = 56;

  // ── Text styles (use these in widgets) ──────────────────────────────────────

  /// Hero display title — Poppins Bold
  static TextStyle get displayHero => GoogleFonts.poppins(
    fontSize: display,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Screen title — Poppins Bold
  static TextStyle get h1 => GoogleFonts.poppins(
    fontSize: xxl,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Section header — Poppins SemiBold
  static TextStyle get h2 => GoogleFonts.poppins(
    fontSize: xl,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Card title — Poppins Medium
  static TextStyle get h3 => GoogleFonts.poppins(
    fontSize: lg,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Subtitle — Montserrat SemiBold
  static TextStyle get subtitle => GoogleFonts.montserrat(
    fontSize: md,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  /// Subtitle regular — Montserrat
  static TextStyle get subtitleRegular => GoogleFonts.montserrat(
    fontSize: base,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Body — Inter Regular
  static TextStyle get body => GoogleFonts.inter(
    fontSize: base,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Body medium — Inter Medium
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: base,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Body small — Inter Regular
  static TextStyle get bodySm => GoogleFonts.inter(
    fontSize: sm,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Label — Inter SemiBold (buttons, nav, CTA)
  static TextStyle get label => GoogleFonts.inter(
    fontSize: sm,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  /// Caption — Inter regular (small meta text)
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: xs,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  /// Overline — Inter Bold uppercase (section labels like "PRIORITY TASKS")
  static TextStyle get overline => GoogleFonts.inter(
    fontSize: xs,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );

  /// Button — Inter ExtraBold
  static TextStyle get button => GoogleFonts.inter(
    fontSize: base,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );

  /// Logo — Poppins ExtraLight (WYLE wordmark)
  static TextStyle get logo => GoogleFonts.poppins(
    fontSize: 46,
    fontWeight: FontWeight.w200,
    color: AppColors.white,
    letterSpacing: 10,
  );

  /// Tab label
  static TextStyle get tabLabel => GoogleFonts.inter(
    fontSize: xs,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  /// Time string (large clock display)
  static TextStyle get timeDisplay => GoogleFonts.poppins(
    fontSize: sm,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
}
