import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _boxName = 'appSettings';
  static const _key = 'themeMode';

  ThemeModeNotifier() : super(_loadInitialMode()) {
    _syncAppColors(state);
  }

  static ThemeMode _loadInitialMode() {
    try {
      final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
      final saved = box?.get(_key) as String?;
      switch (saved) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
        default:
          return ThemeMode.system;
      }
    } catch (_) {
      return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (state == mode) return;
    state = mode;
    _syncAppColors(mode);
    try {
      final box = Hive.box(_boxName);
      final val = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      box.put(_key, val);
    } catch (_) {}
  }

  void updateSystemBrightness(Brightness brightness) {
    if (state == ThemeMode.system) {
      final isDark = (brightness == Brightness.dark);
      if (AppColors.isDark != isDark) {
        AppColors.isDark = isDark;
      }
    }
  }

  void _syncAppColors(ThemeMode mode) {
    if (mode == ThemeMode.light) {
      AppColors.isDark = false;
    } else if (mode == ThemeMode.dark) {
      AppColors.isDark = true;
    } else {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      AppColors.isDark = (brightness == Brightness.dark);
    }
  }
}

