import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayHeading => GoogleFonts.dmSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get titleLarge => GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get headline => GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  /// Clean, human section label (replaces robotic monospace uppercase)
  static TextStyle get sectionLabel => GoogleFonts.dmSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      );

  /// Overline uppercase micro-label
  static TextStyle get overline => GoogleFonts.dmSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPlaceholder,
        letterSpacing: 1.0,
      );

  static TextStyle get cardTitle => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  /// Mono time / micro-label (clean aligned digits)
  static TextStyle get cardTime => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.accentPrimary,
      );

  /// Body / description text
  static TextStyle get bodyText => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  /// Caption / helper text
  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        height: 1.35,
      );

  /// Tag chips
  static TextStyle get tagChip => GoogleFonts.dmSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      );

  /// Button labels
  static TextStyle get buttonLabel => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  /// Nav labels — clean proportional font
  static TextStyle get navLabel => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );

  /// Mono numeric stats for numbers and percentages
  static TextStyle get scoreStat => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );

  /// Large monetary / balance displays
  static TextStyle get amountLarge => GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  /// Medium monetary / metric displays
  static TextStyle get amountMedium => GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      );
}
