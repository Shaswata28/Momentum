import 'package:flutter/material.dart';

/// Dark Palette — Things 3 & Apple Dark aesthetic
abstract final class DarkColors {
  static const Color appBackground = Color(0xFF0F1015);
  static const Color cardBackground = Color(0xFF171821);
  static const Color cardHoverActive = Color(0xFF1E202C);
  static const Color elevatedSurface = Color(0xFF222433);
  static const Color inputBackground = Color(0xFF13141E);
  static const Color modalBackground = Color(0xFF161722);
  static const Color dividerBorderHover = Color(0xFF2B2D3E);
  static const Color subtleBorder = Color(0x1AFFFFFF); // Translucent 10% white
  static const Color cardBorder = Color(0x12FFFFFF);   // Translucent 7% white

  static const Color accentPrimary = Color(0xFF388AF6);
  static const Color accentPressed = Color(0xFF2563EB);
  static const Color accentTintBackground = Color(0x1F388AF6);
  static const Color accentTagBackground = Color(0x2B388AF6);

  static const Color fixedTask = Color(0xFF388AF6);
  static const Color floatingTask = Color(0xFF6366F1);
  static const Color adHocTask = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textPlaceholder = Color(0xFF475569);

  static const Color infoAccent = Color(0xFF388AF6);
  static const Color successDone = Color(0xFF10B981);
  static const Color warningTag = Color(0xFFF59E0B);
  static const Color warningFloating = Color(0xFFF59E0B);
  static const Color errorAlert = Color(0xFFEF4444);
  static const Color dangerOverdue = Color(0xFFEF4444);
}

/// Light Palette — Apple System Grouped & Things 3 Light aesthetic
abstract final class LightColors {
  static const Color appBackground = Color(0xFFF2F2F7);     // Apple System Grouped Gray
  static const Color cardBackground = Color(0xFFFFFFFF);    // Pure White Card
  static const Color cardHoverActive = Color(0xFFE5E5EA);   // Light Apple Gray Active
  static const Color elevatedSurface = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFE5E7EB);   // Clean Light Input
  static const Color modalBackground = Color(0xFFFFFFFF);
  static const Color dividerBorderHover = Color(0xFFE2E8F0);
  static const Color subtleBorder = Color(0x14000000);      // 8% Black Outline
  static const Color cardBorder = Color(0x0F000000);        // 6% Black Outline

  static const Color accentPrimary = Color(0xFF2563EB);     // Focus Blue (accessible contrast on light)
  static const Color accentPressed = Color(0xFF1D4ED8);
  static const Color accentTintBackground = Color(0x1A2563EB);
  static const Color accentTagBackground = Color(0x242563EB);

  static const Color fixedTask = Color(0xFF2563EB);
  static const Color floatingTask = Color(0xFF4F46E5);
  static const Color adHocTask = Color(0xFFD97706);

  static const Color textPrimary = Color(0xFF0F172A);       // Slate 900
  static const Color textSecondary = Color(0xFF475569);     // Slate 600
  static const Color textMuted = Color(0xFF64748B);         // Slate 500
  static const Color textPlaceholder = Color(0xFF94A3B8);   // Slate 400

  static const Color infoAccent = Color(0xFF2563EB);
  static const Color successDone = Color(0xFF059669);       // Emerald 600
  static const Color warningTag = Color(0xFFD97706);        // Amber 600
  static const Color warningFloating = Color(0xFFD97706);
  static const Color errorAlert = Color(0xFFDC2626);        // Red 600
  static const Color dangerOverdue = Color(0xFFDC2626);
}

/// Dynamic Color Tokens adapter for Momentum.
/// Evaluates colors in real time based on active theme brightness ([isDark]).
class AppColors {
  /// Whether the app is currently rendering in dark mode.
  static bool isDark = true;

  // Background layers
  static Color get appBackground => isDark ? DarkColors.appBackground : LightColors.appBackground;
  static Color get cardBackground => isDark ? DarkColors.cardBackground : LightColors.cardBackground;
  static Color get cardHoverActive => isDark ? DarkColors.cardHoverActive : LightColors.cardHoverActive;
  static Color get elevatedSurface => isDark ? DarkColors.elevatedSurface : LightColors.elevatedSurface;
  static Color get inputBackground => isDark ? DarkColors.inputBackground : LightColors.inputBackground;
  static Color get modalBackground => isDark ? DarkColors.modalBackground : LightColors.modalBackground;
  static Color get dividerBorderHover => isDark ? DarkColors.dividerBorderHover : LightColors.dividerBorderHover;
  static Color get subtleBorder => isDark ? DarkColors.subtleBorder : LightColors.subtleBorder;
  static Color get cardBorder => isDark ? DarkColors.cardBorder : LightColors.cardBorder;

  // Accent Colors
  static Color get accentPrimary => isDark ? DarkColors.accentPrimary : LightColors.accentPrimary;
  static Color get accentPressed => isDark ? DarkColors.accentPressed : LightColors.accentPressed;
  static Color get accentTintBackground => isDark ? DarkColors.accentTintBackground : LightColors.accentTintBackground;
  static Color get accentTagBackground => isDark ? DarkColors.accentTagBackground : LightColors.accentTagBackground;

  // Task type colors
  static Color get fixedTask => isDark ? DarkColors.fixedTask : LightColors.fixedTask;
  static Color get floatingTask => isDark ? DarkColors.floatingTask : LightColors.floatingTask;
  static Color get adHocTask => isDark ? DarkColors.adHocTask : LightColors.adHocTask;

  // Text hierarchy
  static Color get textPrimary => isDark ? DarkColors.textPrimary : LightColors.textPrimary;
  static Color get textSecondary => isDark ? DarkColors.textSecondary : LightColors.textSecondary;
  static Color get textMuted => isDark ? DarkColors.textMuted : LightColors.textMuted;
  static Color get textPlaceholder => isDark ? DarkColors.textPlaceholder : LightColors.textPlaceholder;

  // Semantic
  static Color get infoAccent => isDark ? DarkColors.infoAccent : LightColors.infoAccent;
  static Color get successDone => isDark ? DarkColors.successDone : LightColors.successDone;
  static Color get warningTag => isDark ? DarkColors.warningTag : LightColors.warningTag;
  static Color get warningFloating => isDark ? DarkColors.warningFloating : LightColors.warningFloating;
  static Color get errorAlert => isDark ? DarkColors.errorAlert : LightColors.errorAlert;
  static Color get dangerOverdue => isDark ? DarkColors.dangerOverdue : LightColors.dangerOverdue;

  // Convenience border
  static Color get borderColor => isDark ? DarkColors.cardBorder : LightColors.cardBorder;
}
