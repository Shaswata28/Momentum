import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/month_summary.dart';
import '../models/fixed_expense.dart';

class WalletRepository {
  Box<Transaction> get _txBox => Hive.box<Transaction>('transactions');
  Box<MonthSummary> get _monthBox => Hive.box<MonthSummary>('monthSummaries');
  Box<FixedExpense> get _fixedExpenseBox => Hive.box<FixedExpense>('fixedExpenses');

  // Transactions CRUD
  List<Transaction> getAllTransactions() => _txBox.values.toList();
  
  List<Transaction> getTransactionsForMonth(String monthId) =>
      _txBox.values.where((t) => t.monthId == monthId).toList();

  Future<void> saveTransaction(Transaction tx) async {
    await _txBox.put(tx.id, tx);
  }

  Future<void> deleteTransaction(String id) async {
    await _txBox.delete(id);
  }

  /// Settles an IOU transaction (borrowed or lent).
  /// - Marks the original IOU as settled (isSettled = true).
  /// - Creates a real counterpart transaction that affects the balance:
  ///   * Borrowed settled → real expense (money leaves wallet)
  ///   * Lent settled     → real income  (money enters wallet)
  Future<void> settleTransaction(Transaction iou, String newId) async {
    // 1. Overwrite the original with isSettled = true
    await _txBox.put(iou.id, iou.copyWith(isSettled: true));

    // 2. Create the counterpart real transaction
    final now = DateTime.now();
    final counterpart = Transaction(
      id: newId,
      date: now,
      direction: iou.expenseType == ExpenseType.borrowed
          ? Direction.expense   // paying back → money out
          : Direction.income,   // received back → money in
      amount: iou.amount,
      expenseType: iou.expenseType == ExpenseType.borrowed
          ? ExpenseType.other
          : null,
      note: iou.expenseType == ExpenseType.borrowed
          ? 'Settled: ${iou.note.isEmpty ? "borrowed" : iou.note}'
          : 'Settled: ${iou.note.isEmpty ? "lent" : iou.note}',
      isSettled: true,
      monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
    await _txBox.put(counterpart.id, counterpart);
  }

  // MonthSummary CRUD
  MonthSummary? getMonthSummary(String monthId) => _monthBox.get(monthId);

  Future<void> saveMonthSummary(MonthSummary summary) async {
    await _monthBox.put(summary.id, summary);
  }

  // FixedExpense CRUD
  List<FixedExpense> getAllFixedExpenses() => _fixedExpenseBox.values.toList();

  Future<void> saveFixedExpense(FixedExpense expense) async {
    await _fixedExpenseBox.put(expense.id, expense);
  }

  Future<void> deleteFixedExpense(String id) async {
    await _fixedExpenseBox.delete(id);
  }

  // Balance computation
  double computeRunningBalance(String monthId) {
    final summary = getMonthSummary(monthId);
    if (summary == null) return 0.0;
    
    final txs = getTransactionsForMonth(monthId);
    double totalIncome = 0;
    double totalExpense = 0;

    for (var tx in txs) {
       // Skip borrowed & lent — they are IOUs, not real income/expense
       if (tx.expenseType == ExpenseType.borrowed || tx.expenseType == ExpenseType.lent) {
          continue;
       }
       if (tx.direction == Direction.income) {
          totalIncome += tx.amount;
       } else if (tx.direction == Direction.expense) {
          totalExpense += tx.amount;
       }
    }
    
    return summary.openingBalance + totalIncome - totalExpense;
  }
}
