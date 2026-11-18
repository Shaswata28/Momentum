import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'retro_typography.dart';

class AppTypography {
  static TextStyle get displayHeading => AppColors.isRetro
      ? RetroTypography.displayHeading
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        );

  static TextStyle get titleLarge => AppColors.isRetro
      ? RetroTypography.titleLarge
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        );

  static TextStyle get headline => AppColors.isRetro
      ? RetroTypography.headline
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        );

  /// Clean, human section label (retro: pixelated uppercase label)
  static TextStyle get sectionLabel => AppColors.isRetro
      ? RetroTypography.sectionLabel
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        );

  /// Overline uppercase micro-label
  static TextStyle get overline => AppColors.isRetro
      ? RetroTypography.overline
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPlaceholder,
          letterSpacing: 1.0,
        );

  static TextStyle get cardTitle => AppColors.isRetro
      ? RetroTypography.cardTitle
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        );

  /// Mono time / micro-label (clean aligned digits)
  static TextStyle get cardTime => AppColors.isRetro
      ? RetroTypography.cardTime
      : TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.accentPrimary,
        );

  /// Body / description text
  static TextStyle get bodyText => AppColors.isRetro
      ? RetroTypography.bodyText
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.45,
        );

  /// Caption / helper text
  static TextStyle get caption => AppColors.isRetro
      ? RetroTypography.caption
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
          height: 1.35,
        );

  /// Tag chips
  static TextStyle get tagChip => AppColors.isRetro
      ? RetroTypography.tagChip
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        );

  /// Button labels
  static TextStyle get buttonLabel => AppColors.isRetro
      ? RetroTypography.buttonLabel
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );

  /// Nav labels — clean proportional font (retro: 8-bit micro font)
  static TextStyle get navLabel => AppColors.isRetro
      ? RetroTypography.navLabel
      : TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );

  /// Mono numeric stats for numbers and percentages
  static TextStyle get scoreStat => AppColors.isRetro
      ? RetroTypography.scoreStat
      : TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        );

  /// Large monetary / balance displays
  static TextStyle get amountLarge => AppColors.isRetro
      ? RetroTypography.amountLarge
      : TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        );

  /// Medium monetary / metric displays
  static TextStyle get amountMedium => AppColors.isRetro
      ? RetroTypography.amountMedium
      : TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
        );
}
