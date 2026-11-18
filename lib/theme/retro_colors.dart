import 'package:flutter/material.dart';

/// Retro Light Palette — Beige Console aesthetic (GameBoy / NES / Famicom inspired)
abstract final class RetroLightColors {
  // Console Bezel & Shell
  static const Color appBackground = Color(0xFFD9D2BE);
  static const Color cardBackground = Color(0xFFE8E2D0);
  static const Color cardHoverActive = Color(0xFFDDD6C2);
  static const Color elevatedSurface = Color(0xFFE8E2D0);
  static const Color inputBackground = Color(0xFFECE7D8);
  static const Color modalBackground = Color(0xFFE8E2D0);
  static const Color dividerBorderHover = Color(0xFF2A2622);
  static const Color subtleBorder = Color(0xFF2A2622);
  static const Color cardBorder = Color(0xFF2A2622);
  static const Color ink = Color(0xFF2A2622);

  // Controller Accents
  static const Color orangePrimary = Color(
    0xFFF26B21,
  ); // Primary CTA, Close Day, progress
  static const Color blueSecondary = Color(
    0xFF2F6FD6,
  ); // Info, selected states, Focus Shield
  static const Color greenSuccess = Color(
    0xFF3FA34D,
  ); // Income, done tasks, under-budget
  static const Color yellowHighlight = Color(
    0xFFF2C230,
  ); // Warnings, highlights, near-budget
  static const Color redExpense = Color(
    0xFFD32F2F,
  ); // Expenses, overdue, over-budget

  static const Color accentPrimary = orangePrimary;
  static const Color accentPressed = Color(0xFFD95510);
  static const Color accentTintBackground = Color(0x33F26B21);
  static const Color accentTagBackground = Color(0x40F26B21);

  static const Color fixedTask = blueSecondary;
  static const Color floatingTask = orangePrimary;
  static const Color adHocTask = yellowHighlight;

  static const Color textPrimary = Color(0xFF2A2622);
  static const Color textSecondary = Color(0xFF4A443B);
  static const Color textMuted = Color(0xFF6B6457);
  static const Color textPlaceholder = Color(0xFF8A8274);

  static const Color infoAccent = blueSecondary;
  static const Color successDone = greenSuccess;
  static const Color warningTag = yellowHighlight;
  static const Color warningFloating = yellowHighlight;
  static const Color errorAlert = redExpense;
  static const Color dangerOverdue = redExpense;
  static const Color shadow = Color(0xFF2A2622);
}

/// Retro Dark Palette — Gray Console aesthetic (SNES / Game Boy Pocket / Industrial console)
abstract final class RetroDarkColors {
  // Console Bezel & Shell
  static const Color appBackground = Color(0xFF141418);
  static const Color cardBackground = Color(0xFF1E1E26);
  static const Color cardHoverActive = Color(0xFF272732);
  static const Color elevatedSurface = Color(0xFF232330);
  static const Color inputBackground = Color(0xFF18181F);
  static const Color modalBackground = Color(0xFF1E1E26);
  static const Color dividerBorderHover = Color(0xFF2A2A36);
  static const Color subtleBorder = Color(0xFF30303E);
  static const Color cardBorder = Color(0xFF4A4A62);
  static const Color ink = Color(0xFF606078);

  // Controller Accents
  static const Color orangePrimary = Color(
    0xFFE8782A,
  ); // Primary CTA, Close Day, progress
  static const Color blueSecondary = Color(
    0xFF4A78CC,
  ); // Info, selected states, Focus Shield
  static const Color greenSuccess = Color(
    0xFF3DAB52,
  ); // Income, done tasks, under-budget
  static const Color yellowHighlight = Color(
    0xFFD4A820,
  ); // Warnings, highlights, near-budget
  static const Color redExpense = Color(
    0xFFC43A3A,
  ); // Expenses, overdue, over-budget

  static const Color accentPrimary = orangePrimary;
  static const Color accentPressed = Color(0xFFD1651B);
  static const Color accentTintBackground = Color(0x33E8782A);
  static const Color accentTagBackground = Color(0x40E8782A);

  static const Color fixedTask = blueSecondary;
  static const Color floatingTask = orangePrimary;
  static const Color adHocTask = yellowHighlight;

  static const Color textPrimary = Color(0xFFD8D8E8);
  static const Color textSecondary = Color(0xFF9494AA);
  static const Color textMuted = Color(0xFF60607A);
  static const Color textPlaceholder = Color(0xFF48485E);

  static const Color infoAccent = blueSecondary;
  static const Color successDone = greenSuccess;
  static const Color warningTag = yellowHighlight;
  static const Color warningFloating = yellowHighlight;
  static const Color errorAlert = redExpense;
  static const Color dangerOverdue = redExpense;
  static const Color shadow = Color(0xFF3A3A54);
}
