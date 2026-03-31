import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';

import '../models/daily_task_instance.dart';
import '../repositories/routine_period_repository.dart';
import '../repositories/routine_task_repository.dart';
import '../repositories/daily_task_instance_repository.dart';
import 'notification_service.dart';

class InstanceGeneratorService {
  final RoutinePeriodRepository periodRepo;
  final RoutineTaskRepository taskRepo;
  final DailyTaskInstanceRepository instanceRepo;
  final Uuid _uuid = const Uuid();

  InstanceGeneratorService({
    required this.periodRepo,
    required this.taskRepo,
    required this.instanceRepo,
  });

  /// Generates DailyTaskInstances for a given date based on active RoutineTasks.
  Future<void> generateForDate(DateTime date) async {
    final activePeriod = periodRepo.getActivePeriod();
    if (activePeriod == null) return;

    if (date.isBefore(activePeriod.startDate) || date.isAfter(activePeriod.endDate)) {
      return; 
    }

    final int dayOfWeek = date.weekday; 
    final routineTasks = taskRepo.getTasksForDay(activePeriod.id, dayOfWeek);

    final existingInstances = instanceRepo.getTasksForDate(date);
    final existingRoutineTaskIds = existingInstances.map((t) => t.routineTaskId).whereType<String>().toSet();

    List<DailyTaskInstance> instances = [];

    for (var task in routineTasks) {
      if (existingRoutineTaskIds.contains(task.id)) continue;

      final taskInstance = DailyTaskInstance(
        id: _uuid.v4(),
        routineTaskId: task.id,
        date: date,
        title: task.title,
        taskType: task.taskType,
        scheduledTime: task.scheduledTime,
        flexWindowStart: task.flexWindowStart,
        flexWindowEnd: task.flexWindowEnd,
        durationMinutes: task.durationMinutes,
        status: TaskStatus.pending,
        isBufferBlock: false,
        enableDND: task.enableDND,
      );
      instances.add(taskInstance);

      if (task.bufferAfterMin > 0) {
        TimeOfDay? bufferStartTime;
        if (task.scheduledTime != null) {
           final totalMinutes = task.scheduledTime!.hour * 60 + task.scheduledTime!.minute + task.durationMinutes;
           bufferStartTime = TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
        }

        final bufferInstance = DailyTaskInstance(
          id: _uuid.v4(),
          routineTaskId: null, 
          date: date,
          title: 'Buffer — ${task.bufferAfterMin} min',
          taskType: task.taskType,
          scheduledTime: bufferStartTime,
          flexWindowStart: null, // Buffers are transitionary blocks, not explicitly flexible tasks
          flexWindowEnd: null,
          durationMinutes: task.bufferAfterMin,
          status: TaskStatus.pending,
          isBufferBlock: true,
          enableDND: false,
        );
        instances.add(bufferInstance);
      }

      await NotificationService().scheduleTaskNotifications(taskInstance);
    }

    await instanceRepo.saveAll(instances);
  }
}
