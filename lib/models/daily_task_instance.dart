import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'enums.dart';

part 'daily_task_instance.g.dart';

@HiveType(typeId: 5)
class DailyTaskInstance extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? routineTaskId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String title;

  @HiveField(4)
  final TaskType taskType;

  @HiveField(5)
  final TimeOfDay? scheduledTime;

  @HiveField(6)
  final TimeOfDay? flexWindowStart;

  @HiveField(7)
  final TimeOfDay? flexWindowEnd;

  @HiveField(8)
  final int durationMinutes;

  @HiveField(9)
  final TaskStatus status;

  @HiveField(10)
  final DateTime? completedAt;

  @HiveField(11)
  final DateTime? rescheduledToDate;

  @HiveField(12)
  final bool isBufferBlock;

  @HiveField(13)
  final bool enableDND;

  @HiveField(14)
  final int? notificationId;

  DailyTaskInstance({
    required this.id,
    this.routineTaskId,
    required this.date,
    required this.title,
    required this.taskType,
    this.scheduledTime,
    this.flexWindowStart,
    this.flexWindowEnd,
    required this.durationMinutes,
    required this.status,
    this.completedAt,
    this.rescheduledToDate,
    required this.isBufferBlock,
    required this.enableDND,
    this.notificationId,
  });
}
