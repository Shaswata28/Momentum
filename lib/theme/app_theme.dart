import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  /// Dark Theme — Apple Dark / Things 3 Slate Aesthetic
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: false,
      scaffoldBackgroundColor: DarkColors.appBackground,
      colorScheme: const ColorScheme.dark(
        primary: DarkColors.accentPrimary,
        surface: DarkColors.cardBackground,
      ),
      cardColor: DarkColors.cardBackground,
      cardTheme: CardThemeData(
        color: DarkColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: DarkColors.cardBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DarkColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: DarkColors.textPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DarkColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: DarkColors.subtleBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: DarkColors.cardHoverActive,
        contentTextStyle: const TextStyle(color: DarkColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DarkColors.dividerBorderHover,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
    );
  }

  /// Light Theme — Apple System Grouped / Things 3 Light Aesthetic
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: false,
      scaffoldBackgroundColor: LightColors.appBackground,
      colorScheme: const ColorScheme.light(
        primary: LightColors.accentPrimary,
        surface: LightColors.cardBackground,
      ),
      cardColor: LightColors.cardBackground,
      cardTheme: CardThemeData(
        color: LightColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: LightColors.cardBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LightColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: LightColors.textPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LightColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: LightColors.subtleBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LightColors.cardHoverActive,
        contentTextStyle: const TextStyle(color: LightColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: LightColors.dividerBorderHover,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme),
    );
  }
}
