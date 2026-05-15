import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:daily_tracker/models/enums.dart';
import 'package:daily_tracker/models/routine_period.dart';
import 'package:daily_tracker/models/routine_task.dart';
import 'package:daily_tracker/models/daily_task_instance.dart';
import 'package:daily_tracker/repositories/routine_period_repository.dart';
import 'package:daily_tracker/repositories/routine_task_repository.dart';
import 'package:daily_tracker/repositories/daily_task_instance_repository.dart';
import 'package:daily_tracker/services/instance_generator_service.dart';

class FakePeriodRepo implements RoutinePeriodRepository {
  RoutinePeriod? activePeriod;
  @override RoutinePeriod? getActivePeriod() => activePeriod;
  @override List<RoutinePeriod> getAll() => throw UnimplementedError();
  @override Future<void> save(RoutinePeriod period) => throw UnimplementedError();
  @override Future<void> delete(String id) => throw UnimplementedError();
}

class FakeTaskRepo implements RoutineTaskRepository {
  List<RoutineTask> tasks = [];
  @override List<RoutineTask> getTasksForDay(String periodId, int dayOfWeek) {
    return tasks.where((t) => t.routinePeriodId == periodId && t.daysOfWeek.contains(dayOfWeek)).toList();
  }
  @override List<RoutineTask> getAllForPeriod(String periodId) => throw UnimplementedError();
  @override Future<void> save(RoutineTask task) => throw UnimplementedError();
  @override Future<void> delete(String id) => throw UnimplementedError();
}

class FakeInstanceRepo implements DailyTaskInstanceRepository {
  List<DailyTaskInstance> savedInstances = [];
  @override Future<void> saveAll(List<DailyTaskInstance> tasks) async {
    savedInstances.addAll(tasks);
  }
  @override List<DailyTaskInstance> getTasksForDate(DateTime date) => throw UnimplementedError();
  @override List<DailyTaskInstance> getAllPendingFloating() => throw UnimplementedError();
  @override Future<void> save(DailyTaskInstance task) => throw UnimplementedError();
  @override Future<void> delete(String id) => throw UnimplementedError();
}

void main() {
  group('InstanceGeneratorService', () {
    late FakePeriodRepo periodRepo;
    late FakeTaskRepo taskRepo;
    late FakeInstanceRepo instanceRepo;
    late InstanceGeneratorService service;

    setUp(() {
      periodRepo = FakePeriodRepo();
      taskRepo = FakeTaskRepo();
      instanceRepo = FakeInstanceRepo();
      service = InstanceGeneratorService(
        periodRepo: periodRepo,
        taskRepo: taskRepo,
        instanceRepo: instanceRepo,
      );
    });

    test('generates tasks and buffer blocks correctly based on active period', () async {
      final period = RoutinePeriod(
        id: 'p1',
        label: 'Sem 1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
        isActive: true,
      );
      periodRepo.activePeriod = period;

      final testDate = DateTime(2026, 3, 23); // Monday (weekday 1)
      
      final task1 = RoutineTask(
        id: 't1',
        title: 'Class',
        taskType: TaskType.fixed,
        scheduledTime: const TimeOfDay(hour: 10, minute: 0),
        durationMinutes: 60,
        daysOfWeek: [1],
        enableDND: true,
        bufferAfterMin: 30, // should generate a buffer block!
        isActive: true,
        routinePeriodId: 'p1',
      );

      final task2 = RoutineTask(
        id: 't2',
        title: 'Read',
        taskType: TaskType.floating,
        durationMinutes: 45,
        daysOfWeek: [1],
        enableDND: false,
        bufferAfterMin: 0,
        isActive: true,
        routinePeriodId: 'p1',
      );

      taskRepo.tasks = [task1, task2];

      await service.generateForDate(testDate);

      expect(instanceRepo.savedInstances.length, 3, reason: 'Should generate 2 tasks and 1 buffer block');

      final generatedClass = instanceRepo.savedInstances.firstWhere((i) => i.routineTaskId == 't1');
      expect(generatedClass.title, 'Class');
      expect(generatedClass.isBufferBlock, false);

      final bufferBlock = instanceRepo.savedInstances.firstWhere((i) => i.isBufferBlock);
      expect(bufferBlock.title, 'Buffer — 30 min');
      expect(bufferBlock.durationMinutes, 30);
      expect(bufferBlock.scheduledTime?.hour, 11);
      expect(bufferBlock.scheduledTime?.minute, 0, reason: 'Buffer starts right after Class (10:00 + 60 min)');

      final generatedRead = instanceRepo.savedInstances.firstWhere((i) => i.routineTaskId == 't2');
      expect(generatedRead.title, 'Read');
      expect(generatedRead.isBufferBlock, false);
    });

    test('does not generate tasks if date is outside active period', () async {
      final period = RoutinePeriod(
        id: 'p1',
        label: 'Sem 1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
        isActive: true,
      );
      periodRepo.activePeriod = period;

      // Date is outside the active period (starts in January)
      final testDate = DateTime(2025, 12, 1); 
      
      final task1 = RoutineTask(
        id: 't1',
        title: 'Class',
        taskType: TaskType.fixed,
        durationMinutes: 60,
        daysOfWeek: [1],
        enableDND: false,
        bufferAfterMin: 0,
        isActive: true,
        routinePeriodId: 'p1',
      );

      taskRepo.tasks = [task1];

      await service.generateForDate(testDate);

      expect(instanceRepo.savedInstances.isEmpty, true);
    });
  });
}
