import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'enums.dart';

part 'routine_task.g.dart';

@HiveType(typeId: 4)
class RoutineTask extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final TaskType taskType;

  @HiveField(3)
  final TimeOfDay? scheduledTime;

  @HiveField(4)
  final TimeOfDay? flexWindowStart;

  @HiveField(5)
  final TimeOfDay? flexWindowEnd;

  @HiveField(6)
  final int durationMinutes;

  @HiveField(7)
  final List<int> daysOfWeek;

  @HiveField(8)
  final bool enableDND;

  @HiveField(9)
  final int bufferAfterMin;

  @HiveField(10)
  final String? color;

  @HiveField(11)
  final bool isActive;

  @HiveField(12)
  final String routinePeriodId;

  RoutineTask({
    required this.id,
    required this.title,
    required this.taskType,
    this.scheduledTime,
    this.flexWindowStart,
    this.flexWindowEnd,
    required this.durationMinutes,
    required this.daysOfWeek,
    required this.enableDND,
    required this.bufferAfterMin,
    this.color,
    required this.isActive,
    required this.routinePeriodId,
  });
}
