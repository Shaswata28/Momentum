import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import 'notification_service.dart';

class WidgetService {
  static const String androidWidgetName = 'DailyTrackerWidgetProvider';

  static Future<void> _themeSync = Future<void>.value();

  /// Keep theme writes ordered when the appearance controls are tapped quickly.
  /// Save the mode itself so Android can resolve system brightness independently.
  static Future<void> syncTheme(String mode) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future<void>.value();
    }
    _themeSync = _themeSync.then((_) async {
      try {
        await HomeWidget.saveWidgetData<String>('theme_mode', mode);
        await HomeWidget.updateWidget(androidName: androidWidgetName);
      } catch (error) {
        debugPrint('Widget theme sync unavailable: $error');
      }
    });
    return _themeSync;
  }

  static Future<void> updateWidgetData({
    required String? currentTaskId,
    required String headlineTitle,
    required String nextTaskTitle,
    required String nextTaskTime,
    required String progressText,
    required int progressPercent,
    int? taskStartMillis,
    int? taskEndMillis,
    String? headlineLabel,
  }) async {
    await HomeWidget.saveWidgetData<String>('current_task_id', currentTaskId ?? "");
    await HomeWidget.saveWidgetData<String>('headline_title', headlineTitle);
    await HomeWidget.saveWidgetData<String>('next_task_title', nextTaskTitle);
    await HomeWidget.saveWidgetData<String>('next_task_time', nextTaskTime);
    await HomeWidget.saveWidgetData<String>('progress_text', progressText);
    await HomeWidget.saveWidgetData<int>('progress_percent', progressPercent);
    await HomeWidget.saveWidgetData<String>('task_start_millis', (taskStartMillis ?? 0).toString());
    await HomeWidget.saveWidgetData<String>('task_end_millis', (taskEndMillis ?? 0).toString());
    await HomeWidget.saveWidgetData<String>('headline_label', headlineLabel ?? "CURRENT");
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  static Future<void> syncWidgetState(List<DailyTaskInstance> tasks) async {
    final now = DateTime.now();
    DailyTaskInstance? currentTask;
    DailyTaskInstance? nextTask;
    DateTime? taskStartTime;
    DateTime? taskEndTime;

    // 1. Prioritize any task that is explicitly inProgress
    final inProgressTask = tasks
        .where((t) => t.status == TaskStatus.inProgress && !t.isBufferBlock)
        .firstOrNull;

    if (inProgressTask != null) {
      currentTask = inProgressTask;
      if (inProgressTask.scheduledTime != null) {
        final start = DateTime(
          now.year,
          now.month,
          now.day,
          inProgressTask.scheduledTime!.hour,
          inProgressTask.scheduledTime!.minute,
        );
        final end = start.add(Duration(minutes: inProgressTask.durationMinutes));
        if (now.isBefore(start)) {
          // Started early
          taskStartTime = now;
          taskEndTime = now.add(Duration(minutes: inProgressTask.durationMinutes));
        } else {
          taskStartTime = start;
          taskEndTime = end;
        }
      } else if (inProgressTask.flexWindowStart != null) {
        final start = DateTime(
          now.year,
          now.month,
          now.day,
          inProgressTask.flexWindowStart!.hour,
          inProgressTask.flexWindowStart!.minute,
        );
        final end = inProgressTask.flexWindowEnd != null
            ? DateTime(
                now.year,
                now.month,
                now.day,
                inProgressTask.flexWindowEnd!.hour,
                inProgressTask.flexWindowEnd!.minute,
              )
            : start.add(Duration(minutes: inProgressTask.durationMinutes));
        taskStartTime = start.isBefore(now) ? start : now;
        taskEndTime = end;
      } else {
        // Floating or adhoc with no window
        taskStartTime = now;
        taskEndTime = now.add(
          Duration(minutes: inProgressTask.durationMinutes > 0 ? inProgressTask.durationMinutes : 30),
        );
      }
    } else {
      // 2. No active inProgress task: match current wall-clock window
      for (var t in tasks) {
        if ((t.status != TaskStatus.pending && t.status != TaskStatus.inProgress) || t.isBufferBlock) continue;

        if (t.scheduledTime != null) {
          final start = DateTime(now.year, now.month, now.day, t.scheduledTime!.hour, t.scheduledTime!.minute);
          final end = start.add(Duration(minutes: t.durationMinutes));
          if (now.isAfter(start) && now.isBefore(end)) {
            currentTask = t;
            taskStartTime = start;
            taskEndTime = end;
            break;
          }
        } else if (t.flexWindowStart != null) {
          final start = DateTime(now.year, now.month, now.day, t.flexWindowStart!.hour, t.flexWindowStart!.minute);
          final end = t.flexWindowEnd != null
              ? DateTime(now.year, now.month, now.day, t.flexWindowEnd!.hour, t.flexWindowEnd!.minute)
              : start.add(Duration(minutes: t.durationMinutes));
          if (now.isAfter(start) && now.isBefore(end)) {
            currentTask = t;
            taskStartTime = start;
            taskEndTime = end;
            break;
          }
        }
      }
    }

    // 3. Find next upcoming task
    for (var t in tasks) {
      if (t.id == currentTask?.id || (t.status != TaskStatus.pending && t.status != TaskStatus.inProgress) || t.isBufferBlock) continue;
      if (t.scheduledTime != null) {
        final start = DateTime(now.year, now.month, now.day, t.scheduledTime!.hour, t.scheduledTime!.minute);
        if (start.isAfter(now)) {
          if (nextTask == null) {
            nextTask = t;
          } else if (nextTask.scheduledTime != null) {
            final nextStart = DateTime(now.year, now.month, now.day, nextTask.scheduledTime!.hour, nextTask.scheduledTime!.minute);
            if (start.isBefore(nextStart)) {
              nextTask = t;
            }
          }
        }
      } else if (t.flexWindowStart != null) {
        final start = DateTime(now.year, now.month, now.day, t.flexWindowStart!.hour, t.flexWindowStart!.minute);
        if (start.isAfter(now) && nextTask == null) {
          nextTask = t;
        }
      }
    }

    nextTask ??= tasks
        .where((t) =>
            t.id != currentTask?.id &&
            (t.status == TaskStatus.pending || t.status == TaskStatus.inProgress) &&
            !t.isBufferBlock)
        .firstOrNull;

    final total = tasks.where((t) => !t.isBufferBlock).length;
    final done = tasks.where((t) => !t.isBufferBlock && t.status == TaskStatus.done).length;

    int progressPercent = 0;
    int remainingMinutes = 0;
    String headlineLabel = 'CURRENT';

    if (currentTask != null && taskStartTime != null && taskEndTime != null) {
      final totalMinutes = taskEndTime.difference(taskStartTime).inMinutes;
      final elapsed = now.difference(taskStartTime).inMinutes;
      progressPercent = totalMinutes > 0 ? ((elapsed / totalMinutes) * 100).clamp(0, 100).toInt() : 0;
      remainingMinutes = taskEndTime.difference(now).inMinutes.clamp(0, 9999);
      final hour = taskEndTime.hour > 12 ? taskEndTime.hour - 12 : (taskEndTime.hour == 0 ? 12 : taskEndTime.hour);
      final ampm = taskEndTime.hour >= 12 ? 'PM' : 'AM';
      final formattedEndTime = '$hour:${taskEndTime.minute.toString().padLeft(2, '0')} $ampm';
      headlineLabel = remainingMinutes > 0 ? 'CURRENT · ${remainingMinutes}m left' : 'CURRENT · Ending';

      String typeLabel = 'Routine Task';
      if (currentTask.taskType == TaskType.fixed) {
        typeLabel = 'Fixed Routine';
      } else if (currentTask.taskType == TaskType.floating) {
        typeLabel = 'Flexible Window';
      } else if (currentTask.taskType == TaskType.adhoc) {
        typeLabel = 'One-off Task';
      }

      // Post/update Uber-style live ongoing notification
      await NotificationService().showLiveTaskNotification(
        taskId: currentTask.id,
        title: currentTask.title,
        progressPercent: progressPercent,
        remainingMinutes: remainingMinutes,
        endTimeFormatted: formattedEndTime,
        taskType: typeLabel,
      );
    } else {
      // No active task currently running
      await NotificationService().cancelLiveTaskNotification();
    }

    String? nextTimeStr;
    if (nextTask != null) {
      if (nextTask.scheduledTime != null) {
        final st = nextTask.scheduledTime!;
        final dt = DateTime(now.year, now.month, now.day, st.hour, st.minute);
        nextTimeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'pm' : 'am'}";
      } else if (nextTask.flexWindowStart != null) {
        final st = nextTask.flexWindowStart!;
        final dt = DateTime(now.year, now.month, now.day, st.hour, st.minute);
        nextTimeStr = "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'pm' : 'am'}";
      } else {
        nextTimeStr = "floating";
      }
    }

    await updateWidgetData(
      currentTaskId: currentTask?.id,
      headlineTitle: currentTask?.title ?? "No Active Tasks",
      nextTaskTitle: nextTask?.title ?? "No upcoming task",
      nextTaskTime: nextTimeStr ?? "--:--",
      progressText: '$done / $total done',
      progressPercent: progressPercent,
      taskStartMillis: taskStartTime?.millisecondsSinceEpoch,
      taskEndMillis: taskEndTime?.millisecondsSinceEpoch,
      headlineLabel: headlineLabel,
    );
  }
}
