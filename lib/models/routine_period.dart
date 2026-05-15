import 'package:hive/hive.dart';

part 'routine_period.g.dart';

@HiveType(typeId: 3)
class RoutinePeriod extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String label;

  @HiveField(2)
  final DateTime startDate;

  @HiveField(3)
  final DateTime endDate;

  @HiveField(4)
  final bool isActive;

  RoutinePeriod({
    required this.id,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });
}
