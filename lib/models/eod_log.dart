import 'package:hive/hive.dart';

part 'eod_log.g.dart';

@HiveType(typeId: 6)
class EODLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int totalTasks;

  @HiveField(3)
  final int completedTasks;

  @HiveField(4)
  final int skippedTasks;

  @HiveField(5)
  final int rescheduledTasks;

  @HiveField(6)
  final String? userNote;

  @HiveField(7)
  final DateTime closedAt;

  @HiveField(8)
  final double healthScore;

  @HiveField(9)
  final String grade;

  @HiveField(10)
  final int energyLevel;

  @HiveField(11)
  final String motivation;

  /// NEW: Did the user stick to their budget today?
  /// Nullable — null means the question was not answered (older logs).
  @HiveField(12)
  final bool? stuckToBudget;

  EODLog({
    required this.id,
    required this.date,
    required this.totalTasks,
    required this.completedTasks,
    required this.skippedTasks,
    required this.rescheduledTasks,
    this.userNote,
    required this.closedAt,
    required this.healthScore,
    required this.grade,
    required this.energyLevel,
    required this.motivation,
    this.stuckToBudget,
  });
}
