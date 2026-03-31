import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: false,
      scaffoldBackgroundColor: AppColors.appBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentPrimary,
        surface: AppColors.cardBackground,
      ),
      cardColor: AppColors.cardBackground,
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
    );
  }
}
