import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 7)
enum Direction {
  @HiveField(0) income,
  @HiveField(1) expense,
}

@HiveType(typeId: 8)
enum ExpenseType {
  @HiveField(0) fixed,
  @HiveField(1) variable,
  @HiveField(2) borrowed,
  @HiveField(3) lent,
}

@HiveType(typeId: 9)
enum IncomeSource {
  @HiveField(0) tuition,
  @HiveField(1) freelance,
  @HiveField(2) other,
}

@HiveType(typeId: 10)
class Transaction {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final Direction direction;
  @HiveField(3)
  final double amount;
  @HiveField(4)
  final ExpenseType? expenseType;
  @HiveField(5)
  final IncomeSource? incomeSource;
  @HiveField(6)
  final String note;
  @HiveField(7)
  final bool isSettled;
  @HiveField(8)
  final String monthId;

  Transaction({
    required this.id,
    required this.date,
    required this.direction,
    required this.amount,
    this.expenseType,
    this.incomeSource,
    this.note = '',
    this.isSettled = false,
    required this.monthId,
  });
}
