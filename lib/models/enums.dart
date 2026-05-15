import 'package:hive/hive.dart';

part 'enums.g.dart';

@HiveType(typeId: 1)
enum TaskType {
  @HiveField(0)
  fixed,
  @HiveField(1)
  floating,
  @HiveField(2)
  adhoc,
}

@HiveType(typeId: 2)
enum TaskStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  done,
  @HiveField(2)
  skipped,
  @HiveField(3)
  rescheduled,
  @HiveField(4)
  missed,
  @HiveField(5)
  inProgress,
}
