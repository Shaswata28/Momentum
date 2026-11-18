import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class RetroTypography {
  // ── Responsive font-size helpers ─────────────────────────────────────────
  // Press Start 2P is a wide bitmap font; each character is ~8px wide at 8pt.
  // On 320 px viewports (after 20 px padding each side = 280 px usable) even
  // modest text at 14 px can overflow.  We scale down proportionally when the
  // screen is narrower than 360 px.  Call inside a LayoutBuilder or use
  // MediaQuery.sizeOf() at the widget level to get the real viewport.
  //
  // These static getters return the *base* sizes; individual widgets may still
  // apply FittedBox / ellipsis / maxLines as needed.

  static TextStyle get displayHeading => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get titleLarge => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get headline => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle get sectionLabel => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
    height: 1.3,
  );

  static TextStyle get overline => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 7.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPlaceholder,
    letterSpacing: 0.5,
  );

  static TextStyle get cardTitle => TextStyle(
    fontFamily: 'Pixelify Sans',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardTime => TextStyle(
    fontFamily: 'VT323',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.accentPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get bodyText => TextStyle(
    fontFamily: 'Pixelify Sans',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.35,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: 'Pixelify Sans',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.3,
  );

  static TextStyle get tagChip => TextStyle(
    fontFamily: 'Pixelify Sans',
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get buttonLabel => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: (AppColors.isRetro && !AppColors.isDark)
        ? AppColors.textPrimary
        : Colors.white,
    letterSpacing: 0.5,
  );

  static TextStyle get navLabel => TextStyle(
    fontFamily: 'Press Start 2P',
    fontSize: 7.5,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get scoreStat => TextStyle(
    fontFamily: 'VT323',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get amountLarge => TextStyle(
    fontFamily: 'VT323',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get amountMedium => TextStyle(
    fontFamily: 'VT323',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );
}
