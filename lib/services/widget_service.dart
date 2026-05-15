import 'package:home_widget/home_widget.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';

class WidgetService {
  static const String androidWidgetName = 'DailyTrackerWidgetProvider';

  static Future<void> updateWidgetData({
    required String? currentTaskId,
    required String headlineTitle,
    required String nextTaskTitle,
    required String nextTaskTime,
    required String progressText,
    required int progressPercent,
  }) async {
    await HomeWidget.saveWidgetData<String>('current_task_id', currentTaskId ?? "");
    await HomeWidget.saveWidgetData<String>('headline_title', headlineTitle);
    await HomeWidget.saveWidgetData<String>('next_task_title', nextTaskTitle);
    await HomeWidget.saveWidgetData<String>('next_task_time', nextTaskTime);
    await HomeWidget.saveWidgetData<String>('progress_text', progressText);
    await HomeWidget.saveWidgetData<int>('progress_percent', progressPercent);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  static Future<void> syncWidgetState(List<DailyTaskInstance> tasks) async {
    final now = DateTime.now();
    DailyTaskInstance? currentTask;
    DailyTaskInstance? nextTask;

    for (var t in tasks) {
      if (t.status == TaskStatus.done || t.status == TaskStatus.skipped || t.isBufferBlock) continue;

      if (t.scheduledTime != null) {
        final start = DateTime(now.year, now.month, now.day, t.scheduledTime!.hour, t.scheduledTime!.minute);
        final end = start.add(Duration(minutes: t.durationMinutes));
        if (now.isAfter(start) && now.isBefore(end)) {
          currentTask = t;
        } else if (start.isAfter(now) && nextTask == null && currentTask?.id != t.id) {
          nextTask = t;
        }
      } else if (t.flexWindowStart != null) {
        final start = DateTime(now.year, now.month, now.day, t.flexWindowStart!.hour, t.flexWindowStart!.minute);
        if (start.isAfter(now) && nextTask == null && currentTask?.id != t.id) {
          nextTask = t;
        }
      }
    }

    if (currentTask == null) {
      nextTask = tasks
          .where((t) =>
              t.status != TaskStatus.done &&
              t.status != TaskStatus.skipped &&
              !t.isBufferBlock &&
              t.scheduledTime != null &&
              DateTime(now.year, now.month, now.day, t.scheduledTime!.hour, t.scheduledTime!.minute).isAfter(now))
          .firstOrNull;
    }

    final total = tasks.where((t) => !t.isBufferBlock).length;
    final done = tasks.where((t) => !t.isBufferBlock && t.status == TaskStatus.done).length;

    int progressPercent = 0;
    if (currentTask != null && currentTask.scheduledTime != null) {
      final start = DateTime(now.year, now.month, now.day, currentTask.scheduledTime!.hour, currentTask.scheduledTime!.minute);
      final elapsed = now.difference(start).inMinutes;
      progressPercent = ((elapsed / currentTask.durationMinutes) * 100).clamp(0, 100).toInt();
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
    );
  }
}
