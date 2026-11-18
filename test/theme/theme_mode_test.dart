import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/providers/theme_provider.dart';
import 'package:momentum/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Architecture & Dynamic Colors Test', () {
    tearDown(() {
      // Ensure we reset to dark mode (default)
      AppColors.isDark = true;
    });

    test('DarkColors tokens match expectations', () {
      AppColors.isDark = true;
      expect(AppColors.appBackground, const Color(0xFF0F1015));
      expect(AppColors.cardBackground, const Color(0xFF171821));
      expect(AppColors.textPrimary, const Color(0xFFF8FAFC));
      expect(AppColors.cardBorder, const Color(0x12FFFFFF));
    });

    test('LightColors tokens match Things 3 / Apple minimalist specification', () {
      AppColors.isDark = false;
      expect(AppColors.appBackground, const Color(0xFFF2F2F7));
      expect(AppColors.cardBackground, const Color(0xFFFFFFFF));
      expect(AppColors.textPrimary, const Color(0xFF0F172A));
      expect(AppColors.textSecondary, const Color(0xFF475569));
      expect(AppColors.cardBorder, const Color(0x0F000000));
      expect(AppColors.accentPrimary, const Color(0xFF2563EB));
    });

    test('Dynamic getters switch instantly when AppColors.isDark changes', () {
      AppColors.isDark = true;
      final darkBg = AppColors.appBackground;

      AppColors.isDark = false;
      final lightBg = AppColors.appBackground;

      expect(darkBg, isNot(equals(lightBg)));
      expect(darkBg, DarkColors.appBackground);
      expect(lightBg, LightColors.appBackground);
    });

    test('ThemeModeNotifier updates state and synchronizes AppColors', () {
      final notifier = ThemeModeNotifier();

      // Switch to Light
      notifier.setThemeMode(AppThemeMode.light);
      expect(notifier.state, AppThemeMode.light);
      expect(AppColors.isDark, isFalse);
      expect(AppColors.cardBackground, const Color(0xFFFFFFFF));

      // Switch to Dark
      notifier.setThemeMode(AppThemeMode.dark);
      expect(notifier.state, AppThemeMode.dark);
      expect(AppColors.isDark, isTrue);
      expect(AppColors.cardBackground, const Color(0xFF171821));

      // Switch to System & update brightness
      notifier.setThemeMode(AppThemeMode.system);
      expect(notifier.state, AppThemeMode.system);

      notifier.updateSystemBrightness(Brightness.light);
      expect(AppColors.isDark, isFalse);

      notifier.updateSystemBrightness(Brightness.dark);
      expect(AppColors.isDark, isTrue);
    });

    test('ThemeModeNotifier setRetro and setDark independent toggle logic', () {
      final notifier = ThemeModeNotifier();

      // Start in Dark
      notifier.setThemeMode(AppThemeMode.dark);
      expect(notifier.state, AppThemeMode.dark);

      // Toggle theme to Retro (keeps appearance Dark -> retroDark)
      notifier.setRetro(true);
      expect(notifier.state, AppThemeMode.retroDark);
      expect(AppColors.isRetro, isTrue);
      expect(AppColors.isDark, isTrue);

      // Toggle appearance to Light (keeps theme Retro -> retroLight)
      notifier.setDark(false);
      expect(notifier.state, AppThemeMode.retroLight);
      expect(AppColors.isRetro, isTrue);
      expect(AppColors.isDark, isFalse);

      // Toggle theme to Classic (keeps appearance Light -> light)
      notifier.setRetro(false);
      expect(notifier.state, AppThemeMode.light);
      expect(AppColors.isRetro, isFalse);
      expect(AppColors.isDark, isFalse);

      // Toggle appearance to Dark (keeps theme Classic -> dark)
      notifier.setDark(true);
      expect(notifier.state, AppThemeMode.dark);
      expect(AppColors.isRetro, isFalse);
      expect(AppColors.isDark, isTrue);
    });
  });
}
