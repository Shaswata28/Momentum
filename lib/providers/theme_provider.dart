import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';
import '../services/widget_service.dart';
import '../services/focus_blocker_service.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  retroLight,
  retroDark;

  bool get isRetro => this == AppThemeMode.retroLight || this == AppThemeMode.retroDark;
  bool get isDark => this == AppThemeMode.dark || this == AppThemeMode.retroDark;
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  static const _boxName = 'appSettings';
  static const _key = 'themeMode';

  ThemeModeNotifier() : super(_loadInitialMode()) {
    _syncAppColors(state);
    WidgetService.syncTheme(state.name);
    FocusBlockerService().syncTheme(
      themeMode: state.name,
      isRetro: AppColors.isRetro,
      isDark: AppColors.isDark,
    );
  }

  static AppThemeMode _loadInitialMode() {
    try {
      final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;
      final saved = box?.get(_key) as String?;
      switch (saved) {
        case 'light':
          return AppThemeMode.light;
        case 'dark':
          return AppThemeMode.dark;
        case 'retroLight':
        case 'retro_light':
          return AppThemeMode.retroLight;
        case 'retroDark':
        case 'retro_dark':
          return AppThemeMode.retroDark;
        case 'system':
          return AppThemeMode.system;
        default:
          return AppThemeMode.retroLight;
      }
    } catch (_) {
      return AppThemeMode.retroLight;
    }
  }

  void setThemeMode(AppThemeMode mode) {
    if (state == mode) return;
    // IMPORTANT: sync AppColors *before* updating state so that every Riverpod
    // listener that fires during `state = mode` already sees the correct
    // AppColors.isRetro / AppColors.isDark values on its first build pass.
    _syncAppColors(mode);
    state = mode;
    WidgetService.syncTheme(mode.name);
    FocusBlockerService().syncTheme(
      themeMode: mode.name,
      isRetro: mode.isRetro,
      isDark: mode.isDark,
    );
    try {
      final box = Hive.box(_boxName);
      final val = switch (mode) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
        AppThemeMode.retroLight => 'retroLight',
        AppThemeMode.retroDark => 'retroDark',
        AppThemeMode.system => 'system',
      };
      box.put(_key, val);
    } catch (_) {}
  }

  void setRetro(bool isRetro) {
    final isCurrentlyDark = (state == AppThemeMode.system) ? AppColors.isDark : state.isDark;
    if (isRetro) {
      setThemeMode(isCurrentlyDark ? AppThemeMode.retroDark : AppThemeMode.retroLight);
    } else {
      setThemeMode(isCurrentlyDark ? AppThemeMode.dark : AppThemeMode.light);
    }
  }

  void setDark(bool isDark) {
    final isCurrentlyRetro = state.isRetro;
    if (isCurrentlyRetro) {
      setThemeMode(isDark ? AppThemeMode.retroDark : AppThemeMode.retroLight);
    } else {
      setThemeMode(isDark ? AppThemeMode.dark : AppThemeMode.light);
    }
  }

  void updateSystemBrightness(Brightness brightness) {
    if (state == AppThemeMode.system) {
      final isDark = (brightness == Brightness.dark);
      if (AppColors.isDark != isDark || AppColors.isRetro != false) {
        AppColors.isRetro = false;
        AppColors.isDark = isDark;
        WidgetService.syncTheme(state.name);
        FocusBlockerService().syncTheme(
          themeMode: state.name,
          isRetro: false,
          isDark: isDark,
        );
      }
    }
  }

  void _syncAppColors(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        AppColors.isRetro = false;
        AppColors.isDark = false;
        break;
      case AppThemeMode.dark:
        AppColors.isRetro = false;
        AppColors.isDark = true;
        break;
      case AppThemeMode.retroLight:
        AppColors.isRetro = true;
        AppColors.isDark = false;
        break;
      case AppThemeMode.retroDark:
        AppColors.isRetro = true;
        AppColors.isDark = true;
        break;
      case AppThemeMode.system:
        AppColors.isRetro = false;
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        AppColors.isDark = (brightness == Brightness.dark);
        break;
    }
  }
}
