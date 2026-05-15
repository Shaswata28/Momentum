import 'package:hive/hive.dart';

part 'simple_goal.g.dart';

@HiveType(typeId: 14)
class SimpleGoal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final bool isHabit;

  @HiveField(3)
  final DateTime createdAt;

  SimpleGoal({
    required this.id,
    required this.title,
    required this.isHabit,
    required this.createdAt,
  });
}
