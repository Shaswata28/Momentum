import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import '../repositories/daily_task_instance_repository.dart';
import 'dnd_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

// Native callbacks can run in a separate Flutter engine. Forward their writes
// to the app engine too, so its Hive cache and focus timer do not retain a task.
class NativeTaskActionService {
  static const _portName = 'momentum.nativeTaskActions';
  static ReceivePort? _port;

  static void startListening() {
    if (_port != null) return;
    IsolateNameServer.removePortNameMapping(_portName);
    final port = ReceivePort();
    if (!IsolateNameServer.registerPortWithName(port.sendPort, _portName)) {
      port.close();
      return;
    }
    _port = port;
    port.listen((message) async {
      if (message is! Map || message['id'] is! String) return;
      final status = message['status'];
      if (![
        TaskStatus.done.name,
        TaskStatus.skipped.name,
        TaskStatus.inProgress.name,
      ].contains(status))
        return;
      try {
        await apply(
          message['id'] as String,
          TaskStatus.values.byName(status as String),
          completedAt: message['completedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(
                  message['completedAt'] as int,
                )
              : null,
          forward: false,
        );
        NotificationService.onForegroundAction?.call();
      } catch (error) {
        debugPrint('Could not refresh native task action: $error');
      }
    });
  }

  static void stopListening() {
    _port?.close();
    _port = null;
    IsolateNameServer.removePortNameMapping(_portName);
  }

  static Future<void> apply(
    String id,
    TaskStatus status, {
    DateTime? completedAt,
    bool forward = true,
  }) async {
    if (![
      TaskStatus.done,
      TaskStatus.skipped,
      TaskStatus.inProgress,
    ].contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final repo = DailyTaskInstanceRepository();
    final now = DateTime.now();
    final task = repo
        .getTasksForDate(now)
        .where((task) => task.id == id)
        .firstOrNull;
    // A stale notification must not revive a task that has been rescheduled.
    if (task == null || task.status == TaskStatus.rescheduled) return;
    if (status == TaskStatus.inProgress &&
        (task.status == TaskStatus.done || task.status == TaskStatus.skipped))
      return;
    final finishedAt = status == TaskStatus.done
        ? completedAt ?? task.completedAt ?? now
        : null;
    await repo.save(
      DailyTaskInstance(
        id: task.id,
        routineTaskId: task.routineTaskId,
        date: task.date,
        title: task.title,
        taskType: task.taskType,
        scheduledTime: task.scheduledTime,
        flexWindowStart: task.flexWindowStart,
        flexWindowEnd: task.flexWindowEnd,
        durationMinutes: task.durationMinutes,
        status: status,
        completedAt: finishedAt,
        rescheduledToDate: task.rescheduledToDate,
        isBufferBlock: task.isBufferBlock,
        enableDND: task.enableDND,
        notificationId: task.notificationId,
      ),
    );
    if (forward && _port == null) {
      IsolateNameServer.lookupPortByName(_portName)?.send({
        'id': id,
        'status': status.name,
        'completedAt': finishedAt?.millisecondsSinceEpoch,
      });
    }
    final tasks = repo.getTasksForDate(now);
    await DndService().updateTasks(tasks);
    final notifications = NotificationService();
    await notifications.init();
    if (status != TaskStatus.inProgress)
      await notifications.cancelTaskNotifications(id);
    await notifications.cancelLiveTaskNotification();
    await WidgetService.syncWidgetState(tasks);
  }
}
