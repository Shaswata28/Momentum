import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/user_settings.dart';
import 'package:momentum/providers/theme_provider.dart';
import 'package:momentum/screens/profile/profile_screen.dart';
import 'package:momentum/screens/profile/help_screen.dart';
import 'package:momentum/theme/app_colors.dart';
import 'package:momentum/theme/app_theme.dart';
import 'package:momentum/theme/retro_theme.dart';
import 'package:momentum/widgets/action_button.dart';
import 'package:momentum/widgets/health_score_ring.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('momentum_theme_');
    Hive.init(directory.path);
    Hive.registerAdapter(UserSettingsAdapter());
    await Hive.openBox('appSettings');
    await Hive.openBox<UserSettings>('userSettings');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final mode in AppThemeMode.values) {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('shared controls $mode width $width text $scale', (
          tester,
        ) async {
          AppColors.isRetro = mode.isRetro;
          AppColors.isDark = mode.isDark;
          final theme = mode.isRetro
              ? (mode.isDark ? RetroTheme.darkTheme : RetroTheme.lightTheme)
              : (mode.isDark ? AppTheme.darkTheme : AppTheme.lightTheme);
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ActionButton(
                                label: 'Complete task',
                                icon: Icons.done,
                                onTap: () => taps++,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: ActionButton(
                                label: 'Save changes',
                                onTap: null,
                              ),
                            ),
                          ],
                        ),
                        const HealthScoreRing(score: 85, grade: 'B'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final buttons = find.byType(ActionButton);
          for (final button in buttons.evaluate()) {
            expect(
              tester.getSize(find.byWidget(button.widget)).height,
              greaterThanOrEqualTo(48),
            );
          }
          await tester.tap(find.text('Complete task'));
          await tester.tap(find.text('Save changes'));
          expect(taps, 1);
          expect(find.text('85.0'), findsOneWidget);
        });
      }
    }
  }

  testWidgets(
    'button exposes enabled action and disabled state to accessibility',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ActionButton(label: 'Continue', onTap: () {}),
                const ActionButton(label: 'Unavailable', onTap: null),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Continue')),
        matchesSemantics(
          label: 'Continue',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Unavailable')),
        matchesSemantics(
          label: 'Unavailable',
          isButton: true,
          hasEnabledState: true,
        ),
      );
      semantics.dispose();
    },
  );

  for (final mode in AppThemeMode.values.where(
    (mode) => mode != AppThemeMode.system,
  )) {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('profile $mode width $width text $scale', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.runAsync(
            () => Hive.box('appSettings').put('themeMode', mode.name),
          );
          final theme = mode.isRetro
              ? (mode.isDark ? RetroTheme.darkTheme : RetroTheme.lightTheme)
              : (mode.isDark ? AppTheme.darkTheme : AppTheme.lightTheme);
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              child: MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const ProfileScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -2400),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('System appearance follows $brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final notifier = ThemeModeNotifier();
      notifier.updateSystemBrightness(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (context) => Text(Theme.of(context).brightness.name),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(brightness.name), findsOneWidget);
      notifier.dispose();
    });
  }

  test('secondary and helper text contrast on surfaces is at least 4.5:1', () {
    for (final retro in [false, true]) {
      for (final dark in [false, true]) {
        AppColors.isRetro = retro;
        AppColors.isDark = dark;
        for (final foreground in [
          AppColors.textSecondary,
          AppColors.textMuted,
          AppColors.textPlaceholder,
        ]) {
          for (final background in [
            AppColors.appBackground,
            AppColors.cardBackground,
          ]) {
            final a = foreground.computeLuminance();
            final b = background.computeLuminance();
            final ratio = a > b
                ? (a + 0.05) / (b + 0.05)
                : (b + 0.05) / (a + 0.05);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: 'retro=$retro dark=$dark',
            );
          }
        }
      }
    }
  });

  testWidgets(
    'profile and help reflow at narrow large text, profile sheet scrolls above keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => Hive.box('appSettings').put('themeMode', 'retroLight'),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: RetroTheme.lightTheme,
            home: const MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 280),
              ),
              child: ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tap to customize name & avatar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: HelpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test('all bundled font files and licenses are available offline', () async {
    for (final family in [
      'DMSans',
      'JetBrainsMono',
      'PressStart2P',
      'PixelifySans',
      'VT323',
    ]) {
      final bytes = await rootBundle.load('assets/fonts/$family.ttf');
      expect(bytes.lengthInBytes, greaterThan(1000));
      final license = await rootBundle.loadString(
        'assets/fonts/${family.toLowerCase()}-OFL.txt',
      );
      expect(license, contains('SIL OPEN FONT LICENSE'));
    }
  });
}
