import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'theme/retro_theme.dart';
import 'screens/main_layout.dart';
import 'repositories/hive_init.dart';
import 'services/notification_service.dart';
import 'services/dnd_service.dart';
import 'services/focus_blocker_service.dart';
import 'package:home_widget/home_widget.dart';
import 'services/native_task_action_service.dart';
import 'services/month_rollover_service.dart';
import 'models/enums.dart';
import 'models/user_settings.dart';
import 'providers/theme_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;
  final host = uri.host;
  final taskId = uri.queryParameters['taskId'];
  if (taskId == null) return;

  if (host == 'done' || host == 'skip') {
    await initHive();
    await NativeTaskActionService.apply(
      taskId,
      host == 'done' ? TaskStatus.done : TaskStatus.skipped,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All five existing font families are bundled for first-launch offline use.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in [
      'dmsans',
      'jetbrainsmono',
      'pressstart2p',
      'pixelifysans',
      'vt323',
    ]) {
      final license = await rootBundle.loadString(
        'assets/fonts/$family-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });

  await initHive();
  NativeTaskActionService.startListening();
  await MonthRolloverService().checkAndRollover();

  final ns = NotificationService();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await ns.init();
      await ns.scheduleEODPrompt();
    } on PlatformException catch (error) {
      debugPrint('Notifications unavailable at startup: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Notifications unavailable on this platform: $error');
    }
  }

  final dnd = DndService();
  await dnd.init();
  dnd.startMonitoring();

  final focusBlocker = FocusBlockerService();
  await focusBlocker.init();

  await HomeWidget.registerInteractivityCallback(backgroundCallback);
  runApp(const ProviderScope(child: DailyTrackerApp()));
}

class DailyTrackerApp extends ConsumerWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeModeProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    ref.read(themeModeProvider.notifier).updateSystemBrightness(brightness);

    final settingsBox = Hive.box<UserSettings>('userSettings');
    final settings = settingsBox.get('user');
    final isFirstLaunch = settings == null || settings.isFirstLaunch;

    final ThemeData lightTheme;
    final ThemeData darkTheme;
    final ThemeMode themeMode;

    switch (appThemeMode) {
      case AppThemeMode.system:
        lightTheme = AppTheme.lightTheme;
        darkTheme = AppTheme.darkTheme;
        themeMode = ThemeMode.system;
        break;
      case AppThemeMode.light:
        lightTheme = AppTheme.lightTheme;
        darkTheme = AppTheme.darkTheme;
        themeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        lightTheme = AppTheme.lightTheme;
        darkTheme = AppTheme.darkTheme;
        themeMode = ThemeMode.dark;
        break;
      case AppThemeMode.retroLight:
        lightTheme = RetroTheme.lightTheme;
        darkTheme = RetroTheme.lightTheme;
        themeMode = ThemeMode.light;
        break;
      case AppThemeMode.retroDark:
        lightTheme = RetroTheme.darkTheme;
        darkTheme = RetroTheme.darkTheme;
        themeMode = ThemeMode.dark;
        break;
    }

    // In retro mode: clamp text scaling to 1.0 — pixel fonts (Press Start 2P,
    // Pixelify Sans, VT323) are monospace bitmap-style fonts that break badly
    // at large system font scales. Classic mode allows up to 1.3× for
    // accessibility while still preventing extreme overflow.
    final double maxRetroScale = appThemeMode.isRetro ? 1.0 : 1.3;

    return MaterialApp(
      title: 'Momentum',
      navigatorKey: FocusBlockerService.navigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      // builder runs inside MaterialApp after MediaQuery is established,
      // so withClampedTextScaling can read and override the system text scale.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxRetroScale,
        child: child!,
      ),
      home: isFirstLaunch ? const OnboardingScreen() : const MainLayout(),
    );
  }
}
