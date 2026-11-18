import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/user_settings.dart';
import 'package:momentum/models/month_summary.dart';
import 'package:momentum/models/wallet_settings.dart';
import 'package:momentum/providers/review_providers.dart';
import 'package:momentum/providers/wallet_providers.dart';
import 'package:momentum/providers/theme_provider.dart';
import 'package:momentum/repositories/hive_init.dart';
import 'package:momentum/screens/main_layout.dart';
import 'package:momentum/screens/onboarding/onboarding_screen.dart';
import 'package:momentum/screens/wallet/wallet_screen.dart';
import 'package:momentum/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('navigation_onboarding_');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    await initHive();
  });

  setUp(() async {
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call.method);
      if (call.method == 'areNotificationsEnabled' ||
          call.method == 'requestNotificationsPermission')
        return false;
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Etc/UTC',
    );
    await NotificationService().init();
    await Hive.box('appSettings').put('themeMode', 'light');
    await Hive.box<UserSettings>(
      'userSettings',
    ).put('user', UserSettings(firstName: 'Alex', hasSeenCoachMarks: true));
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await Hive.box<MonthSummary>('monthSummaries').put(
      month,
      MonthSummary(
        id: month,
        openingBalance: 0,
        totalIncome: 0,
        totalExpense: 0,
        closingBalance: 0,
      ),
    );
    calls.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
    for (final name in [
      'plugins.flutter.io/path_provider',
      'dexterous.com/flutter/local_notifications',
      'flutter_timezone',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
    bool reduced = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localTimeProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 11, 16, 22)),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }

  Future<void> press(WidgetTester tester, String label) async {
    final button = find.textContaining(label).last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'tabs retain Wallet browse state, expose selection, and survive resume without plugins',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester, const MainLayout());
      Finder tab(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );
      expect(
        tester.getSemantics(tab('Today')).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      for (final label in ['Today', 'Wallet', 'Insights']) {
        expect(tester.getSize(tab(label)).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(tab(label)).width, greaterThanOrEqualTo(48));
      }
      await tester.tap(tab('Wallet'));
      await tester.pumpAndSettle();
      final walletState = tester.state(find.byType(WalletScreen));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainLayout)),
      );
      container.read(selectedMonthDateProvider.notifier).state = DateTime(
        2026,
        10,
      );
      await tester.pump();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(WalletScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(100);
      await tester.pump();
      final offset = scroll.position.pixels;
      await tester.tap(tab('Insights'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tab('Insights')).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(find.text('Routine & Focus'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(tab('Wallet'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(WalletScreen)), same(walletState));
      expect(container.read(selectedMonthIdProvider), '2026-10');
      expect(scroll.position.pixels, offset);
      expect(
        calls.where((c) => c == 'requestNotificationsPermission'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets('theme replacement retains the new foreground task callback', (
    tester,
  ) async {
    await mount(tester, const MainLayout());
    final previous = NotificationService.onForegroundAction;
    expect(previous, isNotNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainLayout)),
    );
      await tester.runAsync(() async {
        container.read(themeModeProvider.notifier).setThemeMode(AppThemeMode.retroDark);
        await Hive.box('appSettings').flush();
      });
    await tester.pumpAndSettle();
    expect(NotificationService.onForegroundAction, isNotNull);
    expect(NotificationService.onForegroundAction, isNot(same(previous)));
    NotificationService.onForegroundAction!();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(NotificationService.onForegroundAction, isNull);
  });

  testWidgets('reduced motion stops a running onboarding logo', (tester) async {
    await mount(tester, const OnboardingScreen(), reduced: false);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await mount(tester, const OnboardingScreen());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    final scale = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).first,
    );
    expect(scale.scale.value, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Android layout tolerates missing HomeWidget platform channels', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await mount(tester, const MainLayout());
      await tester.pumpAndSettle();
      expect(find.byType(MainLayout), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'onboarding fits 320px scale=$scale and retains inputs after failed save and denied permission',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await mount(tester, const OnboardingScreen(), scale: scale);
        expect(tester.takeException(), isNull);
        await press(tester, 'Get Started');
        await press(tester, 'Next');
        await press(tester, 'Next');
        await tester.enterText(find.byType(TextField), 'Taylor');
        await press(tester, 'Continue');
        await press(tester, 'Grant Access');
        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Permission Granted'), findsNothing);
        final requests = calls
            .where((c) => c == 'requestNotificationsPermission')
            .length;
        await press(tester, 'Continue');
        expect(find.textContaining('3 permission(s) skipped'), findsOneWidget);
        // Closing this dependency forces a real persistence failure before first-launch is committed.
        await tester.runAsync(
          () => Hive.box<WalletSettings>('walletSettings').close(),
        );
        await press(tester, 'Launch Momentum');
        expect(find.textContaining('Could not finish setup.'), findsOneWidget);
        expect(
          Hive.box<UserSettings>('userSettings').get('user')!.isFirstLaunch,
          isTrue,
        );
        expect(
          calls.where((c) => c == 'requestNotificationsPermission').length,
          requests,
        );
        expect(find.byType(OnboardingScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Taylor',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Hive.openBox<WalletSettings>('walletSettings'),
        );
      },
    );
  }
}
