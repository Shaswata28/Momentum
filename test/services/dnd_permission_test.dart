import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/daily_task_instance.dart';
import 'package:momentum/models/enums.dart';
import 'package:momentum/services/dnd_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final filters = <int>[];
  final focusStates = <bool>[];
  bool granted = false;
  bool nativeFailure = false;

  DailyTaskInstance task(TaskStatus status, {DateTime? date}) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 1));
    return DailyTaskInstance(
      id: 'focus',
      routineTaskId: null,
      date: date ?? now,
      title: 'Focus',
      taskType: TaskType.fixed,
      scheduledTime: TimeOfDay(hour: start.hour, minute: start.minute),
      flexWindowStart: null,
      flexWindowEnd: null,
      durationMinutes: 120,
      status: status,
      isBufferBlock: false,
      enableDND: true,
    );
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('momentum-dnd-test');
    Hive.init(directory.path);
    await Hive.openBox('appSettings');
    await Hive.openBox('focusShieldSettings');
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    filters.clear();
    focusStates.clear();
    granted = false;
    nativeFailure = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_dnd'), (
          call,
        ) async {
          if (nativeFailure)
            throw PlatformException(code: 'permission_revoked');
          switch (call.method) {
            case 'isNotificationPolicyAccessGranted':
              return granted;
            case 'getCurrentInterruptionFilter':
              return 2; // Preserve the user's priority-only mode.
            case 'setInterruptionFilter':
              filters.add(call.arguments as int);
              return true;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('app.momentum.tracker/focus_blocker'),
          (call) async {
            if (call.method == 'setFocusState') {
              focusStates.add((call.arguments as Map)['isActive'] as bool);
            }
            return null;
          },
        );
  });

  tearDown(() async {
    granted = true;
    nativeFailure = false;
    await DndService().updateTasks([]);
    debugDefaultTargetPlatformOverride = null;
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('denied DND permission never changes the interruption filter', () async {
    await DndService().updateTasks([task(TaskStatus.pending)]);
    expect(filters, isEmpty);
  });

  test(
    'finishing or skipping immediately restores the previous filter',
    () async {
      granted = true;
      await DndService().updateTasks([task(TaskStatus.inProgress)]);
      expect(filters, [3]);
      await DndService().updateTasks([task(TaskStatus.skipped)]);
      expect(filters, [3, 2]);
      expect(focusStates.last, isFalse);
    },
  );

  test('terminal and other-day records do not activate native focus', () async {
    granted = true;
    for (final status in [
      TaskStatus.done,
      TaskStatus.skipped,
      TaskStatus.missed,
      TaskStatus.rescheduled,
    ]) {
      await DndService().updateTasks([task(status)]);
    }
    await DndService().updateTasks([
      task(
        TaskStatus.pending,
        date: DateTime.now().add(const Duration(days: 1)),
      ),
    ]);
    expect(filters, isEmpty);
    expect(focusStates, everyElement(isFalse));
  });

  test(
    'platform failures are contained and the next sync can recover',
    () async {
      granted = true;
      nativeFailure = true;
      await DndService().updateTasks([task(TaskStatus.pending)]);
      nativeFailure = false;
      await DndService().updateTasks([task(TaskStatus.pending)]);
      expect(filters, [3]);
    },
  );
}
