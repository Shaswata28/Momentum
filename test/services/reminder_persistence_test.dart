import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/user_settings.dart';
import 'package:momentum/models/daily_task_instance.dart';
import 'package:momentum/models/enums.dart';
import 'package:momentum/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  late Directory directory;
  final calls = <MethodCall>[];
  var permission = true;
  var failSchedule = false;
  var zone = 'Asia/Dhaka';

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('momentum_reminder_');
    Hive.init(directory.path);
    Hive.registerAdapter(UserSettingsAdapter());
    await Hive.openBox('appSettings');
    await Hive.openBox<UserSettings>('userSettings');
  });

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    permission = true;
    failSchedule = false;
    zone = 'Asia/Dhaka';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (_) async => zone);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'areNotificationsEnabled') return permission;
          if (call.method == 'canScheduleExactNotifications') return false;
          if (call.method == 'zonedSchedule' && failSchedule)
            throw PlatformException(code: 'denied');
          return true;
        });
    await Hive.box('appSettings').clear();
    await NotificationService().init();
    calls.clear();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'old preferences default to 22:30 and invalid values fall back safely',
    () async {
      expect(
        NotificationService().savedEODReminder,
        const TimeOfDay(hour: 22, minute: 30),
      );
      await Hive.box(
        'appSettings',
      ).put(NotificationService.eodReminderKey, 9999);
      expect(
        NotificationService().savedEODReminder,
        const TimeOfDay(hour: 22, minute: 30),
      );
    },
  );

  test(
    'saved reminder survives unrelated profile writes and Hive restart; startup uses it',
    () async {
      expect(
        await NotificationService().saveEODReminder(
          const TimeOfDay(hour: 19, minute: 12),
        ),
        isTrue,
      );
      await Hive.box<UserSettings>('userSettings').put(
        'user',
        UserSettings(firstName: 'Changed', hasSeenCoachMarks: true),
      );
      await Hive.box('appSettings').put('themeMode', 'retroDark');
      await Hive.box('appSettings').close();
      await Hive.openBox('appSettings');
      calls.clear();
      expect(
        NotificationService().savedEODReminder,
        const TimeOfDay(hour: 19, minute: 12),
      );
      expect(await NotificationService().scheduleEODPrompt(), isTrue);
      final schedule =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      expect(schedule['scheduledDateTime'], contains('T19:12:00'));
      expect(schedule['timeZoneName'], 'Asia/Dhaka');
      expect(schedule['matchDateTimeComponents'], isNotNull);
    },
  );

  test(
    'denied notifications preserve preference but do not claim scheduled',
    () async {
      permission = false;
      expect(
        await NotificationService().saveEODReminder(
          const TimeOfDay(hour: 7, minute: 45),
        ),
        isFalse,
      );
      expect(
        NotificationService().savedEODReminder,
        const TimeOfDay(hour: 7, minute: 45),
      );
      expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
      expect(calls.where((c) => c.method == 'cancel'), isNotEmpty);
    },
  );

  test(
    'scheduling failure is honest and retry uses the saved preference',
    () async {
      failSchedule = true;
      expect(
        await NotificationService().saveEODReminder(
          const TimeOfDay(hour: 20, minute: 5),
        ),
        isFalse,
      );
      expect(
        NotificationService().savedEODReminder,
        const TimeOfDay(hour: 20, minute: 5),
      );
      failSchedule = false;
      expect(await NotificationService().scheduleEODPrompt(), isTrue);
    },
  );

  test(
    'timezone changes reschedule at the same local wall-clock time',
    () async {
      await NotificationService().saveEODReminder(
        const TimeOfDay(hour: 22, minute: 30),
      );
      zone = 'America/New_York';
      calls.clear();
      await NotificationService().scheduleEODPrompt();
      final schedule =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      expect(schedule['scheduledDateTime'], contains('T22:30:00'));
      expect(schedule['timeZoneName'], zone);
    },
  );

  test(
    'future timed adhoc notifications use destination date, terminal tasks are ignored',
    () async {
      final future = DateTime.now().add(const Duration(days: 5));
      DailyTaskInstance task(TaskStatus status) => DailyTaskInstance(
        id: 'future',
        routineTaskId: 'routine',
        date: future,
        title: 'Later',
        taskType: TaskType.adhoc,
        scheduledTime: const TimeOfDay(hour: 15, minute: 0),
        durationMinutes: 20,
        status: status,
        isBufferBlock: false,
        enableDND: false,
      );
      await NotificationService().scheduleTaskNotifications(
        task(TaskStatus.pending),
      );
      final schedules = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(schedules, hasLength(2));
      for (final schedule in schedules) {
        final date = DateTime.parse(
          (schedule.arguments as Map)['scheduledDateTime'] as String,
        );
        expect(date.year, future.year);
        expect(date.month, future.month);
        expect(date.day, future.day);
      }
      calls.clear();
      for (final status in [
        TaskStatus.done,
        TaskStatus.skipped,
        TaskStatus.rescheduled,
      ]) {
        await NotificationService().scheduleTaskNotifications(task(status));
      }
      expect(calls, isEmpty);
    },
  );
}
