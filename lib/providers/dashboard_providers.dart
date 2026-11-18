import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import '../repositories/daily_task_instance_repository.dart';
import '../repositories/routine_task_repository.dart';
import '../repositories/routine_period_repository.dart';
import '../services/instance_generator_service.dart';
import '../services/notification_service.dart';
import '../services/dnd_service.dart';
import '../services/widget_service.dart';

final taskInstanceRepositoryProvider = Provider(
  (ref) => DailyTaskInstanceRepository(),
);
final routineTaskRepositoryProviderDB = Provider(
  (ref) => RoutineTaskRepository(),
);
final routinePeriodRepositoryProviderDB = Provider(
  (ref) => RoutinePeriodRepository(),
);
final instanceGeneratorProvider = Provider(
  (ref) => InstanceGeneratorService(
    periodRepo: ref.watch(routinePeriodRepositoryProviderDB),
    taskRepo: ref.watch(routineTaskRepositoryProviderDB),
    instanceRepo: ref.watch(taskInstanceRepositoryProvider),
  ),
);
final todayTasksProvider =
    StateNotifierProvider<TodayTasksNotifier, List<DailyTaskInstance>>((ref) {
      return TodayTasksNotifier(
        ref.watch(taskInstanceRepositoryProvider),
        ref.watch(instanceGeneratorProvider),
      );
    });

class TodayTasksNotifier extends StateNotifier<List<DailyTaskInstance>> {
  final DailyTaskInstanceRepository repo;
  final InstanceGeneratorService generator;
  final Future<void> Function(DailyTaskInstance) scheduleReminder;
  final Future<void> Function(String) cancelReminder;
  final FutureOr<void> Function(List<DailyTaskInstance>) syncTasks;
  final DateTime Function() clock;
  final Map<String, Future<void>> _inFlight = {};
  Future<void> _queue = Future.value();

  TodayTasksNotifier(
    this.repo,
    this.generator, {
    Future<void> Function(DailyTaskInstance)? scheduleReminder,
    Future<void> Function(String)? cancelReminder,
    FutureOr<void> Function(List<DailyTaskInstance>)? syncTasks,
    DateTime Function()? clock,
    bool autoLoad = true,
  }) : scheduleReminder =
           scheduleReminder ?? NotificationService().scheduleTaskNotifications,
       cancelReminder =
           cancelReminder ?? NotificationService().cancelTaskNotifications,
       syncTasks = syncTasks ?? _syncWidgetAndDnd,
       clock = clock ?? DateTime.now,
       super([]) {
    if (autoLoad)
      loadTodayTasks().catchError((Object error) {
        debugPrint('Today refresh failed: $error');
      });
  }

  // Serialize generation and writes so foreground refresh cannot duplicate instances
  // or publish a stale list over a just-completed mutation.
  Future<void> _run(String key, Future<void> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    final guarded = result.whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = guarded;
    return guarded;
  }

  DailyTaskInstance _copy(
    DailyTaskInstance t,
    TaskStatus status, {
    DateTime? completedAt,
    DateTime? rescheduledToDate,
  }) => DailyTaskInstance(
    id: t.id,
    routineTaskId: t.routineTaskId,
    date: t.date,
    title: t.title,
    taskType: t.taskType,
    scheduledTime: t.scheduledTime,
    flexWindowStart: t.flexWindowStart,
    flexWindowEnd: t.flexWindowEnd,
    durationMinutes: t.durationMinutes,
    status: status,
    completedAt: completedAt,
    rescheduledToDate: rescheduledToDate,
    isBufferBlock: t.isBufferBlock,
    enableDND: t.enableDND,
    notificationId: t.notificationId,
  );

  bool _overdue(DailyTaskInstance task) {
    final time = task.taskType == TaskType.floating
        ? task.flexWindowEnd
        : task.scheduledTime;
    if (time == null || task.isBufferBlock) return false;
    var end = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
      time.hour,
      time.minute,
    );
    if (task.taskType != TaskType.floating)
      end = end.add(Duration(minutes: task.durationMinutes));
    return clock().isAfter(end);
  }

  Future<void> _refresh() async {
    final today = clock();
    if (state.any(
      (task) =>
          task.date.year != today.year ||
          task.date.month != today.month ||
          task.date.day != today.day,
    )) {
      if (mounted) state = [];
      await syncTasks([]);
    }
    await generator.generateForDate(today);
    final tasks = repo.getTasksForDate(today);
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].status == TaskStatus.pending && _overdue(tasks[i])) {
        tasks[i] = _copy(tasks[i], TaskStatus.missed);
        await repo.save(tasks[i]);
        await cancelReminder(tasks[i].id);
      }
    }
    tasks.sort(
      (a, b) =>
          (a.scheduledTime == null
                  ? 1440
                  : a.scheduledTime!.hour * 60 + a.scheduledTime!.minute)
              .compareTo(
                b.scheduledTime == null
                    ? 1440
                    : b.scheduledTime!.hour * 60 + b.scheduledTime!.minute,
              ),
    );
    if (mounted) state = tasks;
    await syncTasks(tasks);
  }

  Future<void> loadTodayTasks() => _run('refresh', _refresh);

  Future<void> addAdHocTask(
    String title,
    TimeOfDay? time,
    int durationMinutes, {
    String? id,
  }) => _run('add', () async {
    final task = DailyTaskInstance(
      id: id ?? const Uuid().v4(),
      routineTaskId: null,
      date: clock(),
      title: title,
      taskType: TaskType.adhoc,
      scheduledTime: time,
      flexWindowStart: null,
      flexWindowEnd: null,
      durationMinutes: durationMinutes,
      status: TaskStatus.pending,
      isBufferBlock: false,
      enableDND: false,
    );
    await repo.save(task);
    await _publishAndRemind(task);
  });

  Future<void> _publishAndRemind(DailyTaskInstance task) async {
    // Publish committed data even when a platform side effect fails. The UI reports
    // the failure and a retry can safely repeat cancellation/scheduling by task ID.
    try {
      await cancelReminder(task.id);
      if (task.status == TaskStatus.pending) await scheduleReminder(task);
    } finally {
      final tasks = repo.getTasksForDate(clock());
      tasks.sort(
        (a, b) =>
            (a.scheduledTime == null
                    ? 1440
                    : a.scheduledTime!.hour * 60 + a.scheduledTime!.minute)
                .compareTo(
                  b.scheduledTime == null
                      ? 1440
                      : b.scheduledTime!.hour * 60 + b.scheduledTime!.minute,
                ),
      );
      if (mounted) state = tasks;
      await syncTasks(tasks);
    }
  }

  Future<void> _status(String id, TaskStatus status) => _run(id, () async {
    final task = repo
        .getTasksForDate(clock())
        .where((t) => t.id == id)
        .firstOrNull;
    if (task == null) return;
    var updated = _copy(
      task,
      status,
      completedAt: status == TaskStatus.done ? clock() : null,
    );
    if (status == TaskStatus.pending && _overdue(updated))
      updated = _copy(updated, TaskStatus.missed);
    await repo.save(updated);
    await _publishAndRemind(updated);
  });

  Future<void> startTask(String id) => _status(id, TaskStatus.inProgress);
  Future<void> markTaskDone(String id) => _status(id, TaskStatus.done);
  Future<void> markTaskSkipped(String id) => _status(id, TaskStatus.skipped);
  Future<void> restoreTask(String id) => _status(id, TaskStatus.pending);
  Future<void> dismissBuffer(String id) => markTaskSkipped(id);

  Future<void> rescheduleTask(String id, DateTime toDate) => _run(id, () async {
    final old = repo
        .getTasksForDate(clock())
        .where((t) => t.id == id)
        .firstOrNull;
    if (old == null) return;
    final destination = DateTime(toDate.year, toDate.month, toDate.day);
    final today = clock();
    if (destination.isBefore(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError('Choose today or a future date.');
    }
    // A stable destination ID makes retries idempotent, including service failures.
    final task = DailyTaskInstance(
      id: '${old.id}_rescheduled_${destination.toIso8601String()}',
      routineTaskId: old.routineTaskId,
      date: destination,
      title: old.title,
      taskType: old.taskType,
      scheduledTime: old.scheduledTime,
      flexWindowStart: old.flexWindowStart,
      flexWindowEnd: old.flexWindowEnd,
      durationMinutes: old.durationMinutes,
      status: TaskStatus.pending,
      isBufferBlock: false,
      enableDND: old.enableDND,
    );
    await repo.saveAll([
      _copy(
        old,
        TaskStatus.rescheduled,
        completedAt: clock(),
        rescheduledToDate: destination,
      ),
      task,
    ]);
    try {
      await cancelReminder(old.id);
      await cancelReminder(task.id);
      await scheduleReminder(task);
    } finally {
      if (mounted) state = repo.getTasksForDate(clock());
      await syncTasks(state);
    }
  });

  static Future<void> _syncWidgetAndDnd(List<DailyTaskInstance> tasks) async {
    await DndService().updateTasks(
      tasks
          .where(
            (task) =>
                task.status == TaskStatus.pending ||
                task.status == TaskStatus.inProgress,
          )
          .toList(),
    );
    await WidgetService.syncWidgetState(tasks);
  }
}

final completedTasksProvider = Provider<List<DailyTaskInstance>>(
  (ref) => ref
      .watch(todayTasksProvider)
      .where((t) => !t.isBufferBlock && t.status == TaskStatus.done)
      .toList(),
);
final skippedTasksProvider = Provider<List<DailyTaskInstance>>(
  (ref) => ref
      .watch(todayTasksProvider)
      .where((t) => !t.isBufferBlock && t.status == TaskStatus.skipped)
      .toList(),
);
final activeTasksProvider = Provider<List<DailyTaskInstance>>((ref) {
  final all = ref.watch(todayTasksProvider);
  final active = <DailyTaskInstance>[];
  for (var i = 0; i < all.length; i++) {
    final task = all[i];
    if ({
      TaskStatus.done,
      TaskStatus.skipped,
      TaskStatus.rescheduled,
    }.contains(task.status))
      continue;
    if (task.isBufferBlock) {
      final parent = all.take(i).where((t) => !t.isBufferBlock).lastOrNull;
      if (parent != null &&
          {
            TaskStatus.done,
            TaskStatus.skipped,
            TaskStatus.missed,
            TaskStatus.rescheduled,
          }.contains(parent.status))
        continue;
    }
    active.add(task);
  }
  return active;
});
