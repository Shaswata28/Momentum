import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/providers/theme_provider.dart';
import 'package:momentum/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];
  late Directory directory;
  var failSave = false;
  Completer<void>? saveGate;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('momentum_widget_theme_');
    Hive.init(directory.path);
    await Hive.openBox('appSettings');
  });

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    failSave = false;
    saveGate = null;
    await Hive.box('appSettings').clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'saveWidgetData') {
            await saveGate?.future;
            if (failSave) throw PlatformException(code: 'unavailable');
          }
          return true;
        });
  });

  tearDown(() async {
    if (saveGate != null && !saveGate!.isCompleted) saveGate!.complete();
    await pumpEventQueue();
    debugDefaultTargetPlatformOverride = null;
    AppColors.isRetro = false;
    AppColors.isDark = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  List<String> savedModes() => calls
      .where((call) => call.method == 'saveWidgetData')
      .map((call) => (call.arguments as Map)['data'] as String)
      .toList();

  test('defaults to Retro Light and syncs it to the widget', () async {
    final notifier = ThemeModeNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    expect(notifier.state, AppThemeMode.retroLight);
    expect(AppColors.isRetro, isTrue);
    expect(AppColors.isDark, isFalse);
    expect(savedModes(), ['retroLight']);
  });

  test('restores the saved app theme to the widget on startup', () async {
    await Hive.box('appSettings').put('themeMode', 'retro_dark');
    final notifier = ThemeModeNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();

    expect(savedModes(), ['retroDark']);
    expect(calls.last.method, 'updateWidget');
    expect(calls.last.arguments['android'], 'DailyTrackerWidgetProvider');
  });

  test(
    'every app appearance refreshes the widget without changing task data',
    () async {
      final notifier = ThemeModeNotifier();
      addTearDown(notifier.dispose);
      await pumpEventQueue();
      calls.clear();

      for (final mode in AppThemeMode.values.skip(1)) {
        notifier.setThemeMode(mode);
      }
      notifier.setThemeMode(AppThemeMode.system);
      await pumpEventQueue();

      expect(savedModes(), [
        'light',
        'dark',
        'retroLight',
        'retroDark',
        'system',
      ]);
      expect(calls.map((call) => call.method), [
        for (var i = 0; i < 5; i++) ...['saveWidgetData', 'updateWidget'],
      ]);
      expect(
        calls
            .where((call) => call.method == 'saveWidgetData')
            .every((call) => call.arguments['id'] == 'theme_mode'),
        isTrue,
      );
    },
  );

  test(
    'rapid changes wait for earlier writes and leave the latest theme saved',
    () async {
      await Hive.box('appSettings').put('themeMode', 'system');
      saveGate = Completer<void>();
      final notifier = ThemeModeNotifier();
      addTearDown(notifier.dispose);
      notifier.setThemeMode(AppThemeMode.retroLight);
      notifier.setThemeMode(AppThemeMode.dark);
      await pumpEventQueue();
      expect(savedModes(), ['system']);

      saveGate!.complete();
      await pumpEventQueue();
      expect(savedModes(), ['system', 'retroLight', 'dark']);
      expect(calls.last.method, 'updateWidget');
    },
  );

  test('a plugin failure does not block later theme changes', () async {
    failSave = true;
    final notifier = ThemeModeNotifier();
    addTearDown(notifier.dispose);
    await pumpEventQueue();
    expect(calls.where((call) => call.method == 'updateWidget'), isEmpty);

    failSave = false;
    notifier.setThemeMode(AppThemeMode.retroDark);
    await pumpEventQueue();
    expect(savedModes().last, 'retroDark');
    expect(calls.last.method, 'updateWidget');
  });

  test(
    'system brightness updates preserve system mode for native resolution',
    () async {
      await Hive.box('appSettings').put('themeMode', 'system');
      final notifier = ThemeModeNotifier();
      addTearDown(notifier.dispose);
      notifier.updateSystemBrightness(Brightness.dark);
      notifier.updateSystemBrightness(Brightness.light);
      await pumpEventQueue();
      expect(savedModes(), everyElement('system'));
      expect(AppColors.isDark, isFalse);
    },
  );

  test('unsupported platforms do not call the Android widget plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final notifier = ThemeModeNotifier();
    addTearDown(notifier.dispose);
    notifier.setThemeMode(AppThemeMode.retroLight);
    await pumpEventQueue();
    expect(calls, isEmpty);
  });
}
