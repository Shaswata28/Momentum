import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayHeading => GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// Gray mono labels (was 10px → 12px)
  static TextStyle get sectionLabel => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textPlaceholder,
        letterSpacing: 1.0,
      );

  static TextStyle get cardTitle => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  /// Mono time / micro-label (was 10px → 12px)
  static TextStyle get cardTime => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.accentPrimary,
      );

  /// Body / description text (was 13px → 15px)
  static TextStyle get bodyText => GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// Tag chips (was 10px → 12px)
  static TextStyle get tagChip => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  /// Button labels (was 12px → 14px)
  static TextStyle get buttonLabel => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      );

  /// Nav labels — kept at 10px, increasing would break nav bar layout
  static TextStyle get navLabel => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
      );

  /// Mono numeric stats (was 11px → 13px)
  static TextStyle get scoreStat => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      );
}
