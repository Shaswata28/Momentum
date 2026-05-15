import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 7)
enum Direction {
  @HiveField(0) income,
  @HiveField(1) expense,
}

@HiveType(typeId: 8)
enum ExpenseType {
  @HiveField(0) fixed,      // internal — fixed bill payments (hidden from UI)
  @HiveField(1) variable,   // legacy (hidden from UI)
  @HiveField(2) borrowed,   // IOU: money received, must repay
  @HiveField(3) lent,       // IOU: money given, will be returned
  @HiveField(4) transport,
  @HiveField(5) snacks,
  @HiveField(6) shopping,
  @HiveField(7) fees,
  @HiveField(8) other,
}

@HiveType(typeId: 9)
enum IncomeSource {
  @HiveField(0) tuition,
  @HiveField(1) freelance,  // legacy (hidden from UI, kept for old data)
  @HiveField(2) other,
  @HiveField(3) work,
  @HiveField(4) gift,
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

  Transaction copyWith({
    String? id,
    DateTime? date,
    Direction? direction,
    double? amount,
    ExpenseType? expenseType,
    IncomeSource? incomeSource,
    String? note,
    bool? isSettled,
    String? monthId,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      expenseType: expenseType ?? this.expenseType,
      incomeSource: incomeSource ?? this.incomeSource,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      monthId: monthId ?? this.monthId,
    );
  }
}
