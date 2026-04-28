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
       if (tx.direction == Direction.income || tx.expenseType == ExpenseType.borrowed) {
          totalIncome += tx.amount;
       } else if (tx.direction == Direction.expense && tx.expenseType != ExpenseType.borrowed) {
          totalExpense += tx.amount;
       }
    }
    
    return summary.openingBalance + totalIncome - totalExpense;
  }
}
