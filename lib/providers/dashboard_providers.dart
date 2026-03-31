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
import '../services/routine_health_score_service.dart';

final taskInstanceRepositoryProvider = Provider((ref) {
  return DailyTaskInstanceRepository();
});

final routineTaskRepositoryProviderDB = Provider(
  (ref) => RoutineTaskRepository(),
);
final routinePeriodRepositoryProviderDB = Provider(
  (ref) => RoutinePeriodRepository(),
);

final instanceGeneratorProvider = Provider((ref) {
  return InstanceGeneratorService(
    periodRepo: ref.watch(routinePeriodRepositoryProviderDB),
    taskRepo: ref.watch(routineTaskRepositoryProviderDB),
    instanceRepo: ref.watch(taskInstanceRepositoryProvider),
  );
});

final todayTasksProvider =
    StateNotifierProvider<TodayTasksNotifier, List<DailyTaskInstance>>((ref) {
      final repo = ref.watch(taskInstanceRepositoryProvider);
      final generator = ref.watch(instanceGeneratorProvider);
      return TodayTasksNotifier(repo, generator);
    });

class TodayTasksNotifier extends StateNotifier<List<DailyTaskInstance>> {
  final DailyTaskInstanceRepository repo;
  final InstanceGeneratorService generator;
  static const Uuid _uuid = Uuid();

  TodayTasksNotifier(this.repo, this.generator) : super([]) {
    loadTodayTasks();
  }

  Future<void> loadTodayTasks() async {
    final today = DateTime.now();

    await generator.generateForDate(today);
    final tasks = repo.getTasksForDate(today);

    final tasksList = tasks.toList();
    final now = DateTime.now();

    for (int i = 0; i < tasksList.length; i++) {
      final task = tasksList[i];
      if (task.status == TaskStatus.pending && !task.isBufferBlock) {
        bool isMissed = false;
        if (task.taskType == TaskType.floating) {
          if (task.flexWindowEnd != null) {
            final endDt = DateTime(
              task.date.year,
              task.date.month,
              task.date.day,
              task.flexWindowEnd!.hour,
              task.flexWindowEnd!.minute,
            );
            if (now.isAfter(endDt)) isMissed = true;
          }
        } else {
          if (task.scheduledTime != null) {
            final endDt = DateTime(
              task.date.year,
              task.date.month,
              task.date.day,
              task.scheduledTime!.hour,
              task.scheduledTime!.minute,
            ).add(Duration(minutes: task.durationMinutes));
            if (now.isAfter(endDt)) isMissed = true;
          }
        }

        if (isMissed) {
          final missedTask = DailyTaskInstance(
            id: task.id,
            routineTaskId: task.routineTaskId,
            date: task.date,
            title: task.title,
            taskType: task.taskType,
            scheduledTime: task.scheduledTime,
            flexWindowStart: task.flexWindowStart,
            flexWindowEnd: task.flexWindowEnd,
            durationMinutes: task.durationMinutes,
            status: TaskStatus.missed,
            completedAt: task.completedAt,
            rescheduledToDate: task.rescheduledToDate,
            isBufferBlock: task.isBufferBlock,
            enableDND: task.enableDND,
            notificationId: task.notificationId,
          );
          await repo.save(missedTask);
          tasksList[i] = missedTask;
        }
      }
    }

    tasksList.sort((a, b) {
      if (a.scheduledTime != null && b.scheduledTime != null) {
        final aMin = a.scheduledTime!.hour * 60 + a.scheduledTime!.minute;
        final bMin = b.scheduledTime!.hour * 60 + b.scheduledTime!.minute;
        return aMin.compareTo(bMin);
      }
      if (a.scheduledTime != null && b.scheduledTime == null) return -1;
      if (a.scheduledTime == null && b.scheduledTime != null) return 1;
      return 0;
    });

    state = tasksList;
    _syncWidgetAndDnd(tasksList);
  }

  void addAdHocTask(String title, TimeOfDay? time, int durationMinutes) async {
    final newTask = DailyTaskInstance(
      id: _uuid.v4(),
      routineTaskId: null,
      date: DateTime.now(),
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

    await repo.save(newTask);
    await NotificationService().scheduleTaskNotifications(newTask);

    final newState = [...state, newTask];
    newState.sort((a, b) {
      if (a.scheduledTime != null && b.scheduledTime != null) {
        final aMin = a.scheduledTime!.hour * 60 + a.scheduledTime!.minute;
        final bMin = b.scheduledTime!.hour * 60 + b.scheduledTime!.minute;
        return aMin.compareTo(bMin);
      }
      if (a.scheduledTime != null && b.scheduledTime == null) return -1;
      if (a.scheduledTime == null && b.scheduledTime != null) return 1;
      return 0;
    });
    state = newState;
    _syncWidgetAndDnd(newState);
  }

  void markTaskDone(String id) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final oldTask = state[taskIndex];
      final newTask = DailyTaskInstance(
        id: oldTask.id,
        routineTaskId: oldTask.routineTaskId,
        date: oldTask.date,
        title: oldTask.title,
        taskType: oldTask.taskType,
        scheduledTime: oldTask.scheduledTime,
        flexWindowStart: oldTask.flexWindowStart,
        flexWindowEnd: oldTask.flexWindowEnd,
        durationMinutes: oldTask.durationMinutes,
        status: TaskStatus.done,
        completedAt: DateTime.now(),
        rescheduledToDate: oldTask.rescheduledToDate,
        isBufferBlock: oldTask.isBufferBlock,
        enableDND: oldTask.enableDND,
        notificationId: oldTask.notificationId,
      );

      await repo.save(newTask);
      await NotificationService().cancelTaskNotifications(newTask.id);

      final newState = [...state];
      newState[taskIndex] = newTask;
      state = newState;
      _syncWidgetAndDnd(newState);
    }
  }

  void markTaskSkipped(String id) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final oldTask = state[taskIndex];
    final updated = DailyTaskInstance(
      id: oldTask.id,
      routineTaskId: oldTask.routineTaskId,
      date: oldTask.date,
      title: oldTask.title,
      taskType: oldTask.taskType,
      scheduledTime: oldTask.scheduledTime,
      flexWindowStart: oldTask.flexWindowStart,
      flexWindowEnd: oldTask.flexWindowEnd,
      durationMinutes: oldTask.durationMinutes,
      status: TaskStatus.skipped,
      completedAt: DateTime.now(),
      rescheduledToDate: oldTask.rescheduledToDate,
      isBufferBlock: oldTask.isBufferBlock,
      enableDND: oldTask.enableDND,
      notificationId: oldTask.notificationId,
    );
    await repo.save(updated);
    await NotificationService().cancelTaskNotifications(id);
    final newState = [...state];
    newState[taskIndex] = updated;
    state = newState;
    _syncWidgetAndDnd(newState);
  }

  void rescheduleTask(String id, DateTime toDate) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final oldTask = state[taskIndex];
    final updated = DailyTaskInstance(
      id: oldTask.id,
      routineTaskId: oldTask.routineTaskId,
      date: oldTask.date,
      title: oldTask.title,
      taskType: oldTask.taskType,
      scheduledTime: oldTask.scheduledTime,
      flexWindowStart: oldTask.flexWindowStart,
      flexWindowEnd: oldTask.flexWindowEnd,
      durationMinutes: oldTask.durationMinutes,
      status: TaskStatus.rescheduled,
      completedAt: DateTime.now(),
      rescheduledToDate: toDate,
      isBufferBlock: oldTask.isBufferBlock,
      enableDND: oldTask.enableDND,
      notificationId: oldTask.notificationId,
    );
    // Save the rescheduled original
    await repo.save(updated);
    await NotificationService().cancelTaskNotifications(id);

    // Create a new instance on the target date
    final rescheduledInstance = DailyTaskInstance(
      id: _uuid.v4(),
      routineTaskId: oldTask.routineTaskId,
      date: toDate,
      title: oldTask.title,
      taskType: oldTask.taskType,
      scheduledTime: oldTask.scheduledTime,
      flexWindowStart: oldTask.flexWindowStart,
      flexWindowEnd: oldTask.flexWindowEnd,
      durationMinutes: oldTask.durationMinutes,
      status: TaskStatus.pending,
      isBufferBlock: false,
      enableDND: oldTask.enableDND,
    );
    await repo.save(rescheduledInstance);

    final newState = [...state];
    newState[taskIndex] = updated;
    state = newState;
    _syncWidgetAndDnd(newState);
  }

  void dismissBuffer(String id) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final oldTask = state[taskIndex];
      final newTask = DailyTaskInstance(
        id: oldTask.id,
        routineTaskId: oldTask.routineTaskId,
        date: oldTask.date,
        title: oldTask.title,
        taskType: oldTask.taskType,
        scheduledTime: oldTask.scheduledTime,
        flexWindowStart: oldTask.flexWindowStart,
        flexWindowEnd: oldTask.flexWindowEnd,
        durationMinutes: oldTask.durationMinutes,
        status: TaskStatus.skipped,
        completedAt: DateTime.now(),
        rescheduledToDate: oldTask.rescheduledToDate,
        isBufferBlock: oldTask.isBufferBlock,
        enableDND: oldTask.enableDND,
        notificationId: oldTask.notificationId,
      );

      await repo.save(newTask);
      final newState = [...state];
      newState[taskIndex] = newTask;
      state = newState;
      _syncWidgetAndDnd(newState);
    }
  }

  void _syncWidgetAndDnd(List<DailyTaskInstance> tasks) {
    DndService().updateTasks(tasks);
    WidgetService.syncWidgetState(tasks);
  }
}

final completedTasksProvider = Provider<List<DailyTaskInstance>>((ref) {
  return ref
      .watch(todayTasksProvider)
      .where((t) => t.status == TaskStatus.done)
      .toList();
});

final activeTasksProvider = Provider<List<DailyTaskInstance>>((ref) {
  final allTasks = ref.watch(todayTasksProvider);
  final activeTasks = <DailyTaskInstance>[];

  for (int i = 0; i < allTasks.length; i++) {
    final task = allTasks[i];

    // Done and skipped tasks go to the completed toggle, not the active list
    if (task.status == TaskStatus.done || task.status == TaskStatus.skipped) continue;

    if (task.isBufferBlock) {
      DailyTaskInstance? parentTask;
      for (int j = i - 1; j >= 0; j--) {
        if (!allTasks[j].isBufferBlock) {
          parentTask = allTasks[j];
          break;
        }
      }

      if (parentTask != null &&
          (parentTask.status == TaskStatus.done ||
              parentTask.status == TaskStatus.skipped ||
              parentTask.status == TaskStatus.missed)) {
        continue;
      }
    }

    activeTasks.add(task);
  }

  return activeTasks;
});

final progressProvider = Provider<String>((ref) {
  final total = ref
      .watch(todayTasksProvider)
      .where((t) => !t.isBufferBlock)
      .length;
  final done = ref
      .watch(completedTasksProvider)
      .where((t) => !t.isBufferBlock)
      .length;
  return '$done / $total done';
});

// Fraction 0.0–1.0 for the progress bar pill
final progressFractionProvider = Provider<double>((ref) {
  final tasks = ref.watch(todayTasksProvider).where((t) => !t.isBufferBlock).toList();
  if (tasks.isEmpty) return 0.0;
  final done = tasks.where((t) => t.status == TaskStatus.done).length;
  return done / tasks.length;
});

// Live health score derived from current task state
final liveDayScoreProvider = Provider<Map<String, dynamic>>((ref) {
  final tasks = ref.watch(todayTasksProvider);
  return RoutineHealthScoreService().calculateDailyScore(tasks);
});
