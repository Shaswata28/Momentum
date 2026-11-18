import 'package:flutter/material.dart';
import 'retro_colors.dart';
import 'retro_typography.dart';

class RetroTheme {
  /// Retro Light Theme — Beige Console Aesthetic (NES / Famicom / GameBoy)
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: false,
      fontFamily: 'Pixelify Sans',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: RetroLightColors.appBackground,
      colorScheme: const ColorScheme.light(
        primary: RetroLightColors.accentPrimary,
        secondary: RetroLightColors.blueSecondary,
        surface: RetroLightColors.cardBackground,
        onPrimary: RetroLightColors.ink,
        onSurface: RetroLightColors.textPrimary,
      ),
      cardColor: RetroLightColors.cardBackground,
      cardTheme: const CardThemeData(
        color: RetroLightColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: RetroLightColors.cardBorder, width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RetroLightColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: RetroLightColors.textPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: RetroLightColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: RetroLightColors.cardBorder, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RetroLightColors.cardBackground,
        contentTextStyle: RetroTypography.bodyText.copyWith(
          color: RetroLightColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: RetroLightColors.cardBorder, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: RetroLightColors.dividerBorderHover,
        thickness: 2,
        space: 2,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: RetroLightColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: RetroLightColors.cardBorder, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: RetroLightColors.cardBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: RetroLightColors.accentPrimary,
            width: 2,
          ),
        ),
      ),
    );
  }

  /// Retro Dark Theme — Gray Console Aesthetic (SNES / Industrial Console)
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: false,
      fontFamily: 'Pixelify Sans',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: RetroDarkColors.appBackground,
      colorScheme: const ColorScheme.dark(
        primary: RetroDarkColors.accentPrimary,
        secondary: RetroDarkColors.blueSecondary,
        surface: RetroDarkColors.cardBackground,
        onPrimary: Colors.black,
        onSurface: RetroDarkColors.textPrimary,
      ),
      cardColor: RetroDarkColors.cardBackground,
      cardTheme: const CardThemeData(
        color: RetroDarkColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: RetroDarkColors.cardBorder, width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RetroDarkColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: RetroDarkColors.textPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: RetroDarkColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: RetroDarkColors.cardBorder, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RetroDarkColors.cardBackground,
        contentTextStyle: RetroTypography.bodyText.copyWith(
          color: RetroDarkColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: RetroDarkColors.cardBorder, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: RetroDarkColors.dividerBorderHover,
        thickness: 2,
        space: 2,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: RetroDarkColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: RetroDarkColors.cardBorder, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: RetroDarkColors.cardBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: RetroDarkColors.accentPrimary,
            width: 2,
          ),
        ),
      ),
    );
  }
}
