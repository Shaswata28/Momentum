import 'package:hive/hive.dart';

part 'saving_goal.g.dart';

@HiveType(typeId: 16)
class SavingGoal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double targetAmount;

  @HiveField(3)
  final double monthlyTarget;

  @HiveField(4)
  final Map<String, double> deposits; // monthId (e.g. '2026-11') -> amount

  @HiveField(5)
  final DateTime createdAt;

  SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.monthlyTarget,
    Map<String, double>? deposits,
    DateTime? createdAt,
  })  : deposits = deposits ?? {},
        createdAt = createdAt ?? DateTime.now();

  double get savedSoFar =>
      deposits.values.fold(0.0, (acc, val) => acc + val);

  double get remainingAmount =>
      (targetAmount - savedSoFar).clamp(0.0, double.infinity);

  bool get isCompleted => targetAmount > 0 && savedSoFar >= targetAmount;

  double get progress => targetAmount > 0
      ? (savedSoFar / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  /// Returns estimated months to reach target given current remaining amount and monthly target.
  /// If completed: 0. If monthly target <= 0: null.
  int? get estimatedMonthsRemaining {
    if (isCompleted) return 0;
    if (monthlyTarget <= 0) return null;
    return (remainingAmount / monthlyTarget).ceil();
  }

  SavingGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? monthlyTarget,
    Map<String, double>? deposits,
    DateTime? createdAt,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      deposits: deposits ?? Map<String, double>.from(this.deposits),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
