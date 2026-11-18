import 'package:flutter/material.dart';
import 'retro_colors.dart';

/// Dark Palette — Things 3 & Apple Dark aesthetic (Clean Neutral Graphite Black)
abstract final class DarkColors {
  static const Color appBackground = Color(0xFF0B0B0E); // Deep pure graphite black (no green undertone)
  static const Color cardBackground = Color(0xFF14141B); // Crisp neutral card surface
  static const Color cardHoverActive = Color(0xFF1C1C24);
  static const Color elevatedSurface = Color(0xFF21212B);
  static const Color inputBackground = Color(0xFF101015);
  static const Color modalBackground = Color(0xFF14141B);
  static const Color dividerBorderHover = Color(0xFF262633);
  static const Color subtleBorder = Color(0x1AFFFFFF); // Translucent 10% white
  static const Color cardBorder = Color(0x12FFFFFF); // Translucent 7% white

  static const Color accentPrimary = Color(0xFF388AF6);
  static const Color accentPressed = Color(0xFF2563EB);
  static const Color accentTintBackground = Color(0x1F388AF6);
  static const Color accentTagBackground = Color(0x2B388AF6);

  static const Color fixedTask = Color(0xFF388AF6);
  static const Color floatingTask = Color(0xFF6366F1);
  static const Color adHocTask = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textPlaceholder = Color(0xFF94A3B8);

  static const Color infoAccent = Color(0xFF388AF6);
  static const Color successDone = Color(0xFF10B981);
  static const Color warningTag = Color(0xFFF59E0B);
  static const Color warningFloating = Color(0xFFF59E0B);
  static const Color errorAlert = Color(0xFFEF4444);
  static const Color dangerOverdue = Color(0xFFEF4444);
}

/// Light Palette — Apple System Grouped & Things 3 Light aesthetic
abstract final class LightColors {
  static const Color appBackground = Color(
    0xFFF2F2F7,
  ); // Apple System Grouped Gray
  static const Color cardBackground = Color(0xFFFFFFFF); // Pure White Card
  static const Color cardHoverActive = Color(
    0xFFE5E5EA,
  ); // Light Apple Gray Active
  static const Color elevatedSurface = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFE5E7EB); // Clean Light Input
  static const Color modalBackground = Color(0xFFFFFFFF);
  static const Color dividerBorderHover = Color(0xFFE2E8F0);
  static const Color subtleBorder = Color(0x14000000); // 8% Black Outline
  static const Color cardBorder = Color(0x0F000000); // 6% Black Outline

  static const Color accentPrimary = Color(
    0xFF2563EB,
  ); // Focus Blue (accessible contrast on light)
  static const Color accentPressed = Color(0xFF1D4ED8);
  static const Color accentTintBackground = Color(0x1A2563EB);
  static const Color accentTagBackground = Color(0x242563EB);

  static const Color fixedTask = Color(0xFF2563EB);
  static const Color floatingTask = Color(0xFF4F46E5);
  static const Color adHocTask = Color(0xFFD97706);

  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF526174);
  static const Color textPlaceholder = Color(0xFF526174);

  static const Color infoAccent = Color(0xFF2563EB);
  static const Color successDone = Color(0xFF059669); // Emerald 600
  static const Color warningTag = Color(0xFFD97706); // Amber 600
  static const Color warningFloating = Color(0xFFD97706);
  static const Color errorAlert = Color(0xFFDC2626); // Red 600
  static const Color dangerOverdue = Color(0xFFDC2626);
}

/// Dynamic Color Tokens adapter for Momentum.
/// Evaluates colors in real time based on active theme brightness ([isDark]) and mode ([isRetro]).
class AppColors {
  /// Whether the app is currently rendering in dark mode.
  static bool isDark = true;

  /// Whether the app is currently rendering in retro 8-bit console mode.
  static bool isRetro = false;

  // Background layers
  static Color get appBackground => isRetro
      ? (isDark
            ? RetroDarkColors.appBackground
            : RetroLightColors.appBackground)
      : (isDark ? DarkColors.appBackground : LightColors.appBackground);

  static Color get cardBackground => isRetro
      ? (isDark
            ? RetroDarkColors.cardBackground
            : RetroLightColors.cardBackground)
      : (isDark ? DarkColors.cardBackground : LightColors.cardBackground);

  static Color get cardHoverActive => isRetro
      ? (isDark
            ? RetroDarkColors.cardHoverActive
            : RetroLightColors.cardHoverActive)
      : (isDark ? DarkColors.cardHoverActive : LightColors.cardHoverActive);

  static Color get elevatedSurface => isRetro
      ? (isDark
            ? RetroDarkColors.elevatedSurface
            : RetroLightColors.elevatedSurface)
      : (isDark ? DarkColors.elevatedSurface : LightColors.elevatedSurface);

  static Color get inputBackground => isRetro
      ? (isDark
            ? RetroDarkColors.inputBackground
            : RetroLightColors.inputBackground)
      : (isDark ? DarkColors.inputBackground : LightColors.inputBackground);

  static Color get modalBackground => isRetro
      ? (isDark
            ? RetroDarkColors.modalBackground
            : RetroLightColors.modalBackground)
      : (isDark ? DarkColors.modalBackground : LightColors.modalBackground);

  static Color get dividerBorderHover => isRetro
      ? (isDark
            ? RetroDarkColors.dividerBorderHover
            : RetroLightColors.dividerBorderHover)
      : (isDark
            ? DarkColors.dividerBorderHover
            : LightColors.dividerBorderHover);

  static Color get subtleBorder => isRetro
      ? (isDark ? RetroDarkColors.subtleBorder : RetroLightColors.subtleBorder)
      : (isDark ? DarkColors.subtleBorder : LightColors.subtleBorder);

  static Color get cardBorder => isRetro
      ? (isDark ? RetroDarkColors.cardBorder : RetroLightColors.cardBorder)
      : (isDark ? DarkColors.cardBorder : LightColors.cardBorder);

  // Accent Colors
  static Color get accentPrimary => isRetro
      ? (isDark
            ? RetroDarkColors.accentPrimary
            : RetroLightColors.accentPrimary)
      : (isDark ? DarkColors.accentPrimary : LightColors.accentPrimary);

  static Color get accentPressed => isRetro
      ? (isDark
            ? RetroDarkColors.accentPressed
            : RetroLightColors.accentPressed)
      : (isDark ? DarkColors.accentPressed : LightColors.accentPressed);

  static Color get accentTintBackground => isRetro
      ? (isDark
            ? RetroDarkColors.accentTintBackground
            : RetroLightColors.accentTintBackground)
      : (isDark
            ? DarkColors.accentTintBackground
            : LightColors.accentTintBackground);

  static Color get accentTagBackground => isRetro
      ? (isDark
            ? RetroDarkColors.accentTagBackground
            : RetroLightColors.accentTagBackground)
      : (isDark
            ? DarkColors.accentTagBackground
            : LightColors.accentTagBackground);

  // Task type colors
  static Color get fixedTask => isRetro
      ? (isDark ? RetroDarkColors.fixedTask : RetroLightColors.fixedTask)
      : (isDark ? DarkColors.fixedTask : LightColors.fixedTask);

  static Color get floatingTask => isRetro
      ? (isDark ? RetroDarkColors.floatingTask : RetroLightColors.floatingTask)
      : (isDark ? DarkColors.floatingTask : LightColors.floatingTask);

  static Color get adHocTask => isRetro
      ? (isDark ? RetroDarkColors.adHocTask : RetroLightColors.adHocTask)
      : (isDark ? DarkColors.adHocTask : LightColors.adHocTask);

  // Text hierarchy
  static Color get textPrimary => isRetro
      ? (isDark ? RetroDarkColors.textPrimary : RetroLightColors.textPrimary)
      : (isDark ? DarkColors.textPrimary : LightColors.textPrimary);

  static Color get textSecondary => isRetro
      ? (isDark
            ? RetroDarkColors.textSecondary
            : RetroLightColors.textSecondary)
      : (isDark ? DarkColors.textSecondary : LightColors.textSecondary);

  static Color get textMuted => isRetro
      ? (isDark ? RetroDarkColors.textMuted : RetroLightColors.textMuted)
      : (isDark ? DarkColors.textMuted : LightColors.textMuted);

  static Color get textPlaceholder => isRetro
      ? (isDark
            ? RetroDarkColors.textPlaceholder
            : RetroLightColors.textPlaceholder)
      : (isDark ? DarkColors.textPlaceholder : LightColors.textPlaceholder);

  // Semantic
  static Color get infoAccent => isRetro
      ? (isDark ? RetroDarkColors.infoAccent : RetroLightColors.infoAccent)
      : (isDark ? DarkColors.infoAccent : LightColors.infoAccent);

  static Color get successDone => isRetro
      ? (isDark ? RetroDarkColors.successDone : RetroLightColors.successDone)
      : (isDark ? DarkColors.successDone : LightColors.successDone);

  static Color get warningTag => isRetro
      ? (isDark ? RetroDarkColors.warningTag : RetroLightColors.warningTag)
      : (isDark ? DarkColors.warningTag : LightColors.warningTag);

  static Color get warningFloating => isRetro
      ? (isDark
            ? RetroDarkColors.warningFloating
            : RetroLightColors.warningFloating)
      : (isDark ? DarkColors.warningFloating : LightColors.warningFloating);

  static Color get errorAlert => isRetro
      ? (isDark ? RetroDarkColors.errorAlert : RetroLightColors.errorAlert)
      : (isDark ? DarkColors.errorAlert : LightColors.errorAlert);

  static Color get dangerOverdue => isRetro
      ? (isDark
            ? RetroDarkColors.dangerOverdue
            : RetroLightColors.dangerOverdue)
      : (isDark ? DarkColors.dangerOverdue : LightColors.dangerOverdue);

  // Convenience border & retro shadow
  static Color get borderColor => cardBorder;

  /// Bezel / ink color for retro borders and hard outlines
  static Color get inkColor => isRetro
      ? (isDark ? RetroDarkColors.ink : RetroLightColors.ink)
      : (isDark ? DarkColors.textPrimary : LightColors.textPrimary);

  /// Solid offset block shadow for retro keypresses and cards
  static Color get retroShadowColor => isRetro
      ? (isDark ? RetroDarkColors.shadow : RetroLightColors.shadow)
      : (isDark
            ? Colors.black.withValues(alpha: 0.16)
            : Colors.black.withValues(alpha: 0.08));
}
