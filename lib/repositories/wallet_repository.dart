import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/month_summary.dart';
import '../models/fixed_expense.dart';
import '../models/saving_goal.dart';

class WalletRepository {
  static String monthIdForDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Box<Transaction> get _txBox => Hive.box<Transaction>('transactions');
  Box<MonthSummary> get _monthBox => Hive.box<MonthSummary>('monthSummaries');
  Box<FixedExpense> get _fixedExpenseBox =>
      Hive.box<FixedExpense>('fixedExpenses');
  Box<SavingGoal> get _savingGoalBox => Hive.box<SavingGoal>('savingGoals');

  // Transactions CRUD
  List<Transaction> getTransactionsForMonth(String monthId) =>
      _txBox.values.where((t) => t.monthId == monthId).toList();

  Future<void> saveTransaction(Transaction tx) async {
    if (!tx.amount.isFinite || tx.amount <= 0) {
      throw ArgumentError('Amount must be finite and greater than zero.');
    }
    if (tx.monthId != monthIdForDate(tx.date)) {
      throw ArgumentError('Transaction month must match its entry date.');
    }
    await _txBox.put(tx.id, tx);
  }

  Future<void> deleteTransaction(String id) async {
    await _txBox.delete(id);
    final settledId = '${id}_settled';
    if (_txBox.containsKey(settledId)) {
      await _txBox.delete(settledId);
    }
  }

  bool hasSettledCounterpart(String id) => _txBox.containsKey('${id}_settled');

  /// Settles an IOU transaction (borrowed or lent).
  /// - Marks the original IOU as settled (isSettled = true).
  /// - Creates a real counterpart transaction that affects the balance:
  ///   * Borrowed settled → real expense (money leaves wallet)
  ///   * Lent settled     → real income  (money enters wallet)
  Future<void> settleTransaction(Transaction iou, String newId) async {
    final original = _txBox.get(iou.id);
    if (original == null) throw StateError('Transaction no longer exists.');
    if (original.expenseType != ExpenseType.borrowed &&
        original.expenseType != ExpenseType.lent) {
      throw ArgumentError('Only borrowed or lent entries can be settled.');
    }
    // Never recreate a legacy settled IOU or move a prior repayment to today.
    if (original.isSettled || hasSettledCounterpart(original.id)) {
      if (!original.isSettled)
        await _txBox.put(original.id, original.copyWith(isSettled: true));
      return;
    }
    final now = DateTime.now();
    final isBorrowed = original.expenseType == ExpenseType.borrowed;
    final counterpart = Transaction(
      id: '${original.id}_settled',
      date: now,
      direction: isBorrowed
          ? Direction
                .expense // paying back → money out
          : Direction.income, // received back → money in
      amount: original.amount,
      expenseType: isBorrowed ? ExpenseType.other : null,
      incomeSource: isBorrowed ? null : IncomeSource.other,
      note:
          'Settled: ${iou.note.isEmpty ? (isBorrowed ? "borrowed" : "lent") : iou.note}',
      isSettled: true,
      monthId: monthIdForDate(now),
    );
    await _txBox.putAll({
      original.id: original.copyWith(isSettled: true),
      counterpart.id: counterpart,
    });
  }

  // MonthSummary CRUD
  MonthSummary? getMonthSummary(String monthId) => _monthBox.get(monthId);

  Future<void> saveMonthSummary(MonthSummary summary) async {
    await _monthBox.put(summary.id, summary);
  }

  // FixedExpense CRUD
  List<FixedExpense> getAllFixedExpenses() => _fixedExpenseBox.values.toList();

  Future<void> saveFixedExpense(FixedExpense expense) async {
    if (!expense.amount.isFinite ||
        expense.amount <= 0 ||
        expense.billingDay < 1 ||
        expense.billingDay > 31) {
      throw ArgumentError(
        'Enter a positive amount and billing day from 1 to 31.',
      );
    }
    await _fixedExpenseBox.put(expense.id, expense);
  }

  Future<void> payFixedExpense(FixedExpense expense) async {
    final now = DateTime.now();
    final monthId = monthIdForDate(now);
    final current = _fixedExpenseBox.get(expense.id);
    if (current == null) throw StateError('Bill no longer exists.');
    final id = 'bill_${expense.id}_$monthId';
    if (current.lastPaidMonthKey == monthId) return;
    // Stable identity also makes retry safe if the bill-status write failed.
    if (!_txBox.containsKey(id)) {
      await saveTransaction(
        Transaction(
          id: id,
          date: now,
          direction: Direction.expense,
          amount: current.amount,
          expenseType: ExpenseType.fixed,
          note: current.name,
          isSettled: true,
          monthId: monthId,
        ),
      );
    }
    await saveFixedExpense(
      FixedExpense(
        id: current.id,
        name: current.name,
        amount: current.amount,
        billingDay: current.billingDay,
        lastPaidMonthKey: monthId,
      ),
    );
  }

  Future<void> deleteFixedExpense(String id) async {
    await _fixedExpenseBox.delete(id);
  }

  // SavingGoal CRUD
  List<SavingGoal> getAllSavingGoals() => _savingGoalBox.values.toList();

  Future<void> saveSavingGoal(SavingGoal goal) async {
    if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
      throw ArgumentError('Target price must be greater than zero.');
    }
    if (!goal.monthlyTarget.isFinite || goal.monthlyTarget <= 0) {
      throw ArgumentError('Monthly target must be greater than zero.');
    }
    await _savingGoalBox.put(goal.id, goal);
  }

  Future<void> deleteSavingGoal(String id) async {
    await _savingGoalBox.delete(id);
    final relatedTxs =
        _txBox.values.where((t) => t.id.startsWith('saving_${id}_')).toList();
    for (final tx in relatedTxs) {
      await _txBox.delete(tx.id);
    }
  }

  Future<void> addSavingGoalDeposit({
    required String goalId,
    required String monthKey,
    required double amount,
  }) async {
    final goal = _savingGoalBox.get(goalId);
    if (goal == null) throw StateError('Saving goal not found.');
    final updatedDeposits = Map<String, double>.from(goal.deposits);
    final currentVal = updatedDeposits[monthKey] ?? 0.0;
    updatedDeposits[monthKey] = currentVal + amount;
    final updatedGoal = goal.copyWith(deposits: updatedDeposits);
    await _savingGoalBox.put(goalId, updatedGoal);

    // Record expense transaction so cash balance, outflow, and transactions list update
    final now = DateTime.now();
    final txId = 'saving_${goalId}_${now.millisecondsSinceEpoch}';
    await saveTransaction(
      Transaction(
        id: txId,
        date: now,
        direction: Direction.expense,
        amount: amount,
        expenseType: ExpenseType.other,
        note: 'Savings: ${goal.name}',
        isSettled: true,
        monthId: monthKey,
      ),
    );
  }

  // Balance computation
  double computeRunningBalance(String monthId) {
    final summary = getMonthSummary(monthId);
    final openingBalance = summary?.openingBalance ?? 0.0;

    final txs = getTransactionsForMonth(monthId);
    double totalIncome = 0;
    double totalExpense = 0;

    for (var tx in txs) {
      // Legacy fallback: if an IOU was marked settled at entry with no counterpart,
      // net effect was 0 (money went out and came back in past), so skip.
      if (tx.isSettled &&
          (tx.expenseType == ExpenseType.borrowed ||
              tx.expenseType == ExpenseType.lent) &&
          !hasSettledCounterpart(tx.id)) {
        continue;
      }

      if (tx.direction == Direction.income) {
        totalIncome += tx.amount;
      } else if (tx.direction == Direction.expense) {
        totalExpense += tx.amount;
      }
    }

    return openingBalance + totalIncome - totalExpense;
  }
}
