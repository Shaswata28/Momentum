import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/daily_task_instance.dart';
import 'package:momentum/models/eod_log.dart';
import 'package:momentum/models/enums.dart';
import 'package:momentum/models/routine_period.dart';
import 'package:momentum/models/routine_task.dart';
import 'package:momentum/models/time_of_day_adapter.dart';
import 'package:momentum/models/user_settings.dart';
import 'package:momentum/providers/dashboard_providers.dart';
import 'package:momentum/providers/review_providers.dart';
import 'package:momentum/providers/wallet_providers.dart' show runningBalanceProvider;
import 'package:momentum/screens/dashboard/dashboard_screen.dart';
import 'package:momentum/screens/log/eod_log_screen.dart';
import 'package:momentum/screens/log/review_history_screen.dart';
import 'package:momentum/theme/app_colors.dart';
import 'package:momentum/widgets/task_card.dart';
import 'package:momentum/repositories/daily_task_instance_repository.dart';
import 'package:momentum/repositories/eod_log_repository.dart';
import 'package:momentum/repositories/routine_period_repository.dart';
import 'package:momentum/repositories/routine_task_repository.dart';
import 'package:momentum/services/instance_generator_service.dart';

class _Generator extends InstanceGeneratorService {
  _Generator()
    : super(
        periodRepo: RoutinePeriodRepository(),
        taskRepo: RoutineTaskRepository(),
        instanceRepo: DailyTaskInstanceRepository(),
      );
  @override
  Future<void> generateForDate(DateTime date) async {}
}

class _FailingRepository extends DailyTaskInstanceRepository {
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> save(DailyTaskInstance task) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('disk unavailable');
    await super.save(task);
  }
}

class _FailingReviewRepository extends EODLogRepository {
  @override
  Future<void> save(EODLog log) async => throw StateError('disk unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _FailingRepository repo;
  late TodayTasksNotifier notifier;
  final now = DateTime(2026, 11, 16, 12);
  late DateTime currentTime;
  late List<String> scheduled;
  late List<String> cancelled;

  DailyTaskInstance task({
    DateTime? date,
    String title = 'Read',
    String id = 'task',
    TaskStatus status = TaskStatus.skipped,
    int hour = 14,
    bool buffer = false,
  }) => DailyTaskInstance(
    id: id,
    routineTaskId: 'routine',
    date: date ?? now,
    title: title,
    taskType: TaskType.fixed,
    scheduledTime: TimeOfDay(hour: hour, minute: 0),
    flexWindowStart: null,
    flexWindowEnd: null,
    durationMinutes: 30,
    status: status,
    completedAt: now,
    rescheduledToDate: now,
    isBufferBlock: buffer,
    enableDND: true,
  );

  setUpAll(() {
    Hive.registerAdapter(DailyTaskInstanceAdapter());
    Hive.registerAdapter(TaskTypeAdapter());
    Hive.registerAdapter(TaskStatusAdapter());
    Hive.registerAdapter(EODLogAdapter());
    Hive.registerAdapter(RoutinePeriodAdapter());
    Hive.registerAdapter(RoutineTaskAdapter());
    Hive.registerAdapter(TimeOfDayAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('momentum-review-test');
    Hive.init(directory.path);
    await Hive.openBox<DailyTaskInstance>('dailyTaskInstances');
    await Hive.openBox<EODLog>('eodLogs');
    await Hive.openBox<RoutinePeriod>('routinePeriods');
    await Hive.openBox<RoutineTask>('routineTasks');
    await Hive.openBox('focusShieldSettings');
    await Hive.openBox<UserSettings>('userSettings');
    await Hive.box<UserSettings>('userSettings').put('user', UserSettings(firstName: 'A long display name that wraps', hasSeenCoachMarks: true));
    repo = _FailingRepository();
    currentTime = now;
    scheduled = [];
    cancelled = [];
    notifier = TodayTasksNotifier(
      repo,
      _Generator(),
      autoLoad: false,
      clock: () => currentTime,
      scheduleReminder: (task) async => scheduled.add(task.id),
      cancelReminder: (id) async => cancelled.add(id),
      syncTasks: (_) {},
    );
  });

  tearDown(() async {
    notifier.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'restore retains identity and schedule, clears terminal metadata, and schedules future reminder',
    () async {
      await repo.save(task());
      await notifier.restoreTask('task');
      final restored = repo.getTasksForDate(now).single;
      expect(restored.id, 'task');
      expect(restored.routineTaskId, 'routine');
      expect(restored.scheduledTime, const TimeOfDay(hour: 14, minute: 0));
      expect(restored.status, TaskStatus.pending);
      expect(restored.completedAt, isNull);
      expect(restored.rescheduledToDate, isNull);
      expect(scheduled, ['task']);
    },
  );

  test('restored elapsed task becomes missed without a reminder', () async {
    await repo.save(task(hour: 9));
    await notifier.restoreTask('task');
    expect(notifier.state.single.status, TaskStatus.missed);
    expect(scheduled, isEmpty);
    expect(cancelled, ['task']);
  });

  test(
    'failed storage is awaitable and does not publish success; retry succeeds',
    () async {
      await repo.save(task(status: TaskStatus.pending));
      await notifier.loadTodayTasks();
      repo.fail = true;
      await expectLater(notifier.markTaskSkipped('task'), throwsStateError);
      expect(notifier.state.single.status, TaskStatus.pending);
      repo.fail = false;
      await notifier.markTaskSkipped('task');
      expect(notifier.state.single.status, TaskStatus.skipped);
    },
  );

  test(
    'repeated task taps write and schedule once while mutation is pending',
    () async {
      await repo.save(task());
      repo.gate = Completer<void>();
      final first = notifier.restoreTask('task');
      final second = notifier.restoreTask('task');
      repo.gate!.complete();
      await Future.wait([first, second]);
      expect(scheduled, ['task']);
    },
  );

  test(
    'reschedule preserves destination date and stable retry identity/reminder',
    () async {
      await repo.save(task(status: TaskStatus.pending));
      final tomorrow = DateTime(2026, 11, 17);
      await notifier.rescheduleTask('task', tomorrow);
      await notifier.rescheduleTask('task', tomorrow);
      final destination = repo.getTasksForDate(tomorrow).single;
      expect(destination.date, tomorrow);
      expect(destination.status, TaskStatus.pending);
      expect(scheduled, [destination.id, destination.id]);
      expect(cancelled.where((id) => id == destination.id).length, 2);
      expect(repo.getTasksForDate(now).single.status, TaskStatus.rescheduled);
    },
  );

  test(
    'local-day rollover replaces yesterday instead of retaining old tasks',
    () async {
      await repo.save(task(status: TaskStatus.done));
      await repo.save(
        task(
          id: 'tomorrow',
          date: DateTime(2026, 11, 17),
          status: TaskStatus.pending,
        ),
      );
      await notifier.loadTodayTasks();
      expect(notifier.state.single.id, 'task');
      currentTime = DateTime(2026, 11, 17, 0, 1);
      await notifier.loadTodayTasks();
      expect(notifier.state.single.id, 'tomorrow');
      expect(notifier.state.single.status, TaskStatus.pending);
    },
  );

  test(
    'destination reminder failure keeps one committed destination on retry',
    () async {
      await repo.save(task(status: TaskStatus.pending));
      var failReminder = true;
      final failing = TodayTasksNotifier(
        repo,
        _Generator(),
        autoLoad: false,
        clock: () => now,
        scheduleReminder: (_) async {
          if (failReminder) throw StateError('service unavailable');
        },
        cancelReminder: (_) async {},
        syncTasks: (_) {},
      );
      final tomorrow = DateTime(2026, 11, 17);
      await expectLater(
        failing.rescheduleTask('task', tomorrow),
        throwsStateError,
      );
      expect(failing.state.single.status, TaskStatus.rescheduled);
      failReminder = false;
      await failing.rescheduleTask('task', tomorrow);
      expect(repo.getTasksForDate(tomorrow).length, 1);
      failing.dispose();
    },
  );

  EODLog review(String id, DateTime date) => EODLog(
    id: id,
    date: date,
    totalTasks: 3,
    completedTasks: 1,
    skippedTasks: 1,
    rescheduledTasks: 0,
    userNote: 'Original snapshot',
    closedAt: date,
    healthScore: 33,
    grade: 'C',
    energyLevel: 5,
    motivation: 'Medium',
  );

  test(
    'one immutable review per local date including simultaneous submissions',
    () async {
      final reviews = EODLogRepository();
      final first = reviews.save(review('one', now));
      await expectLater(
        reviews.save(review('two', DateTime(2026, 11, 16, 22))),
        throwsStateError,
      );
      await first;
      await expectLater(reviews.save(review('three', now)), throwsStateError);
      await repo.save(task(status: TaskStatus.done));
      expect(reviews.getForDate(now)!.completedTasks, 1);
      expect(reviews.getForDate(now)!.userNote, 'Original snapshot');
    },
  );

  test(
    'history is newest first, supports empty state and emits saved reviews',
    () async {
      final reviews = EODLogRepository();
      expect(await reviews.watchLogs().first, isEmpty);
      await reviews.save(
        review('older', now.subtract(const Duration(days: 1))),
      );
      await reviews.save(review('newer', now));
      expect(reviews.getAllLogs().map((log) => log.id), ['newer', 'older']);
    },
  );

  testWidgets('history empty state offers Review Day', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewHistoryProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: ReviewHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('Review Day'), findsOneWidget);
  });

  testWidgets('review save failure retains reflection inputs for retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eodRepoProvider.overrideWithValue(_FailingReviewRepository()),
          todayTasksProvider.overrideWith(
            (ref) => TodayTasksNotifier(
              repo,
              _Generator(),
              autoLoad: false,
              scheduleReminder: (_) async {},
              cancelReminder: (_) async {},
              syncTasks: (_) {},
            ),
          ),
        ],
        child: const MaterialApp(home: EODLogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this reflection');
    await tester.ensureVisible(find.text('Save Review'));
    await tester.tap(find.text('Save Review'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this reflection'), findsOneWidget);
    expect(find.textContaining('Your answers are kept'), findsOneWidget);
    expect(find.text('Save Review'), findsOneWidget);
  });

  for (final retro in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          testWidgets(
            'historical snapshot retro=$retro dark=$dark width=$width scale=$scale',
            (tester) async {
              AppColors.isRetro = retro;
              AppColors.isDark = dark;
              tester.view.physicalSize = Size(width, 900);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp(
                    theme: ThemeData(
                      brightness: dark ? Brightness.dark : Brightness.light,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: EODLogScreen(
                      savedLog: review('old', DateTime(2026, 11, 15, 20, 30)),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('Saved Review'), findsOneWidget);
              expect(
                find.textContaining('Submitted Nov 15, 2026'),
                findsOneWidget,
              );
              expect(find.textContaining('Later task changes'), findsOneWidget);
              expect(find.text('Save Review'), findsNothing);
              expect(tester.takeException(), isNull);
            },
          );
          testWidgets('editable review retro=$retro dark=$dark width=$width scale=$scale', (tester) async {
            AppColors.isRetro = retro;
            AppColors.isDark = dark;
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(ProviderScope(overrides: [
              todayTasksProvider.overrideWith((ref) => TodayTasksNotifier(repo, _Generator(), autoLoad: false,
                scheduleReminder: (_) async {}, cancelReminder: (_) async {}, syncTasks: (_) {},
              )),
            ], child: MaterialApp(
              theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const EODLogScreen(),
            )));
            await tester.pumpAndSettle();
            expect(find.text('Review Day'), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
          testWidgets('Today tasks retro=$retro dark=$dark width=$width scale=$scale', (tester) async {
            AppColors.isRetro = retro;
            AppColors.isDark = dark;
            await tester.runAsync(() => repo.saveAll([
              task(id: 'active', status: TaskStatus.pending, title: 'A very long scheduled task title that wraps naturally on a small phone screen'),
              task(id: 'skipped', status: TaskStatus.skipped, title: 'A long skipped task that can still be restored to the timeline'),
              task(id: 'done', status: TaskStatus.done, title: 'A completed task with a long recorded title'),
              task(id: 'buffer', status: TaskStatus.skipped, buffer: true),
            ]));
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(ProviderScope(overrides: [
              todayTasksProvider.overrideWith((ref) => TodayTasksNotifier(repo, _Generator(), autoLoad: false, clock: () => now,
                scheduleReminder: (_) async {}, cancelReminder: (_) async {}, syncTasks: (_) {},
              )),
              runningBalanceProvider.overrideWithValue(123456789.5),
              localTimeProvider.overrideWith((ref) => Stream.value(now)),
            ], child: MaterialApp(
              theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
                child: child!,
              ),
              home: const DashboardScreen(),
            )));
            await tester.pumpAndSettle();
            expect(find.text('WALLET'), findsOneWidget);
            expect(find.text('SHIELD'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(find.text('Skipped (1)'), 300, scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Skipped (1)'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Skipped (1)'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Restore'));
            expect(find.text('Restore'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(find.text('COMPLETED - 1 task'), -200, scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('COMPLETED - 1 task'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('COMPLETED - 1 task'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets(
    'task completion waits for persistence and duplicate taps are guarded',
    (tester) async {
      AppColors.isRetro = false;
      final saving = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task(status: TaskStatus.pending),
              onMarkDone: () {
                calls++;
                return saving.future;
              },
              onSkip: () {},
              onReschedule: (_) {},
            ),
          ),
        ),
      );
      final complete = find.byTooltip('Complete Read');
      await tester.tap(complete);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(calls, 1);
      await tester.tap(complete, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      saving.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
