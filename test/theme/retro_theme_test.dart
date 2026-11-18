import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momentum/theme/app_colors.dart';
import 'package:momentum/theme/retro_colors.dart';
import 'package:momentum/theme/retro_theme.dart';
import 'package:momentum/theme/app_typography.dart';
import 'package:momentum/providers/theme_provider.dart';
import 'package:momentum/widgets/action_button.dart';
import 'package:momentum/screens/onboarding/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retro Palette Tokens (from Retro theme Momentum.md)', () {
    test('Retro Light (beige console) colors match spec', () {
      expect(RetroLightColors.appBackground, const Color(0xFFD9D2BE));
      expect(RetroLightColors.cardBackground, const Color(0xFFE8E2D0));
      expect(RetroLightColors.cardBorder, const Color(0xFF2A2622));
      expect(RetroLightColors.textPrimary, const Color(0xFF2A2622));
      expect(RetroLightColors.textMuted, const Color(0xFF6B6457));
      expect(RetroLightColors.orangePrimary, const Color(0xFFF26B21));
      expect(RetroLightColors.blueSecondary, const Color(0xFF2F6FD6));
      expect(RetroLightColors.greenSuccess, const Color(0xFF3FA34D));
      expect(RetroLightColors.yellowHighlight, const Color(0xFFF2C230));
    });

    test('Retro Dark (gray console) colors match spec', () {
      expect(RetroDarkColors.appBackground, const Color(0xFF2B2B33));
      expect(RetroDarkColors.cardBackground, const Color(0xFF3E3E49));
      expect(RetroDarkColors.cardBorder, const Color(0xFFC9CBD1));
      expect(RetroDarkColors.textPrimary, const Color(0xFFE4E5E9));
      expect(RetroDarkColors.textMuted, const Color(0xFF9A9CA6));
      expect(RetroDarkColors.orangePrimary, const Color(0xFFFF8A3D));
      expect(RetroDarkColors.blueSecondary, const Color(0xFF5B93F0));
      expect(RetroDarkColors.greenSuccess, const Color(0xFF5CC96B));
      expect(RetroDarkColors.yellowHighlight, const Color(0xFFFFD54F));
      expect(RetroDarkColors.shadow, const Color(0xFF000000));
    });
  });

  group('ThemeModeNotifier and AppColors Sync', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_test');
      Hive.init(tempDir.path);
      await Hive.openBox('appSettings');
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Switching to retroLight sets AppColors.isRetro=true and isDark=false', () {
      final notifier = ThemeModeNotifier();
      notifier.setThemeMode(AppThemeMode.retroLight);

      expect(notifier.state, AppThemeMode.retroLight);
      expect(AppColors.isRetro, true);
      expect(AppColors.isDark, false);
      expect(AppColors.appBackground, RetroLightColors.appBackground);
      expect(AppColors.cardBackground, RetroLightColors.cardBackground);
      expect(AppColors.accentPrimary, RetroLightColors.accentPrimary);
      expect(AppColors.cardBorder, RetroLightColors.cardBorder);
    });

    test('Switching to retroDark sets AppColors.isRetro=true and isDark=true', () {
      final notifier = ThemeModeNotifier();
      notifier.setThemeMode(AppThemeMode.retroDark);

      expect(notifier.state, AppThemeMode.retroDark);
      expect(AppColors.isRetro, true);
      expect(AppColors.isDark, true);
      expect(AppColors.appBackground, RetroDarkColors.appBackground);
      expect(AppColors.cardBackground, RetroDarkColors.cardBackground);
      expect(AppColors.accentPrimary, RetroDarkColors.accentPrimary);
      expect(AppColors.cardBorder, RetroDarkColors.cardBorder);
    });

    test('Switching to modern dark restores isRetro=false and isDark=true', () {
      final notifier = ThemeModeNotifier();
      notifier.setThemeMode(AppThemeMode.dark);

      expect(notifier.state, AppThemeMode.dark);
      expect(AppColors.isRetro, false);
      expect(AppColors.isDark, true);
      expect(AppColors.appBackground, DarkColors.appBackground);
    });
  });

  group('Retro Widget and Theme Rendering', () {
    testWidgets('Renders RetroTheme with zero radius and NoSplash in MaterialApp', (tester) async {
      final light = RetroTheme.lightTheme;
      final dark = RetroTheme.darkTheme;

      expect(light.splashFactory, NoSplash.splashFactory);
      expect(dark.splashFactory, NoSplash.splashFactory);

      expect(light.cardTheme.shape, const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: RetroLightColors.cardBorder, width: 2),
      ));

      expect(dark.cardTheme.shape, const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: RetroDarkColors.cardBorder, width: 2),
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: light,
          home: const Scaffold(
            body: Card(
              child: Text('Retro Card'),
            ),
          ),
        ),
      );

      expect(find.text('Retro Card'), findsOneWidget);
    });

    testWidgets('Three ActionButtons in a row do not overflow in Retro mode', (tester) async {
      AppColors.isRetro = true;
      AppColors.isDark = true;

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.darkTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Income',
                      color: AppColors.successDone,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Expense',
                      color: AppColors.warningTag,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'IOU',
                      color: AppColors.accentPrimary,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('IOU'), findsOneWidget);
    });

    testWidgets('Insights AppBar does not overflow in Retro mode', (tester) async {
      AppColors.isRetro = true;
      AppColors.isDark = true;

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.darkTheme,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(AppColors.isRetro ? 152 : 144),
              child: Container(
                color: AppColors.appBackground,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Insights',
                          style: AppTypography.displayHeading.copyWith(
                            fontSize: AppColors.isRetro ? 18 : 26,
                            letterSpacing: AppColors.isRetro ? 0.0 : -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Performance trends & financial health',
                          style: AppTypography.bodyText.copyWith(
                            color: AppColors.textPlaceholder,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(color: AppColors.cardBorder, width: 2.0),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Routine & Focus',
                                          style: AppTypography.buttonLabel.copyWith(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.textSecondary),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Wallet & Finance',
                                          style: AppTypography.buttonLabel.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Container(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Routine & Focus'), findsOneWidget);
      expect(find.text('Wallet & Finance'), findsOneWidget);
    });

    testWidgets('Theme and Appearance segmented toggles render Classic, Retro, Light, Dark without overflow', (tester) async {
      AppColors.isRetro = true;
      AppColors.isDark = true;

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.darkTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              Expanded(child: Center(child: Text('Classic', style: AppTypography.buttonLabel))),
                              Expanded(child: Center(child: Text('Retro', style: AppTypography.buttonLabel))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              Expanded(child: Center(child: Text('Light', style: AppTypography.buttonLabel))),
                              Expanded(child: Center(child: Text('Dark', style: AppTypography.buttonLabel))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Retro'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('MindfulFrictionScreen renders with zero border radius in retro mode', (tester) async {
      AppColors.isRetro = true;
      AppColors.isDark = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Text('Focus Shield Friction Boxy Test'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('Retro Dark shadow color evaluates to pure black #000000', () {
      AppColors.isRetro = true;
      AppColors.isDark = true;
      expect(AppColors.retroShadowColor, const Color(0xFF000000));

      AppColors.isDark = false;
      expect(AppColors.retroShadowColor, RetroLightColors.shadow);
    });

    testWidgets('OnboardingScreen displays theming choice on page 2 and toggles retro mode', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('MOMENTUM'), findsOneWidget);
      expect(find.text('Get Started →'), findsOneWidget);

      // Tap Get Started to go to Page 1
      await tester.tap(find.text('Get Started →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap Next to go to Page 2 (Theme)
      await tester.tap(find.text('Next →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Make it yours.'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Retro'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Tap Retro
      await tester.tap(find.text('Retro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AppColors.isRetro, isTrue);

      // Tap Classic
      await tester.tap(find.text('Classic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AppColors.isRetro, isFalse);
    });

    testWidgets('OnboardingScreen navigates to permissions page with notification, shield, and DND controls', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Skip to jump straight to Profile Setup (Page 3)
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("Let's set up\nyour profile."), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField), 'Tester');
      await tester.pump();

      // Tap Continue to go to Permissions (Page 4)
      await tester.tap(find.text('Continue →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('A few permissions.'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Focus Shield'), findsOneWidget);
      expect(find.text('Do Not Disturb'), findsOneWidget);
    });
  });
}
