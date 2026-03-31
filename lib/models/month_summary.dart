import 'package:hive/hive.dart';

part 'month_summary.g.dart';

@HiveType(typeId: 11)
class MonthSummary {
  @HiveField(0)
  final String id; // 'YYYY-MM'
  @HiveField(1)
  final double openingBalance;
  @HiveField(2)
  final double totalIncome;
  @HiveField(3)
  final double totalExpense;
  @HiveField(4)
  final double closingBalance;
  @HiveField(5)
  final double? budgetLimit;
  @HiveField(6)
  final bool isClosed;

  MonthSummary({
    required this.id,
    required this.openingBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.closingBalance,
    this.budgetLimit,
    this.isClosed = false,
  });
}
