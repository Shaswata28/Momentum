import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/main.dart' as app;
import 'package:momentum/models/daily_task_instance.dart';
import 'package:momentum/models/enums.dart';
import 'package:momentum/repositories/hive_init.dart';
import 'package:momentum/services/dnd_service.dart';
import 'package:momentum/services/native_task_action_service.dart';
import 'package:momentum/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final filters = <int>[];
  final shield = <bool>[];
  const channels = [
    'plugins.flutter.io/path_provider',
    'flutter_dnd',
    'app.momentum.tracker/focus_blocker',
    'dexterous.com/flutter/local_notifications',
    'flutter_timezone',
    'home_widget',
  ];

  Future<void> seed({TaskStatus status = TaskStatus.pending}) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 1));
    final task = DailyTaskInstance(
      id: 'native-task',
      date: now,
      title: 'Focus from a native action',
      taskType: TaskType.fixed,
      scheduledTime: TimeOfDay(hour: start.hour, minute: start.minute),
      durationMinutes: 120,
      status: status,
      rescheduledToDate: status == TaskStatus.rescheduled
          ? now.add(const Duration(days: 1))
          : null,
      isBufferBlock: false,
      enableDND: true,
    );
    await Hive.box<DailyTaskInstance>('dailyTaskInstances').put(task.id, task);
    await DndService().updateTasks([task]);
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'momentum-native-actions',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_dnd'), (
      call,
    ) async {
      if (call.method == 'isNotificationPolicyAccessGranted') return true;
      if (call.method == 'getCurrentInterruptionFilter') return 2;
      if (call.method == 'setInterruptionFilter')
        filters.add(call.arguments as int);
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.momentum.tracker/focus_blocker'),
      (call) async {
        if (call.method == 'setFocusState')
          shield.add((call.arguments as Map)['isActive'] as bool);
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Etc/UTC',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (_) async => true,
    );
    await initHive();
    await NotificationService().init();
  });

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await Hive.box<DailyTaskInstance>('dailyTaskInstances').clear();
    await Hive.box('focusShieldSettings').put('enabled', true);
    await Hive.box(
      'focusShieldSettings',
    ).put('blockedPackages', ['com.example.distraction']);
    filters.clear();
    shield.clear();
  });

  tearDown(() async {
    NativeTaskActionService.stopListening();
    NotificationService.onForegroundAction = null;
    await DndService().updateTasks([]);
    debugDefaultTargetPlatformOverride = null;
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  test(
    'widget Skip persists task and immediately releases DND and app blocking',
    () async {
      await seed();
      expect(filters, [3]);
      await app.backgroundCallback(
        Uri.parse('momentum://skip?taskId=native-task'),
      );
      final task = Hive.box<DailyTaskInstance>(
        'dailyTaskInstances',
      ).get('native-task')!;
      expect(task.status, TaskStatus.skipped);
      expect(task.completedAt, isNull);
      expect(filters, [3, 2]);
      expect(shield.last, isFalse);
    },
  );

  test('notification Done uses the same terminal focus cleanup', () async {
    await seed();
    await notificationTapBackground(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'mark_done',
        payload: 'native-task',
      ),
    );
    final task = Hive.box<DailyTaskInstance>(
      'dailyTaskInstances',
    ).get('native-task')!;
    expect(task.status, TaskStatus.done);
    expect(task.completedAt, isNotNull);
    expect(filters, [3, 2]);
    expect(shield.last, isFalse);
  });

  test(
    'external engine message refreshes the app Hive cache, focus timer and UI',
    () async {
      await seed();
      NativeTaskActionService.startListening();
      final refreshed = Completer<void>();
      NotificationService.onForegroundAction = () => refreshed.complete();
      IsolateNameServer.lookupPortByName('momentum.nativeTaskActions')!.send({
        'id': 'native-task',
        'status': 'done',
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await refreshed.future.timeout(const Duration(seconds: 5));
      expect(
        Hive.box<DailyTaskInstance>(
          'dailyTaskInstances',
        ).get('native-task')!.status,
        TaskStatus.done,
      );
      expect(filters, [3, 2]);
      expect(shield.last, isFalse);
    },
  );

  test('stale native notifications do not revive a rescheduled task', () async {
    await seed(status: TaskStatus.rescheduled);
    await NativeTaskActionService.apply('native-task', TaskStatus.done);
    expect(
      Hive.box<DailyTaskInstance>(
        'dailyTaskInstances',
      ).get('native-task')!.status,
      TaskStatus.rescheduled,
    );
    expect(filters, isEmpty);
  });

  test(
    'background engine can restore a persisted DND ownership filter',
    () async {
      await Hive.box('appSettings').put('focus.previousDndFilter', 2);
      await DndService().updateTasks([]);
      expect(filters, [2]);
      expect(
        Hive.box('appSettings').containsKey('focus.previousDndFilter'),
        isFalse,
      );
    },
  );
}
