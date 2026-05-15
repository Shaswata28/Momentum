import 'package:hive/hive.dart';

part 'fixed_expense.g.dart';

@HiveType(typeId: 15)
class FixedExpense extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final int billingDay;

  @HiveField(4)
  final String? lastPaidMonthKey;

  FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.billingDay,
    this.lastPaidMonthKey,
  });
}
